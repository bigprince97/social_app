import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';

import '../../services/block_service.dart';
import '../../services/call_service.dart';
import '../../services/chat_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_style.dart';
import '../../utils/content_filter.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/premium_action_sheet.dart';
import '../../widgets/premium_toast.dart';
import '../../services/active_conversation.dart';
import '../../services/local_cache.dart';
import '../../services/message_sync_service.dart';
import '../call/call_screen.dart';
import '../call/livestream_screen.dart';
import '../group/group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _chatService = ChatService();
  final _callService = CallService();
  final _blockService = BlockService();
  final _storageService = StorageService();
  final _inputCtrl = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  final List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _messageLoadGeneration = 0;
  RealtimeChannel? _readChannel;
  RealtimeChannel? _convCallChannel;
  StreamSubscription<ChatSyncEvent>? _messageSyncSubscription;
  CallInfo? _activeLivestream; // 群内进行中的直播（横幅）
  late final String _currentUserId;
  late Conversation _conversation;
  Timer? _readTimer;
  Timer? _livestreamExpiryTimer;
  // 新消息攒批：刷屏时 100ms 内涌入的消息合并为一次 setState，
  // 避免每条消息各触发一次整页重建导致掉帧。
  final List<Message> _pendingIncoming = [];
  Timer? _incomingFlushTimer;
  Timer? _cacheTimer;
  // 长按消息→回复：待引用的消息（输入栏上方显示引用条）
  Message? _replyTo;

  // read receipts
  DateTime? _otherLastReadAt;

  // 直聊：对方是否已被我拉黑（用于菜单显示 拉黑/取消拉黑）
  bool _isOtherBlocked = false;
  // 任一方存在拉黑关系：用于禁用语音/视频来电入口。
  bool _isEitherBlocked = false;

  // voice recording state
  bool _recording = false;
  int _recordSeconds = 0; // 仅驱动录音条 UI 计时显示
  DateTime? _recordStartAt; // 真实时长用墙钟，见 _stopRecording
  Timer? _recordTimer;
  String? _recordingPath;

  // @mention state
  bool _showMentionPicker = false;
  String _mentionQuery = '';
  final List<String> _mentionedUserIds = [];

  // 群主=会话创建者；管理员=role admin（群主含管理员权限）。
  // 只有群主/管理员能开关直播。
  bool get _canManageGroup {
    if (_conversation.createdBy == _currentUserId) return true;
    final me = _conversation.members
        .where((m) => m.userId == _currentUserId)
        .firstOrNull;
    return me?.role == 'admin';
  }

  // Group member display names for @mention highlight
  List<String> get _memberDisplayNames => _conversation.members
      .where((m) => m.userId != _currentUserId)
      .map((m) => m.profile?.displayName ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

  List<ConversationMember> get _mentionableMembers => _conversation.members
      .where((m) => m.userId != _currentUserId)
      .where((m) => m.profile != null)
      .where(
        (m) =>
            _mentionQuery.isEmpty ||
            (m.profile!.displayName.toLowerCase().contains(
              _mentionQuery.toLowerCase(),
            )),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _conversation = widget.conversation;
    ActiveConversation.enter(_conversation.id);
    MessageSyncService.instance.registerConversation(_conversation);
    unawaited(MessageSyncService.instance.start());
    // 进入会话:清除通知栏里属于本会话的所有通知
    PushNotificationService.clearConversationNotifications(_conversation.id);
    _computeOtherLastRead();
    _loadBlockState();
    _refreshConversationMetadata();
    _loadMessages();
    _subscribeToMessageSync();
    _subscribeToReadReceipts();
    // 进入聊天立即标记已读一次（清未读 badge），再用定时器跟进后续新消息。
    _markReadAndRefreshBadge();
    _scheduleUpdateLastRead();
    _inputCtrl.addListener(_onInputChanged);
    _scrollController.addListener(_onScroll);
    if (_conversation.type == 'group') {
      _refreshActiveLivestream();
      _convCallChannel = _callService.subscribeToConversationCalls(
        _conversation.id,
        _refreshActiveLivestream,
      );
    }
  }

  Future<void> _refreshActiveLivestream() async {
    try {
      final live = await _callService.getActiveLivestream(_conversation.id);
      if (!mounted) return;
      setState(() => _activeLivestream = live);
      _scheduleLivestreamExpiryCheck(live);
    } catch (_) {}
  }

  /// 页面先使用路由传入的数据立即显示，再在后台只刷新当前会话的名称、
  /// 公告、成员和用户资料，避免为了一个会话重拉整个列表。
  Future<void> _refreshConversationMetadata() async {
    try {
      final latest = await _chatService.getConversation(_conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = latest;
        _computeOtherLastRead();
      });
      MessageSyncService.instance.registerConversation(latest);
    } catch (_) {
      // 离线时继续使用路由传入的会话快照。
    }
  }

  void _scheduleLivestreamExpiryCheck(CallInfo? live) {
    _livestreamExpiryTimer?.cancel();
    if (live == null) return;
    final lastHeartbeat = live.lastHeartbeatAt ?? live.createdAt;
    final expiresAt = lastHeartbeat.add(const Duration(seconds: 46));
    final delay = expiresAt.difference(DateTime.now());
    _livestreamExpiryTimer = Timer(
      delay.isNegative ? const Duration(milliseconds: 300) : delay,
      _refreshActiveLivestream,
    );
  }

  Future<void> _joinLivestream(CallInfo live) async {
    try {
      final tokenData = await _callService.getLiveKitToken(
        room: live.livekitRoom!,
        canPublish: true, // 观众也可连麦（开麦/开视频），默认进来不推流
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LivestreamScreen(
            call: live,
            livekitUrl: tokenData.url,
            livekitToken: tokenData.token,
            isHost: false,
            canManageLivestream: _canManageGroup,
            groupName: _conversation.name ?? AppLocalizations.of(context).group,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).joinLivestreamFailed(e),
          kind: ToastKind.error,
        );
      }
    }
  }

  void _onScroll() {
    // 倒序列表：顶部=更早消息=接近 maxScrollExtent
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  // 倒序列表中「底部=最新」对应 offset 0
  bool get _isNearBottom =>
      !_scrollController.hasClients || _scrollController.position.pixels <= 150;

  void _scheduleUpdateLastRead() {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(seconds: 2), () {
      _markReadAndRefreshBadge();
    });
  }

  Future<void> _markReadAndRefreshBadge() async {
    MessageSyncService.instance.markConversationRead(_conversation.id);
    await _chatService.updateLastRead(_conversation.id);
    // 回前台时未读校准可能与已读 RPC 并发；落库后再清一次，避免旧快照
    // 把刚进入的会话红点短暂恢复出来。
    MessageSyncService.instance.markConversationRead(_conversation.id);
  }

  void _computeOtherLastRead() {
    if (_conversation.type != 'direct') return;
    final other = _conversation.members
        .where((m) => m.userId != _currentUserId)
        .firstOrNull;
    _otherLastReadAt = other?.lastReadAt;
  }

  bool _inputIsEmpty = true;

  void _onInputChanged() {
    final text = _inputCtrl.text;
    final isEmpty = text.trim().isEmpty;
    if (isEmpty != _inputIsEmpty) {
      setState(() => _inputIsEmpty = isEmpty);
    }
    final cursor = _inputCtrl.selection.baseOffset;
    if (cursor < 0) return;

    // Detect if cursor is right after an @ sequence
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx != -1 && !before.substring(atIdx).contains(' ')) {
      final query = before.substring(atIdx + 1);
      if (!_showMentionPicker || query != _mentionQuery) {
        setState(() {
          _showMentionPicker = true;
          _mentionQuery = query;
        });
      }
    } else if (_showMentionPicker) {
      setState(() => _showMentionPicker = false);
    }
  }

  // 用 removeChannel 而非 unsubscribe：后者不从客户端注册表移除同名 topic 频道，
  // 反复切后台/前台会累积僵尸频道。removeChannel 会一并退订并移除。
  void _removeCh(RealtimeChannel? ch) {
    if (ch != null) Supabase.instance.client.removeChannel(ch);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回前台：校准一次未读并补拉后台期间可能漏掉的当前会话消息。
    if (state == AppLifecycleState.resumed) {
      // 后台期间该会话可能积了新通知,回前台仍在本页则一并清除
      PushNotificationService.clearConversationNotifications(_conversation.id);
      _removeCh(_readChannel);
      unawaited(MessageSyncService.instance.resume());
      _markReadAndRefreshBadge();
      _loadMessages();
      _subscribeToReadReceipts();
      if (_conversation.type == 'group') {
        _refreshActiveLivestream();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ActiveConversation.leave(_conversation.id);
    _messageSyncSubscription?.cancel();
    _removeCh(_readChannel);
    _removeCh(_convCallChannel);
    _inputCtrl.removeListener(_onInputChanged);
    _scrollController.removeListener(_onScroll);
    _inputCtrl.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    _readTimer?.cancel();
    _incomingFlushTimer?.cancel();
    _cacheTimer?.cancel();
    _cacheCurrentMessagesNow();
    _livestreamExpiryTimer?.cancel();
    // 离开聊天时立即落库已读：避免 2s 内快速返回时定时器被取消，
    // 导致 last_read 未更新、会话列表未读 badge 不清除。
    unawaited(_markReadAndRefreshBadge());
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final generation = ++_messageLoadGeneration;
    if (mounted) {
      setState(() {
        _page = 0;
        _hasMore = true;
      });
    }
    // 缓存优先：先秒显本地缓存的历史消息（不等网络），再后台拉新替换。
    try {
      final cached = await _chatService.getCachedMessages(
        _conversation.id,
        conversationType: _conversation.type,
      );
      if (mounted &&
          generation == _messageLoadGeneration &&
          cached.isNotEmpty &&
          _messages.isEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(cached);
          _loading = false;
        });
      }
    } catch (_) {}
    if (mounted && generation == _messageLoadGeneration && _messages.isEmpty) {
      setState(() => _loading = true);
    }
    final messageIdsBeforeNetwork = _messages.map((m) => m.id).toSet();
    try {
      // 后台拉新（超时兜底，避免 iOS 半开连接永久挂起转圈）
      final msgs = await _chatService
          .getMessages(
            _conversation.id,
            conversationType: _conversation.type,
            page: 0,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted || generation != _messageLoadGeneration) return;
      setState(() {
        // REST 拉取和 Realtime/发送可能并发：保留刷新开始后才出现、且本次
        // 响应尚未包含的消息，避免网络响应把刚发出/刚收到的气泡覆盖掉。
        final concurrent = _messages
            .where(
              (local) =>
                  local.isUploading ||
                  (!messageIdsBeforeNetwork.contains(local.id) &&
                      !msgs.any((remote) => remote.id == local.id)),
            )
            .toList();
        _messages
          ..clear()
          ..addAll(msgs)
          ..addAll(
            concurrent.where(
              (local) => !msgs.any((remote) => remote.id == local.id),
            ),
          );
        if (msgs.length < 50) _hasMore = false;
      });
    } catch (_) {
      // 超时/网络错误：保留已显示的缓存消息，不弹错（离线优雅降级）
    } finally {
      if (mounted && generation == _messageLoadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final older = await _chatService.getMessages(
        _conversation.id,
        conversationType: _conversation.type,
        page: nextPage,
      );
      if (!mounted) return;
      if (older.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      // reverse:true：更早消息插入数据头部 → 渲染在列表顶部，
      // 视口从底部锚定，插入顶部不会跳动，无需手动保持偏移。
      setState(() {
        _messages.insertAll(0, older);
        _page = nextPage;
        if (older.length < 50) _hasMore = false;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _cacheCurrentMessages() {
    // 刷屏时合并磁盘写入，避免每 100ms 都序列化并写一遍历史消息。
    _cacheTimer?.cancel();
    _cacheTimer = Timer(
      const Duration(milliseconds: 750),
      _cacheCurrentMessagesNow,
    );
  }

  void _cacheCurrentMessagesNow() {
    // 不缓存乐观占位（上传中）消息，否则重启后会残留“发送中”的僵尸气泡。
    final persistable = _messages.where((m) => !m.isUploading).toList();
    unawaited(_chatService.cacheMessages(_conversation.id, persistable));
  }

  void _subscribeToMessageSync() {
    _messageSyncSubscription?.cancel();
    _messageSyncSubscription = MessageSyncService.instance.events.listen((
      event,
    ) {
      if (event is! SyncedMessageEvent ||
          event.message.conversationId != _conversation.id ||
          !mounted) {
        return;
      }
      final msg = event.message;
      if (event.isUpdate) {
        final idx = _messages.indexWhere((message) => message.id == msg.id);
        if (idx == -1) return;
        setState(() => _messages[idx] = msg);
        _cacheCurrentMessages();
        return;
      }
      if (!mounted) return;
      // 仅进群文件、不在聊天显示的文件跳过
      if (msg.payload?['files_only'] == true) return;
      final existingIndex = _messages.indexWhere(
        (message) => message.id == msg.id,
      );
      if (existingIndex != -1) {
        // 自己的消息使用同一个 UUID 作为占位和数据库主键。Broadcast 可能
        // 比 REST 响应更早到达，此时原位确认，不增加第二个气泡。
        if (_messages[existingIndex].isUploading) {
          setState(() => _messages[existingIndex] = msg);
          _cacheCurrentMessages();
        }
        return;
      }
      if (_pendingIncoming.any((message) => message.id == msg.id)) {
        return;
      }
      _pendingIncoming.add(msg);
      // 攒批而非逐条 setState：刷屏时几十次整页重建 → 合并为 1 次
      _incomingFlushTimer ??= Timer(
        const Duration(milliseconds: 100),
        _flushIncomingMessages,
      );
    });
  }

  void _flushIncomingMessages() {
    _incomingFlushTimer = null;
    if (!mounted || _pendingIncoming.isEmpty) return;
    // flush 时再去重一次：攒批期间 _loadMessages 可能已经拉到同批消息
    final batch =
        _pendingIncoming
            .where((p) => !_messages.any((m) => m.id == p.id))
            .toList()
          ..sort((a, b) {
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    _pendingIncoming.clear();
    if (batch.isEmpty) return;
    // 收到对方新消息：仅当用户已在底部时自动滚动，避免打断上翻阅读
    final wasNearBottom = _isNearBottom;
    setState(() {
      _messages.addAll(batch);
      _messages.sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    });
    _cacheCurrentMessages();
    if (wasNearBottom) _scrollToBottom();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _scheduleUpdateLastRead();
    }
  }

  // 直聊：订阅对方 last_read_at 变化，对方读到我的消息时即时刷新「已读」状态。
  void _subscribeToReadReceipts() {
    if (_conversation.type != 'direct') return;
    _readChannel = Supabase.instance.client
        .channel('read:${_conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversation_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversation.id,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row['user_id'] == _currentUserId) return; // 只关心对方
            final ts = row['last_read_at'] as String?;
            if (ts == null) return;
            final dt = DateTime.tryParse(ts);
            if (dt != null && mounted) {
              setState(() => _otherLastReadAt = dt);
            }
          },
        )
        .subscribe();
  }

  // 倒序列表：底部=最新=offset 0
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Send text ──────────────────────────────────────────────────────────

  void _startReply(Message msg) {
    setState(() => _replyTo = msg);
    _inputFocusNode.requestFocus();
  }

  Map<String, dynamic>? _replyPayloadFor(Message? message) => message == null
      ? null
      : <String, dynamic>{'reply_to': message.toReplyMetadata()};

  void _clearReplyIfMatches(String? repliedMessageId) {
    if (!mounted || repliedMessageId == null) return;
    if (_replyTo?.id == repliedMessageId) setState(() => _replyTo = null);
  }

  Future<void> _sendMessage() async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    if (_conversation.type == 'direct' && _isEitherBlocked) {
      _showSendError(const BlockedChatException());
      return;
    }
    final mentionIds = List<String>.from(_mentionedUserIds);
    final replyTo = _replyTo;
    final payload = _replyPayloadFor(replyTo);
    // 客户端先生成最终消息主键：REST 超时但数据库已提交时，Broadcast
    // 仍能用同一 UUID 确认占位，重试也不会制造第二条消息。
    final tempId = const Uuid().v4();
    _inputCtrl.clear();
    _mentionedUserIds.clear();
    if (replyTo != null) setState(() => _replyTo = null);
    // 先显示本地气泡，网络确认后原位替换，用户不再感觉“按下发送后顿一下”。
    _addPendingMedia(
      tempId: tempId,
      messageType: 'text',
      content: content,
      payload: payload ?? const {},
    );
    try {
      final msg = await _chatService.sendMessage(
        messageId: tempId,
        conversationId: _conversation.id,
        content: content,
        mentionedUserIds: mentionIds.isEmpty ? null : mentionIds,
        payload: payload,
      );
      _replacePending(tempId, msg);
      _clearReplyIfMatches(replyTo?.id);
      _cacheCurrentMessages();
    } catch (e) {
      final confirmed = _messages.any(
        (message) => message.id == tempId && !message.isUploading,
      );
      if (confirmed) {
        _cacheCurrentMessages();
      } else {
        _removePending(tempId);
      }
      if (mounted && !confirmed) {
        _showSendError(e);
        // 连续快速发送时，较早请求失败不能覆盖用户已经输入的下一条内容。
        if (_inputCtrl.text.trim().isEmpty) {
          _inputCtrl.text = content;
          _inputCtrl.selection = TextSelection.collapsed(
            offset: content.length,
          );
          _mentionedUserIds
            ..clear()
            ..addAll(mentionIds);
          if (replyTo != null && _replyTo == null) {
            setState(() => _replyTo = replyTo);
          }
        }
      }
    }
  }

  // 发送失败提示：被对方拉黑(RLS 42501)→明确提示；网络/离线→静默不弹错
  void _showSendError(Object e) {
    final s = e.toString();
    if (e is BlockedChatException ||
        s.contains('42501') ||
        s.contains('row-level security')) {
      showPremiumToast(
        context,
        AppLocalizations.of(context).blockedCannotSend,
        kind: ToastKind.block,
      );
      return;
    }
    showErrorIfNotNetwork(
      context,
      e,
      AppLocalizations.of(context).sendFailed(_retryLaterMessage(context)),
    );
  }

  String _retryLaterMessage(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'ja') return 'しばらくしてからもう一度お試しください';
    if (locale.languageCode == 'en') return 'Please try again later';
    return '请稍后重试';
  }

  // 发送前大小拦截：Supabase 后台上限 500MB，客户端设 490MB 留余量
  // （multipart 编码会有少量额外字节）。超限直接提示，不再默默失败。
  static const int _kMaxUploadBytes = 490 * 1000 * 1000;

  /// 文件超过上限则弹提示并返回 true（调用方据此中止发送）。
  bool _rejectIfTooLarge(int bytes) {
    if (bytes <= _kMaxUploadBytes) return false;
    if (mounted) {
      final mb = (bytes / (1000 * 1000)).round();
      showPremiumToast(
        context,
        '文件过大（约 $mb MB），最大支持 500 MB',
        kind: ToastKind.error,
      );
    }
    return true;
  }

  // ─── @mention picker ────────────────────────────────────────────────────

  void _selectMention(ConversationMember member) {
    final text = _inputCtrl.text;
    final cursor = _inputCtrl.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx == -1) return;
    final after = text.substring(cursor);
    final name = member.profile!.displayName;
    final newText = '${text.substring(0, atIdx)}@$name $after';
    _inputCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + name.length + 2),
    );
    if (!_mentionedUserIds.contains(member.userId)) {
      _mentionedUserIds.add(member.userId);
    }
    setState(() => _showMentionPicker = false);
  }

  // ─── Voice recording (tap to start / tap to stop) ───────────────────────

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Request permission first; if denied, bail out
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      // iOS 的系统权限弹窗一生只弹一次,之后请求会被静默拒绝
      // (permanentlyDenied):必须引导用户去系统设置手动开启
      if (status.isPermanentlyDenied) {
        final go = await showPremiumConfirm(
          context,
          title: AppLocalizations.of(context).microphonePermissionRequired,
          message: '请在系统设置中允许 Omega 使用麦克风,才能发送语音消息。',
          confirmLabel: '去设置',
          icon: Icons.mic_off_rounded,
        );
        if (go) await openAppSettings();
      } else {
        showPremiumToast(
          context,
          AppLocalizations.of(context).microphonePermissionRequired,
          kind: ToastKind.info,
        );
      }
      return;
    }
    // If somehow already recording, stop first
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    final dir = await getTemporaryDirectory();
    // 编码器按平台分：
    // - iOS：AVAudioRecorder 不支持 Opus，必须用 aacLc(.m4a)，否则录音直接失败。
    // - Android：用 Opus(.ogg) 走 media3 软解，跨设备最稳；
    //   （aacLc 在部分 Samsung 设备硬解 MediaCodecAudioRenderer 报错无法播放。）
    final useOpus = !Platform.isIOS;
    final ext = useOpus ? 'ogg' : 'm4a';
    final encoder = useOpus ? AudioEncoder.opus : AudioEncoder.aacLc;
    _recordingPath =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: 32000,
        sampleRate: 48000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    _recordSeconds = 0;
    _recordStartAt = DateTime.now();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    // 用墙钟时间算时长并立即捕获为局部变量：
    // ① Timer 每秒 tick，<1s 的录音 _recordSeconds=0 会被误丢；
    // ② 上传是异步的，期间开始下一条录音会重置实例变量（竞态）。
    final startedAt = _recordStartAt;
    _recordStartAt = null;
    final durMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (cancel || path == null) return;
    if (durMs < 500) {
      // 太短：明确提示，不再静默丢弃
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).recordingTooShort,
          kind: ToastKind.info,
        );
      }
      return;
    }
    final durationSeconds = (durMs / 1000).round().clamp(1, 6000);
    if (!mounted) return;
    final replyTo = _replyTo;
    final replyPayload = _replyPayloadFor(replyTo);
    setState(() => _sending = true);
    try {
      final audioBytes = await File(path).readAsBytes();
      final ext = path.contains('.') ? path.split('.').last : 'ogg';
      final url = await _storageService.uploadChatAudio(audioBytes, ext: ext);
      final msg = await _chatService.sendAudioMessage(
        conversationId: _conversation.id,
        audioUrl: url,
        durationSeconds: durationSeconds,
        replyPayload: replyPayload,
      );
      if (mounted) {
        setState(() => _messages.add(msg));
        _clearReplyIfMatches(replyTo?.id);
        _cacheCurrentMessages();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _showSendError(e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ─── File attachments ────────────────────────────────────────────────────

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF1C1C1E).withAlpha(220)
        : Colors.white.withAlpha(230);

    showGeneralDialog(
      context: context,
      barrierLabel: '发送',
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(60),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, _) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(curved),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(18)
                                : Colors.white.withAlpha(160),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 90 : 28),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    bottom: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).attachmentTitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _AttachItem(
                                      icon: Icons.photo_library_rounded,
                                      label: AppLocalizations.of(
                                        context,
                                      ).attachmentPhoto,
                                      color: const Color(0xFF34C759),
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _pickAndConfirmImage(
                                          ImageSource.gallery,
                                        );
                                      },
                                    ),
                                    _AttachItem(
                                      icon: Icons.videocam_rounded,
                                      label: AppLocalizations.of(
                                        context,
                                      ).attachmentVideo,
                                      color: const Color(0xFFFF453A),
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _sendVideo();
                                      },
                                    ),
                                    _AttachItem(
                                      icon: Icons.insert_drive_file_rounded,
                                      label: AppLocalizations.of(context).files,
                                      color: const Color(0xFF0A84FF),
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _sendFile();
                                      },
                                    ),
                                    _AttachItem(
                                      icon: Icons.camera_alt_rounded,
                                      label: AppLocalizations.of(
                                        context,
                                      ).attachmentCamera,
                                      color: const Color(0xFFAF52DE),
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _pickAndConfirmImage(
                                          ImageSource.camera,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndConfirmImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (picked == null) return;
    final confirmed = await _confirmImageSend(picked);
    if (!mounted || !confirmed) return;
    await _uploadAndSendImage(picked);
  }

  Future<bool> _confirmImageSend(XFile picked) async {
    final t = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.imagePlaceholder),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(picked.path),
              fit: BoxFit.contain,
              width: double.maxFinite,
              height: 320,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.send),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _uploadAndSendImage(XFile picked) async {
    final replyTo = _replyTo;
    final replyPayload = _replyPayloadFor(replyTo);
    setState(() => _sending = true);
    try {
      final imageUrl = await _storageService.uploadChatImage(picked);
      final msg = await _chatService.sendImageMessage(
        conversationId: _conversation.id,
        imageUrl: imageUrl,
        replyPayload: replyPayload,
      );
      if (mounted) {
        setState(() => _messages.add(msg));
        _clearReplyIfMatches(replyTo?.id);
        _cacheCurrentMessages();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _showSendError(e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted) return;
    if (picked == null) return;
    final vsize = await picked.length();
    if (!mounted) return;
    if (_rejectIfTooLarge(vsize)) return;
    Uint8List? thumbnailBytes;
    try {
      thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: picked.path,
        maxWidth: 720,
        timeMs: 100,
        quality: 80,
      );
    } catch (_) {
      // 极少数系统不支持的视频编码仍允许发送，只退回无封面占位。
    }
    final replyTo = _replyTo;
    final replyPayload = _replyPayloadFor(replyTo);
    // 乐观发送：立刻插入占位气泡，上传过程中实时更新进度，不等发完才显示。
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    _addPendingMedia(
      tempId: tempId,
      messageType: 'video',
      payload: {
        'local_path': picked.path,
        'thumbnail_bytes': ?thumbnailBytes,
        ...?replyPayload,
      },
    );
    try {
      final uploaded = await _storageService.uploadChatVideo(picked);
      String? thumbnailUrl;
      if (thumbnailBytes != null) {
        try {
          thumbnailUrl = await _storageService.uploadChatVideoThumbnail(
            thumbnailBytes,
          );
        } catch (_) {
          // 封面上传失败不应阻断视频本身发送。
        }
      }
      final msg = await _chatService.sendVideoMessage(
        conversationId: _conversation.id,
        videoUrl: uploaded.url,
        fileSize: uploaded.size,
        thumbnailUrl: thumbnailUrl,
        replyPayload: replyPayload,
      );
      _replacePending(tempId, msg);
      _clearReplyIfMatches(replyTo?.id);
      _cacheCurrentMessages();
    } catch (e) {
      _removePending(tempId);
      if (mounted) _showSendError(e);
    }
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes =
        picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (!mounted) return;
    if (bytes == null) return;
    if (_rejectIfTooLarge(bytes.length)) return;
    final mime = picked.extension != null
        ? _mimeFromExt(picked.extension!)
        : null;
    final replyTo = _replyTo;
    final replyPayload = _replyPayloadFor(replyTo);
    // 乐观发送：立刻插入占位气泡（含文件名/大小/图标），上传中实时进度条。
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    _addPendingMedia(
      tempId: tempId,
      messageType: 'file',
      content: picked.name,
      payload: {
        'name': picked.name,
        'size': bytes.length,
        'mime': mime ?? 'application/octet-stream',
        ...?replyPayload,
      },
    );
    try {
      final uploaded = await _storageService.uploadChatFile(bytes, picked.name);
      final msg = await _chatService.sendFileMessage(
        conversationId: _conversation.id,
        fileUrl: uploaded.url,
        fileName: picked.name,
        fileSize: uploaded.size,
        mimeType: mime,
        replyPayload: replyPayload,
      );
      _replacePending(tempId, msg);
      _clearReplyIfMatches(replyTo?.id);
      _cacheCurrentMessages();
    } catch (e) {
      _removePending(tempId);
      if (mounted) _showSendError(e);
    }
  }

  // ─── 乐观发送占位气泡：插入 / 成功替换 / 失败移除 ────────────────────────
  void _addPendingMedia({
    required String tempId,
    required String messageType,
    String? content,
    Map<String, dynamic> payload = const {},
  }) {
    final pending = Message(
      id: tempId,
      conversationId: _conversation.id,
      senderId: _currentUserId,
      content: content,
      messageType: messageType,
      createdAt: DateTime.now(),
      // 不带 upload_progress → 气泡显示不确定态转圈（“发送中…”）
      payload: {'pending': true, ...payload},
    );
    setState(() => _messages.add(pending));
    _scrollToBottom();
  }

  void _replacePending(String tempId, Message real) {
    if (!mounted) return;
    setState(() {
      final tempIdx = _messages.indexWhere((m) => m.id == tempId);
      final realIdx = _messages.indexWhere((m) => m.id == real.id);
      if (tempIdx != -1 && realIdx == tempIdx) {
        // UUID 幂等发送：临时占位和服务端真实消息本来就是同一个 id。
        _messages[tempIdx] = real;
      } else if (realIdx != -1) {
        // realtime 已抢先插入真实消息：移除临时占位，避免重复
        if (tempIdx != -1) _messages.removeAt(tempIdx);
      } else if (tempIdx != -1) {
        _messages[tempIdx] = real;
      } else {
        _messages.add(real);
      }
    });
    _scrollToBottom();
  }

  void _removePending(String tempId) {
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == tempId));
  }

  String? _mimeFromExt(String ext) {
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
    };
    return map[ext.toLowerCase()];
  }

  // ─── Calls ───────────────────────────────────────────────────────────────

  Future<void> _startCall(String callType) async {
    final isDirect = _conversation.type == 'direct';
    final otherMember = isDirect
        ? _conversation.members
              .where((m) => m.userId != _currentUserId)
              .firstOrNull
        : null;
    try {
      final call = await _callService.createCall(
        conversationId: _conversation.id,
        callType: callType,
        calleeId: otherMember?.userId,
      );
      final tokenData = await _callService.getLiveKitToken(
        room: call.livekitRoom!,
        canPublish: true,
      );
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              call: call,
              livekitUrl: tokenData.url,
              livekitToken: tokenData.token,
              displayName: _conversation.displayName(_currentUserId),
            ),
          ),
        );
        // 通话结束返回后刷新一次，确保通话记录立即出现（不依赖 realtime 延迟）
        if (mounted) _reloadLatestMessages();
      }
    } catch (e) {
      if (mounted) {
        if (e is BlockedCallException ||
            (e is PostgrestException && e.code == '42501')) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).blockedCannotCall,
            kind: ToastKind.block,
          );
          await _loadBlockState();
          return;
        }
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).callStartFailed(e.toString()),
        );
      }
    }
  }

  /// 拉取最新消息并并入列表（去重），用于通话结束等场景即时刷新
  Future<void> _reloadLatestMessages() async {
    try {
      final msgs = await _chatService.getMessages(
        _conversation.id,
        conversationType: _conversation.type,
      );
      if (!mounted) return;
      final existing = _messages.map((m) => m.id).toSet();
      final fresh = msgs.where(
        (m) => !existing.contains(m.id) && m.payload?['files_only'] != true,
      );
      if (fresh.isEmpty) return;
      setState(() => _messages.addAll(fresh));
      _cacheCurrentMessages();
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _startLivestream() async {
    try {
      final call = await _callService.createCall(
        conversationId: _conversation.id,
        callType: 'livestream',
      );
      final tokenData = await _callService.getLiveKitToken(
        room: call.livekitRoom!,
        canPublish: true,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivestreamScreen(
              call: call,
              livekitUrl: tokenData.url,
              livekitToken: tokenData.token,
              isHost: true,
              canManageLivestream: _canManageGroup,
              groupName:
                  _conversation.name ?? AppLocalizations.of(context).group,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).livestreamStartFailed(e.toString()),
        );
      }
    }
  }

  // ─── Recall (optimistic) ─────────────────────────────────────────────────

  void _recallMessage(String messageId) {
    // Unfocus after a frame so we run after Flutter's focus-restoration
    // that fires when the bottom sheet closes, preventing keyboard re-open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.unfocus();
    });
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final old = _messages[idx];
    setState(() {
      _messages[idx] = Message(
        id: old.id,
        conversationId: old.conversationId,
        senderId: old.senderId,
        content: old.content,
        messageType: old.messageType,
        mediaUrl: old.mediaUrl,
        isDeleted: true,
        createdAt: old.createdAt,
        sender: old.sender,
        payload: old.payload,
      );
    });
    _cacheCurrentMessages();
    _chatService.deleteMessage(messageId);
  }

  Future<void> _showEditMessageDialog(Message message) async {
    final ctrl = TextEditingController(text: message.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑消息'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: '输入消息',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = ctrl.text.trim();
                if (value.isEmpty || value == (message.content ?? '').trim()) {
                  Navigator.pop(dialogContext);
                  return;
                }
                if (ContentFilter.hasBanned(value)) {
                  showPremiumToast(
                    dialogContext,
                    AppLocalizations.of(context).contentBlocked,
                    kind: ToastKind.block,
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    await _editMessage(message, result);
  }

  Future<void> _editMessage(Message message, String content) async {
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx == -1) return;
    final old = _messages[idx];
    final editedPayload = <String, dynamic>{
      ...?old.payload,
      'edited_at': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages[idx] = old.copyWith(content: content, payload: editedPayload);
    });
    _cacheCurrentMessages();
    try {
      final updated = await _chatService.editMessage(
        messageId: message.id,
        content: content,
        currentPayload: old.payload,
      );
      if (!mounted) return;
      setState(() {
        final currentIdx = _messages.indexWhere((m) => m.id == message.id);
        if (currentIdx != -1) _messages[currentIdx] = updated;
      });
      _cacheCurrentMessages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final currentIdx = _messages.indexWhere((m) => m.id == message.id);
        if (currentIdx != -1) _messages[currentIdx] = old;
      });
      _cacheCurrentMessages();
      showPremiumToast(context, '编辑失败，请稍后重试', kind: ToastKind.error);
    }
  }

  // ─── Group actions ───────────────────────────────────────────────────────

  Future<void> _loadBlockState() async {
    if (_conversation.type != 'direct') return;
    final other = _conversation.members
        .where((m) => m.userId != _currentUserId)
        .firstOrNull;
    if (other == null) return;
    try {
      final results = await Future.wait([
        _blockService.isBlocked(other.userId),
        _blockService.isEitherBlocked(other.userId),
      ]);
      if (mounted) {
        setState(() {
          _isOtherBlocked = results[0];
          _isEitherBlocked = results[1];
        });
      }
    } catch (_) {}
  }

  void _showBlockDialog(String otherUserId, String otherName) async {
    final t = AppLocalizations.of(context);
    if (_isOtherBlocked) {
      // 已拉黑 → 取消拉黑
      final confirm = await showPremiumConfirm(
        context,
        icon: Icons.lock_open_rounded,
        title: t.unblock,
        message: t.unblockConfirm(otherName),
        confirmLabel: t.unblock,
      );
      if (!confirm) return;
      await _blockService.unblockUser(otherUserId);
      if (mounted) {
        final stillBlocked = await _blockService.isEitherBlocked(otherUserId);
        if (!mounted) return;
        setState(() {
          _isOtherBlocked = false;
          _isEitherBlocked = stillBlocked;
        });
        showPremiumToast(
          context,
          t.userUnblocked(otherName),
          kind: ToastKind.success,
        );
      }
      return;
    }
    final confirm = await showPremiumConfirm(
      context,
      icon: Icons.block_rounded,
      title: t.blockUserTitle,
      message: t.blockUserConfirm2(otherName),
      confirmLabel: t.block,
      destructive: true,
    );
    if (!confirm) return;
    await _blockService.blockUser(otherUserId);
    if (mounted) {
      setState(() {
        _isOtherBlocked = true;
        _isEitherBlocked = true;
      });
      showPremiumToast(
        context,
        t.userBlocked2(otherName),
        kind: ToastKind.block,
      );
    }
  }

  void _openGroupInfo() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          conversation: _conversation,
          onAnnouncementUpdated: (a) {
            setState(() => _conversation.announcement = a.isEmpty ? null : a);
          },
          onGroupUpdated: () {
            // 群名/群头像被修改后刷新聊天页标题栏
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context);
  }

  void _openUserProfile(String userId) {
    context.push('/profile/$userId');
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _conversation.displayName(_currentUserId);
    final isGroup = _conversation.type == 'group';
    final isDirect = _conversation.type == 'direct';
    final messagesById = {for (final message in _messages) message.id: message};
    final otherMember = isDirect
        ? _conversation.members
              .where((m) => m.userId != _currentUserId)
              .firstOrNull
        : null;
    final avatarUrl = _conversation.displayAvatar(_currentUserId);

    return Scaffold(
      backgroundColor: kChatBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar with online dot
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isGroup
                  ? _openGroupInfo
                  : isDirect && otherMember != null
                  ? () => _openUserProfile(otherMember.userId)
                  : null,
              child: Semantics(
                button: isGroup || (isDirect && otherMember != null),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withAlpha(40),
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              title.isNotEmpty ? title[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9575CD),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isGroup
                    ? _openGroupInfo
                    : isDirect && otherMember != null
                    ? () => _openUserProfile(otherMember.userId)
                    : null,
                child: Semantics(
                  button: isGroup || (isDirect && otherMember != null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isGroup
                            ? AppLocalizations.of(
                                context,
                              ).memberCount(_conversation.members.length)
                            : AppLocalizations.of(context).online,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (isDirect && otherMember != null) ...[
            IconButton(
              icon: Icon(
                Icons.call_outlined,
                color: _isEitherBlocked ? Colors.white38 : Colors.white,
              ),
              tooltip: AppLocalizations.of(context).voiceCall,
              onPressed: _isEitherBlocked ? null : () => _startCall('voice'),
            ),
            IconButton(
              icon: Icon(
                Icons.videocam_outlined,
                color: _isEitherBlocked ? Colors.white38 : Colors.white,
              ),
              tooltip: AppLocalizations.of(context).videoCall,
              onPressed: _isEitherBlocked ? null : () => _startCall('video'),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () async {
                // 打开菜单前实时查一次真实拉黑状态，避免 initState 异步竞态
                // 或入口数据不全导致菜单一直显示「拉黑」
                try {
                  final results = await Future.wait([
                    _blockService.isBlocked(otherMember.userId),
                    _blockService.isEitherBlocked(otherMember.userId),
                  ]);
                  if (mounted) {
                    setState(() {
                      _isOtherBlocked = results[0];
                      _isEitherBlocked = results[1];
                    });
                  }
                } catch (_) {}
                if (!context.mounted) return;
                final t = AppLocalizations.of(context);
                showPremiumActionSheet(
                  context,
                  actions: [
                    PremiumAction(
                      icon: _isOtherBlocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      label: _isOtherBlocked ? t.unblock : t.block,
                      destructive: !_isOtherBlocked,
                      onTap: () {
                        Navigator.pop(context);
                        _showBlockDialog(
                          otherMember.userId,
                          otherMember.profile?.displayName ?? t.thisUser,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
          if (isGroup) ...[
            // 仅群主/管理员可开直播
            if (_canManageGroup)
              IconButton(
                icon: const Icon(Icons.live_tv_outlined, color: Colors.white),
                tooltip: AppLocalizations.of(context).startLivestream,
                onPressed: _startLivestream,
              ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _openGroupInfo,
              tooltip: AppLocalizations.of(context).groupInfo,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 群公告横幅
          if (isGroup && _conversation.announcement?.isNotEmpty == true)
            Material(
              color: const Color(0xFFFFF9C4),
              child: InkWell(
                onTap: _openGroupInfo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign,
                        size: 16,
                        color: Color(0xFF795548),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _conversation.announcement!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 群内进行中的直播横幅（点击加入）
          if (_activeLivestream != null)
            Material(
              color: const Color(0xFF7B5EA7),
              child: InkWell(
                onTap: () => _joinLivestream(_activeLivestream!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF453A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sensors_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).groupLivestreamOngoing,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          AppLocalizations.of(context).joinLivestream,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            // 点消息区空白处收起键盘（iOS 点输入框后无法收回的修复）
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 56,
                            color: Colors.grey.withAlpha(100),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).sendFirstMessage,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      // 倒序列表（工业标准）：i=0 在底部=最新消息，
                      // 进入聊天天然锚定最新；加载更多的转圈在顶部。
                      reverse: true,
                      // 关键：reverse 列表插入新消息会让所有项索引右移，ValueKey
                      // 在 sliver 里不会跨索引保留 State，必须用此回调按 key 定位新
                      // 索引，否则正在播放的语音气泡会被重建/串台而中断播放。
                      findChildIndexCallback: (Key key) {
                        if (key is! ValueKey<String>) return null;
                        final dataIdx = _messages.indexWhere(
                          (m) => m.id == key.value,
                        );
                        if (dataIdx < 0) return null;
                        return _messages.length - 1 - dataIdx;
                      },
                      // 列表滚动/下拉时自动收起键盘（iOS 尤其需要）
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 0,
                      ),
                      itemCount: _messages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        // 顶部（最大 index）显示「加载更早消息」转圈
                        if (_loadingMore && i == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        // 列表下标 i → 数据下标（最新在 i=0）
                        final msgIdx = _messages.length - 1 - i;
                        final msg = _messages[msgIdx];
                        final isMe = msg.senderId == _currentUserId;
                        // 时间上更早的相邻消息（用于日期分隔/头像分组）
                        final prev = msgIdx > 0 ? _messages[msgIdx - 1] : null;
                        // 群聊收到的每条消息都显示头像（同一人连发三条→三个头像）
                        final showAvatar = isGroup && !isMe;
                        // 昵称只在连发的第一条显示，避免重复
                        final showSenderName =
                            isGroup &&
                            !isMe &&
                            (prev == null || prev.senderId != msg.senderId);
                        final isRead =
                            isMe &&
                            isDirect &&
                            _otherLastReadAt != null &&
                            msg.createdAt.isBefore(_otherLastReadAt!);
                        final prevDate = prev?.createdAt.toLocal();
                        final curDate = msg.createdAt.toLocal();
                        final showSep =
                            prevDate == null ||
                            prevDate.year != curDate.year ||
                            prevDate.month != curDate.month ||
                            prevDate.day != curDate.day;
                        return MessageBubble(
                          // 按消息 id 锚定，防止 reverse 列表插入新消息时
                          // Flutter 按位置复用 State，导致音频气泡时长/播放器串台
                          key: ValueKey(msg.id),
                          message: msg,
                          replySource: messagesById[msg.replyToId],
                          isMe: isMe,
                          showAvatar: showAvatar,
                          showSenderName: showSenderName,
                          isRead: isRead,
                          showDateSeparator: showSep,
                          groupMemberNames: _memberDisplayNames,
                          isGroupChat: isGroup,
                          onDelete: isMe ? () => _recallMessage(msg.id) : null,
                          onEdit: isMe
                              ? () => _showEditMessageDialog(msg)
                              : null,
                          onReply: () => _startReply(msg),
                        );
                      },
                    ),
            ),
          ),
          // @mention suggestion strip
          if (_showMentionPicker && _mentionableMembers.isNotEmpty)
            _buildMentionStrip(),
          if (_replyTo != null) _buildReplyStrip(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Reply strip（输入栏上方的引用条）──────────────────────────────────

  IconData _replyTypeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'file':
        return Icons.insert_drive_file_rounded;
      case 'audio':
        return Icons.mic_rounded;
      case 'scripture':
        return Icons.menu_book_rounded;
      case 'call':
        return Icons.call_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  Widget _buildReplyStrip() {
    final msg = _replyTo!;
    final thumb = msg.replyTargetThumb;
    final showTypeIcon = thumb == null && msg.messageType != 'text';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF9575CD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (thumb != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: thumb,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 34,
                      height: 34,
                      color: Colors.grey.shade200,
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 34,
                      height: 34,
                      color: Colors.grey.shade200,
                      child: Icon(
                        _replyTypeIcon(msg.messageType),
                        size: 17,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (msg.messageType == 'video')
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ] else if (showTypeIcon) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF9575CD).withAlpha(24),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _replyTypeIcon(msg.messageType),
                size: 18,
                color: const Color(0xFF9575CD),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.sender?.displayName ??
                      (msg.senderId == _currentUserId ? '我' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9575CD),
                  ),
                ),
                Text(
                  msg.replyTargetPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.grey.shade500,
            ),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  // ─── @mention strip ──────────────────────────────────────────────────────

  Widget _buildMentionStrip() {
    return Container(
      color: Colors.white,
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionableMembers.length,
        itemBuilder: (context, i) {
          final m = _mentionableMembers[i];
          final p = m.profile!;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: p.avatarUrl != null
                  ? CachedNetworkImageProvider(p.avatarUrl!)
                  : null,
              child: p.avatarUrl == null
                  ? Text(
                      avatarInitial(p.displayName),
                      style: const TextStyle(fontSize: 11),
                    )
                  : null,
            ),
            title: Text(p.displayName, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '@${p.username}',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _selectMention(m),
          );
        },
      ),
    );
  }

  // ─── Input bar ───────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    if (_recording) return _buildRecordingBar();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F5);

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        // 居中对齐：单行时 +/麦克风 小圆按钮与输入框胶囊垂直居中
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Attachment — gradient circle
          GestureDetector(
            onTap: _sending ? null : _showAttachmentMenu,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: _sending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF9575CD), Color(0xFFB39DDB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _sending ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 22,
                color: _sending ? Colors.grey : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).messageHint,
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  // @ mention button (groups only)
                  if (_conversation.type == 'group')
                    GestureDetector(
                      onTap: () {
                        final text = _inputCtrl.text;
                        final offset = _inputCtrl.selection.baseOffset;
                        final safeOffset = offset < 0 ? text.length : offset;
                        final newText =
                            '${text.substring(0, safeOffset)}@${text.substring(safeOffset)}';
                        _inputCtrl.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                            offset: safeOffset + 1,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 10),
                        child: Icon(
                          Icons.alternate_email,
                          size: 18,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Voice or Send button
          _inputIsEmpty && !kIsWeb
              ? GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF0F0F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          // Cancel
          GestureDetector(
            onTap: () => _stopRecording(cancel: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Pulse + timer
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _PulsingDot(),
                const SizedBox(width: 8),
                Text(
                  '$mins:$secs',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).recording,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Send
          GestureDetector(
            onTap: () => _stopRecording(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                AppLocalizations.of(context).send,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _AttachItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AttachItem> createState() => _AttachItemState();
}

class _AttachItemState extends State<_AttachItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withAlpha(widget.isDark ? 46 : 30),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: color.withAlpha(widget.isDark ? 60 : 40),
                  width: 0.8,
                ),
              ),
              child: Icon(widget.icon, color: color, size: 27),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.isDark
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context2, child) => Container(
      width: 10 * _anim.value,
      height: 10 * _anim.value,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    ),
  );
}
