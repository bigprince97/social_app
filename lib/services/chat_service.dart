import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import '../models/conversation.dart';
import '../models/message.dart';
import 'local_cache.dart';

class ChatService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ─── Conversations ────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    try {
      final data = await _client
          .from('conversations')
          .select('*, conversation_members(*, profiles(*))')
          .order('last_message_at', ascending: false);
      await LocalCache.instance.write('conversations', data);
      final convs = _processConversations(data as List);
      await _applyUnreadCounts(convs); // 用真实未读数覆盖占位值
      return convs;
    } catch (e) {
      if (isNetworkError(e)) {
        final cached = await LocalCache.instance.read('conversations');
        if (cached is List) return _processConversations(cached);
      }
      rethrow;
    }
  }

  /// 只读本地缓存（不碰网络），用于「缓存优先」秒显。
  Future<List<Conversation>> getCachedConversations() async {
    final cached = await LocalCache.instance.read('conversations');
    if (cached is List) return _processConversations(cached);
    return [];
  }

  Future<List<Message>> getCachedMessages(String conversationId) async {
    final cached = await LocalCache.instance.read('messages_$conversationId');
    if (cached is List) {
      return cached
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
          .reversed
          .toList();
    }
    return [];
  }

  Future<void> cacheMessages(
    String conversationId,
    List<Message> messages, {
    int limit = 100,
  }) async {
    final visible = messages
        .where((message) => message.payload?['files_only'] != true)
        .toList();
    final latest = visible.length > limit
        ? visible.sublist(visible.length - limit)
        : visible;
    await LocalCache.instance.write(
      'messages_$conversationId',
      latest.reversed.map((message) => message.toJson()).toList(),
    );
  }

  /// 拉取每个会话的真实未读数（RPC），覆盖 _processConversations 的占位 1。
  /// 失败时保留占位值（仍能指示"有未读"），不影响列表显示。
  Future<void> _applyUnreadCounts(List<Conversation> convs) async {
    try {
      final counts = await getUnreadCounts();
      for (final c in convs) {
        c.unreadCount = counts[c.id] ?? 0;
      }
    } catch (_) {
      // RPC 不可用：保留布尔占位，不报错
    }
  }

  /// 拉取真实未读消息数。key 是 conversation_id，value 是该会话未读条数。
  Future<Map<String, int>> getUnreadCounts() async {
    final rows = await _client.rpc('get_unread_counts') as List;
    return {
      for (final r in rows)
        (r['conversation_id'] as String): (r['cnt'] as num).toInt(),
    };
  }

  List<Conversation> _processConversations(List data) {
    var convs = data
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final uid = _userId;
    if (uid != null) {
      // 过滤掉「我」已隐藏（软删除）的会话
      convs = convs.where((conv) {
        final me = conv.members.where((m) => m.userId == uid).firstOrNull;
        return me == null || !me.hidden;
      }).toList();
      for (final conv in convs) {
        final me = conv.members.where((m) => m.userId == uid).firstOrNull;
        if (me != null && conv.lastMessageAt != null) {
          if (me.lastReadAt == null ||
              conv.lastMessageAt!.isAfter(me.lastReadAt!)) {
            conv.unreadCount = 1;
          }
        }
      }
    }
    return convs;
  }

  Future<Conversation> createDirectConversation(String otherUserId) async {
    final result = await _client.rpc(
      'create_direct_conversation',
      params: {'other_user_id': otherUserId},
    );
    return Conversation.fromJson(result as Map<String, dynamic>);
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
  }) async {
    final conv = await _client
        .from('conversations')
        .insert({'type': 'group', 'name': name, 'created_by': _userId})
        .select()
        .single();

    final allMembers = [requireUid(_client), ...memberIds];
    await _client
        .from('conversation_members')
        .insert(
          allMembers
              .map(
                (id) => {
                  'conversation_id': conv['id'],
                  'user_id': id,
                  'role': id == _userId ? 'admin' : 'member',
                },
              )
              .toList(),
        );

    final full = await _client
        .from('conversations')
        .select('*, conversation_members(*, profiles(*))')
        .eq('id', conv['id'] as String)
        .single();
    return Conversation.fromJson(full);
  }

  Future<void> disbandGroup(String conversationId) async {
    await _client.from('conversations').delete().eq('id', conversationId);
  }

  /// 修改群名称（RLS 限群主/管理员）
  Future<void> updateGroupName(String conversationId, String name) async {
    await _client
        .from('conversations')
        .update({'name': name})
        .eq('id', conversationId);
  }

  /// 修改群头像 URL（RLS 限群主/管理员）
  Future<void> updateGroupAvatar(String conversationId, String url) async {
    await _client
        .from('conversations')
        .update({'avatar_url': url})
        .eq('id', conversationId);
  }

  /// 删除对话：仅从「我的」列表隐藏（软删除，标记 hidden=true），
  /// 不删成员行——否则会破坏对方的直聊（对方进来找不到我）。
  /// 重新收到/发送消息时会自动取消隐藏。
  Future<void> deleteConversation(String conversationId) async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('conversation_members')
        .update({'hidden': true})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid);
  }

  /// 向群里添加成员（去重已在群成员；以 member 角色加入）
  Future<void> addMembers(String conversationId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    final existing = await _client
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId);
    final existingIds = {
      for (final r in existing as List) r['user_id'] as String,
    };
    final toAdd = userIds.where((id) => !existingIds.contains(id)).toList();
    if (toAdd.isEmpty) return;
    await _client
        .from('conversation_members')
        .insert(
          toAdd
              .map(
                (id) => {
                  'conversation_id': conversationId,
                  'user_id': id,
                  'role': 'member',
                },
              )
              .toList(),
        );
  }

  Future<void> promoteToAdmin(String memberId) async {
    await _client
        .from('conversation_members')
        .update({'role': 'admin'})
        .eq('id', memberId);
  }

  Future<void> demoteToMember(String memberId) async {
    await _client
        .from('conversation_members')
        .update({'role': 'member'})
        .eq('id', memberId);
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 0,
    int limit = 50,
  }) async {
    try {
      final data = await _client
          .from('messages')
          .select('*, profiles(*)')
          .eq('conversation_id', conversationId)
          // 仅进群文件、不在聊天显示的文件（files_only）排除
          .or('payload->>files_only.is.null,payload->>files_only.neq.true')
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      if (page == 0) {
        await LocalCache.instance.write('messages_$conversationId', data);
      }
      return (data as List)
          .map((e) => Message.fromJson(e))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      if (page == 0 && isNetworkError(e)) {
        final cached = await LocalCache.instance.read(
          'messages_$conversationId',
        );
        if (cached is List) {
          return cached
              .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              .reversed
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    Map<String, dynamic>? payload,
    List<String>? mentionedUserIds,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': content,
          'message_type': messageType,
          'media_url': ?mediaUrl,
          'payload': ?payload,
          if (mentionedUserIds?.isNotEmpty == true)
            'mentions': mentionedUserIds,
        })
        .select('*, profiles(*)')
        .single();
    return Message.fromJson(data);
  }

  Future<Message> sendImageMessage({
    required String conversationId,
    required String imageUrl,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'image',
      mediaUrl: imageUrl,
    );
  }

  Future<Message> sendAudioMessage({
    required String conversationId,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'audio',
      mediaUrl: audioUrl,
      payload: {'duration': durationSeconds},
    );
  }

  Future<Message> sendVideoMessage({
    required String conversationId,
    required String videoUrl,
    required int fileSize,
    String? thumbnailUrl,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'video',
      mediaUrl: videoUrl,
      payload: {'size': fileSize, 'thumbnail': thumbnailUrl},
    );
  }

  Future<Message> sendFileMessage({
    required String conversationId,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String? mimeType,
    // true=仅存入群文件、不在聊天中显示（群文件页直接上传）
    bool filesOnly = false,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': fileName,
          'message_type': 'file',
          'media_url': fileUrl,
          'payload': {
            'name': fileName,
            'size': fileSize,
            'mime': mimeType ?? 'application/octet-stream',
            if (filesOnly) 'files_only': true,
          },
        })
        .select('*, profiles(*)')
        .single();
    return Message.fromJson(data);
  }

  Future<Message> sendScriptureMessage({
    required String conversationId,
    required String quoteText,
    required String scriptureTitle,
    required String chapterTitle,
  }) async {
    final content = '$quoteText|||$scriptureTitle|||$chapterTitle';
    return sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: 'scripture',
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'is_deleted': true})
        .eq('id', messageId);
  }

  Future<Message> editMessage({
    required String messageId,
    required String content,
    Map<String, dynamic>? currentPayload,
  }) async {
    final uid = requireUid(_client);
    final payload = <String, dynamic>{
      ...?currentPayload,
      'edited_at': DateTime.now().toIso8601String(),
    };
    final data = await _client
        .from('messages')
        .update({'content': content, 'payload': payload})
        .eq('id', messageId)
        .eq('sender_id', uid)
        .eq('message_type', 'text')
        .eq('is_deleted', false)
        .select('*, profiles(*)')
        .single();
    return Message.fromJson(data);
  }

  /// 更新已读时间：尽力而为，离线/网络异常静默忽略（调用方多为 fire-and-forget）。
  Future<void> updateLastRead(String conversationId) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', uid);
    } catch (_) {
      // 已读回执失败无需打扰用户，也不应抛未捕获异常
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message) onMessage,
  ) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow['sender_id'] == _userId) return;
            final full = await _client
                .from('messages')
                .select('*, profiles(*)')
                .eq('id', newRow['id'] as String)
                .single();
            onMessage(Message.fromJson(full));
          },
        )
        .subscribe();
  }

  // Subscribe to message updates (recall / edit)
  RealtimeChannel subscribeToMessageUpdates(
    String conversationId,
    void Function(Message message) onUpdate,
  ) {
    return _client
        .channel('messages_update:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final updated = payload.newRecord;
            final id = updated['id'] as String?;
            if (id == null) return;
            final full = await _client
                .from('messages')
                .select('*, profiles(*)')
                .eq('id', id)
                .single();
            onUpdate(Message.fromJson(full));
          },
        )
        .subscribe();
  }
}
