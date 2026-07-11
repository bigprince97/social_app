import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import 'active_conversation.dart';

abstract class ChatSyncEvent {
  const ChatSyncEvent();
}

class SyncedMessageEvent extends ChatSyncEvent {
  final Message message;
  final bool isUpdate;
  final String? conversationType;
  final String? conversationName;

  const SyncedMessageEvent({
    required this.message,
    required this.isUpdate,
    this.conversationType,
    this.conversationName,
  });
}

class UnreadCountsChangedEvent extends ChatSyncEvent {
  const UnreadCountsChangedEvent();
}

class ConversationMembershipChangedEvent extends ChatSyncEvent {
  const ConversationMembershipChangedEvent();
}

/// 纯内存状态：负责消息去重和本地未读计算，独立于 Supabase，便于压测与单测。
class MessageSyncStore {
  final int seenLimit;
  final Map<String, int> _unread = {};
  final LinkedHashSet<String> _seenInsertIds = LinkedHashSet<String>();
  final Map<String, String> _updateFingerprints = {};
  final ListQueue<String> _updateOrder = ListQueue<String>();

  MessageSyncStore({this.seenLimit = 5000});

  Map<String, int> get unreadCounts => Map.unmodifiable(_unread);

  int get totalUnread => _unread.values.fold(0, (sum, count) => sum + count);

  void clear() {
    _unread.clear();
    _seenInsertIds.clear();
    _updateFingerprints.clear();
    _updateOrder.clear();
  }

  void replaceUnread(Map<String, int> values) {
    _unread
      ..clear()
      ..addAll(
        values.map((key, value) => MapEntry(key, value < 0 ? 0 : value)),
      );
  }

  void markRead(String conversationId) {
    _unread[conversationId] = 0;
  }

  bool acceptInsert({
    required Message message,
    required String currentUserId,
    required bool isCurrentConversation,
  }) {
    if (!_seenInsertIds.add(message.id)) return false;
    while (_seenInsertIds.length > seenLimit) {
      _seenInsertIds.remove(_seenInsertIds.first);
    }
    if (message.senderId != currentUserId && !isCurrentConversation) {
      _unread[message.conversationId] =
          (_unread[message.conversationId] ?? 0) + 1;
    } else if (isCurrentConversation) {
      _unread[message.conversationId] = 0;
    }
    return true;
  }

  bool acceptUpdate(Message message) {
    final fingerprint = <Object?>[
      message.content,
      message.mediaUrl,
      message.isDeleted,
      message.messageType,
      message.payload,
    ].join('|');
    if (_updateFingerprints[message.id] == fingerprint) return false;
    _updateFingerprints[message.id] = fingerprint;
    _updateOrder
      ..remove(message.id)
      ..addLast(message.id);
    while (_updateOrder.length > seenLimit) {
      final oldest = _updateOrder.removeFirst();
      _updateFingerprints.remove(oldest);
    }
    return true;
  }
}

class _ConversationMeta {
  final String type;
  final String title;

  const _ConversationMeta({required this.type, required this.title});
}

/// App 内唯一的聊天消息同步入口。
///
/// 每个会话只建立一个私有 Broadcast channel。数据库只广播 message id，
/// 客户端在 100ms 窗口内批量经过 messages RLS 取完整内容，避免绕过退群/拉黑权限。
class MessageSyncService {
  MessageSyncService._();

  static final instance = MessageSyncService._();

  final _client = Supabase.instance.client;
  final _store = MessageSyncStore();
  final _events = StreamController<ChatSyncEvent>.broadcast(sync: true);
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, _ConversationMeta> _conversationMeta = {};
  final Set<String> _pendingMessageIds = {};
  final Map<String, bool> _pendingUpdates = {};
  final Map<String, int> _retryAttempts = {};
  final Map<String, Timer> _retryTimers = {};
  RealtimeChannel? _membershipChannel;

  final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  Stream<ChatSyncEvent> get events => _events.stream;
  Map<String, int> get unreadCounts => _store.unreadCounts;
  bool get hasUnreadSnapshot => _hasUnreadSnapshot;

  String? _userId;
  bool _initialized = false;
  bool _hasUnreadSnapshot = false;
  bool _foreground = true;
  Future<void>? _startFuture;
  String? _startUserId;
  Future<void>? _refreshFuture;
  Future<void>? _unreadRefreshFuture;
  Timer? _batchTimer;
  int _generation = 0;

  int unreadFor(String conversationId) =>
      _store.unreadCounts[conversationId] ?? 0;

  Future<void> start() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Future.value();
    if (_initialized && _userId == uid) return Future.value();
    final running = _startFuture;
    if (running != null) {
      if (_startUserId == uid) return running;
      return running.then((_) => start());
    }
    final future = _start(uid);
    _startFuture = future;
    _startUserId = uid;
    return future.whenComplete(() {
      if (identical(_startFuture, future)) {
        _startFuture = null;
        _startUserId = null;
      }
    });
  }

  Future<void> _start(String uid) async {
    if (_userId != null && _userId != uid) await stop();
    _userId = uid;
    final generation = ++_generation;
    // 先以数据库快照校准未读，再开始接收增量，避免启动竞态把刚收到的
    // 本地 +1 被稍晚返回的旧快照覆盖。
    await refreshUnreadCounts();
    if (generation != _generation || _userId != uid) return;
    await refreshSubscriptions();
    if (generation != _generation || _userId != uid) return;
    _initialized = true;
  }

  Future<void> resume() async {
    _foreground = true;
    final alreadyInitialized = _initialized;
    await start();
    if (alreadyInitialized) {
      await Future.wait([refreshSubscriptions(), refreshUnreadCounts()]);
    }
  }

  void setForeground(bool value) {
    _foreground = value;
  }

  Future<void> stop() async {
    _generation++;
    _refreshFuture = null;
    _unreadRefreshFuture = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingMessageIds.clear();
    _pendingUpdates.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    final channels = _channels.values.toList();
    _channels.clear();
    final membershipChannel = _membershipChannel;
    _membershipChannel = null;
    if (membershipChannel != null) {
      try {
        await _client.removeChannel(membershipChannel);
      } catch (_) {}
    }
    for (final channel in channels) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }
    _conversationMeta.clear();
    _store.clear();
    _hasUnreadSnapshot = false;
    _publishUnread(emitEvent: true);
    _initialized = false;
    _userId = null;
  }

  void registerConversation(Conversation conversation) {
    final uid = _userId ?? _client.auth.currentUser?.id ?? '';
    _conversationMeta[conversation.id] = _ConversationMeta(
      type: conversation.type,
      title: conversation.displayName(uid),
    );
    if (_initialized && !_channels.containsKey(conversation.id)) {
      unawaited(refreshSubscriptions());
    }
  }

  void registerConversations(Iterable<Conversation> conversations) {
    for (final conversation in conversations) {
      registerConversation(conversation);
    }
    if (_userId != null) unawaited(refreshSubscriptions());
  }

  Future<void> refreshSubscriptions() {
    final uid = _userId;
    if (uid == null) return Future.value();
    final generation = _generation;
    final running = _refreshFuture;
    if (running != null) return running;
    final future = _refreshSubscriptionsSafely(uid, generation);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
  }

  Future<void> _refreshSubscriptionsSafely(String uid, int generation) async {
    try {
      await _refreshSubscriptions(uid, generation);
    } catch (_) {
      // 弱网时保留现有频道；回前台或下次注册会话时会再次校准。
    }
  }

  Future<void> _refreshSubscriptions(String uid, int generation) async {
    _ensureMembershipSubscription(uid, generation);
    final rows = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid);
    if (generation != _generation || _userId != uid) return;
    final desired = {
      for (final row in rows as List) row['conversation_id'] as String,
    };

    final obsolete = _channels.keys
        .where((id) => !desired.contains(id))
        .toList();
    for (final id in obsolete) {
      final channel = _channels.remove(id);
      if (channel != null) await _client.removeChannel(channel);
    }
    for (final id in desired) {
      if (generation != _generation || _userId != uid) return;
      if (_channels.containsKey(id)) continue;
      _channels[id] = _subscribeConversation(id, generation);
    }
  }

  void _ensureMembershipSubscription(String uid, int generation) {
    if (_membershipChannel != null || generation != _generation) return;
    _membershipChannel = _client
        .channel('chat_memberships:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'conversation_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => unawaited(
            _handleMembershipInserted(uid: uid, generation: generation),
          ),
        )
        .subscribe();
  }

  Future<void> _handleMembershipInserted({
    required String uid,
    required int generation,
  }) async {
    if (generation != _generation || _userId != uid) return;
    await refreshSubscriptions();
    if (generation == _generation && _userId == uid && !_events.isClosed) {
      _events.add(const ConversationMembershipChangedEvent());
    }
  }

  RealtimeChannel _subscribeConversation(
    String conversationId,
    int generation,
  ) {
    late final RealtimeChannel channel;
    channel =
        _client.channel(
          'conversation:$conversationId:messages',
          opts: const RealtimeChannelConfig(private: true),
        )..onBroadcast(
          event: 'message_changed',
          callback: (frame) =>
              _queueEnvelope(frame, conversationId, generation),
        );
    channel.subscribe((status, _) {
      if (generation != _generation) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _retryAttempts.remove(conversationId);
        _retryTimers.remove(conversationId)?.cancel();
        return;
      }
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (identical(_channels[conversationId], channel)) {
          _channels.remove(conversationId);
          unawaited(_removeChannelSilently(channel));
        }
        final attempt = (_retryAttempts[conversationId] ?? 0) + 1;
        _retryAttempts[conversationId] = attempt;
        final seconds = attempt >= 4 ? 15 : 1 << attempt;
        _retryTimers.remove(conversationId)?.cancel();
        _retryTimers[conversationId] = Timer(Duration(seconds: seconds), () {
          _retryTimers.remove(conversationId);
          if (generation == _generation && _userId != null) {
            unawaited(refreshSubscriptions());
          }
        });
      }
    });
    return channel;
  }

  Future<void> _removeChannelSilently(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (_) {}
  }

  void _queueEnvelope(
    Map<String, dynamic> frame,
    String expectedConversation,
    int generation,
  ) {
    if (generation != _generation || _userId == null) return;
    final raw = frame['payload'];
    if (raw is! Map) return;
    final envelope = Map<String, dynamic>.from(raw);
    final conversationId = envelope['conversation_id'] as String?;
    final messageId = envelope['message_id'] as String?;
    if (conversationId != expectedConversation || messageId == null) return;
    final operation = envelope['operation'];
    if (operation == 'INSERT') {
      // 同一 100ms 窗口内 INSERT 后紧跟 UPDATE 时，INSERT 优先，保证
      // 收件人的未读数只增加一次；取回的仍是数据库中的最新行。
      _pendingUpdates[messageId] = false;
    } else if (operation == 'UPDATE') {
      _pendingUpdates.putIfAbsent(messageId, () => true);
    } else {
      return;
    }
    _pendingMessageIds.add(messageId);
    _batchTimer ??= Timer(const Duration(milliseconds: 100), _flushBatch);
  }

  Future<void> _flushBatch() async {
    _batchTimer = null;
    if (_pendingMessageIds.isEmpty) return;
    final generation = _generation;
    final uid = _userId;
    if (uid == null) return;
    final ids = _pendingMessageIds.take(100).toList();
    final operations = <String, bool>{};
    for (final id in ids) {
      _pendingMessageIds.remove(id);
      operations[id] = _pendingUpdates.remove(id) == true;
    }
    try {
      final rows = await _client
          .from('messages')
          .select('*, profiles(*)')
          .inFilter('id', ids);
      if (generation != _generation || _userId != uid) return;
      final messages =
          (rows as List)
              .map(
                (row) =>
                    Message.fromJson(Map<String, dynamic>.from(row as Map)),
              )
              .where((message) => message.payload?['files_only'] != true)
              .toList()
            ..sort((a, b) {
              final byTime = a.createdAt.compareTo(b.createdAt);
              return byTime != 0 ? byTime : a.id.compareTo(b.id);
            });
      for (final message in messages) {
        final isUpdate = operations[message.id] == true;
        _handleMessage(message, isUpdate: isUpdate);
      }
      // RLS 拒绝或已退群的 id 不会返回；本批 operations 是局部快照，
      // 无需触碰查询期间新到达的同 id UPDATE 事件。
    } catch (_) {
      // Broadcast 不是可靠队列；网络异常由当前页面/回前台 REST 补拉恢复。
    } finally {
      if (_pendingMessageIds.isNotEmpty) {
        _batchTimer ??= Timer(const Duration(milliseconds: 100), _flushBatch);
      }
    }
  }

  void _handleMessage(Message message, {required bool isUpdate}) {
    if (isUpdate) {
      if (!_store.acceptUpdate(message)) return;
    } else {
      final accepted = _store.acceptInsert(
        message: message,
        currentUserId: _userId ?? '',
        isCurrentConversation:
            _foreground && ActiveConversation.current == message.conversationId,
      );
      if (!accepted) return;
      _publishUnread(emitEvent: false);
    }
    final meta = _conversationMeta[message.conversationId];
    _events.add(
      SyncedMessageEvent(
        message: message,
        isUpdate: isUpdate,
        conversationType: meta?.type,
        conversationName: meta?.title,
      ),
    );
  }

  Future<void> refreshUnreadCounts() {
    final running = _unreadRefreshFuture;
    if (running != null) return running;
    final future = _refreshUnreadCounts();
    _unreadRefreshFuture = future;
    return future.whenComplete(() {
      if (identical(_unreadRefreshFuture, future)) {
        _unreadRefreshFuture = null;
      }
    });
  }

  Future<void> _refreshUnreadCounts() async {
    final uid = _userId;
    final generation = _generation;
    if (uid == null) return;
    try {
      final rows = await _client.rpc('get_unread_counts') as List;
      if (generation != _generation || _userId != uid) return;
      _store.replaceUnread({
        for (final row in rows)
          row['conversation_id'] as String: (row['cnt'] as num).toInt(),
      });
      _hasUnreadSnapshot = true;
      _publishUnread(emitEvent: true);
    } catch (_) {}
  }

  void markConversationRead(String conversationId) {
    if ((_store.unreadCounts[conversationId] ?? 0) == 0) return;
    _store.markRead(conversationId);
    _publishUnread(emitEvent: true);
  }

  void _publishUnread({required bool emitEvent}) {
    final total = _store.totalUnread;
    if (totalUnread.value != total) totalUnread.value = total;
    if (emitEvent && !_events.isClosed) {
      _events.add(const UnreadCountsChangedEvent());
    }
  }
}
