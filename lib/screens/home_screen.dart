import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/active_media_session.dart';
import '../services/local_cache.dart';
import '../services/active_conversation.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_style.dart';
import 'call/call_screen.dart';
import 'call/incoming_call_screen.dart';
import 'call/livestream_screen.dart';
import 'chat/conversations_screen.dart';
import 'feed/feed_screen.dart';
import 'profile/profile_screen.dart';
import 'scripture/scripture_home_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  int _unreadMessages = 0;

  final _chatService = ChatService();
  final _callService = CallService();
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _callChannel;
  bool _handlingCall = false; // 防止重复弹出来电界面
  final _mediaController = ActiveMediaSessionController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _loadBadges();
    _subscribeToMessages();
    _subscribeToIncomingCalls();
    PushNotificationService.onActiveMediaTap = _restoreMediaSession;
    // 来电推送兜底：FCM 收到 type=call 时用 call_id 拉取并弹来电界面
    PushNotificationService.onCallPush = _onIncomingCallFromPush;
  }

  Future<void> _onIncomingCallFromPush(Map<String, dynamic> data) async {
    if (data['call_type'] == 'livestream') return;
    final callId = data['call_id'] as String?;
    if (callId == null || callId.isEmpty) return;
    try {
      final call = await _callService.getCallById(callId);
      if (call != null) _onIncomingCall(call);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回前台：后台期间 realtime 事件丢失，重拉角标并重建订阅
    if (state == AppLifecycleState.resumed) {
      _loadBadges();
      _removeCh(_msgChannel);
      _removeCh(_callChannel);
      _subscribeToMessages();
      _subscribeToIncomingCalls();
      final session = _mediaController.session;
      if (session != null && !session.minimized) {
        PushNotificationService.cancelActiveMediaNotification();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _mediaController.session?.showSystemNotification();
    }
  }

  // removeChannel 而非 unsubscribe：避免反复切后台累积同名僵尸频道。
  void _removeCh(RealtimeChannel? ch) {
    if (ch != null) Supabase.instance.client.removeChannel(ch);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeCh(_msgChannel);
    _removeCh(_callChannel);
    PushNotificationService.onActiveMediaTap = null;
    PushNotificationService.onCallPush = null;
    super.dispose();
  }

  // ─── 全局来电监听 ─────────────────────────────────────────────────────────
  void _subscribeToIncomingCalls() {
    _callChannel = _callService.subscribeToIncomingCalls(_onIncomingCall);
  }

  Future<void> _onIncomingCall(CallInfo call) async {
    if (_handlingCall || !mounted) return;
    if (call.callType == 'livestream') return;
    // 仅响应仍在振铃的来电
    if (call.status != 'ringing') return;
    _handlingCall = true;

    final navigator = Navigator.of(context, rootNavigator: true);
    // 监听该通话状态：主叫取消/超时(变为 ended/missed/declined) → 自动关闭来电界面。
    // 被叫自己接听会先置 accepted=true，避免误关已替换的通话页。
    bool accepted = false;
    bool closedByStatus = false;
    final statusCh = _callService.subscribeToCallStatus(call.id, (status) {
      if (status == 'ringing' || accepted) return;
      if (!closedByStatus && navigator.canPop()) {
        closedByStatus = true;
        navigator.pop(); // 关闭来电界面
      }
    });
    await navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          call: call,
          onAccept: () async {
            accepted = true;
            try {
              await _callService.acceptCall(call.id);
              final tokenData = await _callService.getLiveKitToken(
                room: call.livekitRoom!,
                canPublish: true,
              );
              // 取主叫昵称作为通话页显示名（之前误传了"通话中"字样）
              String callerName = '';
              try {
                final p = await Supabase.instance.client
                    .from('profiles')
                    .select('display_name')
                    .eq('id', call.callerId)
                    .maybeSingle();
                callerName = (p?['display_name'] as String?) ?? '';
              } catch (_) {}
              if (!navigator.mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    call: call,
                    livekitUrl: tokenData.url,
                    livekitToken: tokenData.token,
                    displayName: callerName,
                  ),
                ),
              );
            } catch (e) {
              if (navigator.canPop()) navigator.pop();
              if (mounted) {
                showErrorIfNotNetwork(
                  context,
                  e,
                  AppLocalizations.of(context).acceptCallFailed(e.toString()),
                );
              }
            }
          },
          onDecline: () async {
            accepted = true; // 阻止状态回调重复 pop
            try {
              await _callService.declineCall(call.id);
            } catch (_) {}
            if (navigator.canPop()) navigator.pop();
          },
        ),
      ),
    );
    statusCh.unsubscribe();
    _handlingCall = false;
  }

  Future<void> _loadBadges() async {
    try {
      final counts = await _chatService.getUnreadCounts();
      final msgCount = counts.values.where((count) => count > 0).length;
      await PushNotificationService.syncAppIconBadge(msgCount);
      if (mounted) setState(() => _unreadMessages = msgCount);
    } catch (_) {}
  }

  void _subscribeToMessages() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _msgChannel = Supabase.instance.client
        .channel('home_new_msg_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final senderId = payload.newRecord['sender_id'] as String?;
            if (senderId == null || senderId == userId) return;
            if (mounted) _loadBadges();
            _maybeShowChatBanner(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// 前台收到新消息且不在该会话页时，弹本地通知横幅
  Future<void> _maybeShowChatBanner(Map<String, dynamic> record) async {
    final conversationId = record['conversation_id'] as String?;
    if (conversationId == null) return;
    if (ActiveConversation.current == conversationId) return;
    if (record['is_deleted'] == true) return;
    try {
      final client = Supabase.instance.client;
      final sender = await client
          .from('profiles')
          .select('display_name')
          .eq('id', record['sender_id'] as String)
          .maybeSingle();
      // 群聊横幅：标题显示群名，正文带发送者名，与后台推送格式一致
      final conv = await client
          .from('conversations')
          .select('type, name')
          .eq('id', conversationId)
          .maybeSingle();
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      final type = record['message_type'] as String? ?? 'text';
      var body = switch (type) {
        'image' => t.imagePlaceholder,
        'video' => t.videoPlaceholder,
        'audio' => t.audioPlaceholder,
        'file' => t.filePlaceholder,
        'scripture' => t.scripturePlaceholder,
        _ => (record['content'] as String?) ?? '',
      };
      if (body.isEmpty) return;
      final senderName = (sender?['display_name'] as String?) ?? '';
      final isGroup = conv?['type'] == 'group';
      final title =
          isGroup ? ((conv?['name'] as String?) ?? t.group) : senderName;
      if (isGroup) body = '$senderName：$body';
      await PushNotificationService.showChatBanner(
        title: title,
        body: body,
        conversationId: conversationId,
      );
    } catch (_) {}
  }

  void _onTabSelected(int i) {
    setState(() {
      _currentIndex = i;
    });
    _loadBadges();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final screens = [
      const FeedScreen(),
      const ScriptureHomeScreen(),
      ConversationsScreen(onUnreadChanged: _loadBadges),
      ProfileScreen(userId: userId),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        unreadMessages: _unreadMessages,
      ),
    );
  }

  void _restoreMediaSession() {
    final session = _mediaController.session;
    if (session == null || session.ended) return;
    if (session.pageVisible) {
      session.restore();
      return;
    }
    session.restore();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (session.isCall) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            session: session,
            call: session.call,
            livekitUrl: session.livekitUrl,
            livekitToken: session.livekitToken,
            displayName: session.displayName,
          ),
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => LivestreamScreen(
            session: session,
            call: session.call,
            livekitUrl: session.livekitUrl,
            livekitToken: session.livekitToken,
            isHost: session.isHost,
            canManageLivestream: session.canManageLivestream,
            groupName: session.groupName,
          ),
        ),
      );
    }
  }
}

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadMessages;

  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.unreadMessages,
  });

  static const _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.menu_book_outlined, Icons.menu_book_rounded),
    (Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
    (Icons.person_outline, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context);
    final labels = [t.square, t.scripture, t.messages, t.tabProfile];
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withAlpha(225)
                : Colors.white.withAlpha(225),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(16)
                    : Colors.black.withAlpha(12),
                width: 0.6,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < _icons.length; i++)
                    Expanded(
                      child: _NavItem(
                        outlineIcon: _icons[i].$1,
                        filledIcon: _icons[i].$2,
                        label: labels[i],
                        selected: currentIndex == i,
                        badge: i == 2 ? unreadMessages : 0,
                        onTap: () => onTap(i),
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppStyle.brand.withAlpha(isDark ? 50 : 32)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _IconWithBadge(
              icon: selected ? filledIcon : outlineIcon,
              color: selected ? AppStyle.brand : inactive,
              badge: badge,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppStyle.brand : inactive,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badge;

  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: 24);
    if (badge <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -7,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            decoration: BoxDecoration(
              color: AppStyle.red,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
