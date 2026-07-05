import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../services/chat_service.dart';
import '../../services/event_bus.dart';
import '../../services/friend_service.dart';
import '../../services/local_cache.dart';
import '../../services/notification_service.dart';
import '../../theme/app_style.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import '../../widgets/premium_toast.dart';

/// 「好友」Tab：好友列表 + 好友申请，右上角搜索添加与通知入口。
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _friendService = FriendService();
  final _notificationService = NotificationService();
  final _chatService = ChatService();
  late final TabController _tabCtrl;

  List<Friendship> _friends = [];
  List<Friendship> _incoming = [];
  List<Friendship> _outgoing = [];
  int _unreadNotifications = 0;
  bool _loading = true;
  RealtimeChannel? _friendshipChannel;
  RealtimeChannel? _notificationChannel;
  StreamSubscription<String>? _blockedSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
    _friendshipChannel = _friendService.subscribeToChanges(() {
      if (mounted) _load(silent: true);
    });
    try {
      _notificationChannel = _notificationService.subscribeToNotifications((_) {
        if (mounted) _loadUnread();
      });
    } catch (_) {}
    _blockedSub = onUserBlocked.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    final client = Supabase.instance.client;
    if (_friendshipChannel != null) client.removeChannel(_friendshipChannel!);
    if (_notificationChannel != null) {
      client.removeChannel(_notificationChannel!);
    }
    _blockedSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _friendService.getFriends(),
        _friendService.getIncomingRequests(),
        _friendService.getOutgoingRequests(),
      ]);
      if (mounted) {
        setState(() {
          _friends = results[0];
          _incoming = results[1];
          _outgoing = results[2];
        });
      }
      await _loadUnread();
    } catch (_) {
      // 离线静默
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {}
  }

  Future<void> _accept(Friendship f) async {
    try {
      await _friendService.acceptRequest(f.id);
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).friendRequestAccepted,
          kind: ToastKind.success,
        );
      }
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).operationFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _removeFriendship(Friendship f) async {
    try {
      await _friendService.removeFriendship(f.id);
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).operationFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _confirmRemoveFriend(Friendship f) async {
    final t = AppLocalizations.of(context);
    final confirm = await showPremiumConfirm(
      context,
      icon: Icons.person_remove_rounded,
      title: t.removeFriend,
      message: t.removeFriendConfirm(f.other?.displayName ?? ''),
      confirmLabel: t.removeFriend,
      destructive: true,
    );
    if (confirm) await _removeFriendship(f);
  }

  Future<void> _openChat(Profile other) async {
    try {
      final conv = await _chatService.createDirectConversation(other.id);
      if (mounted) context.push('/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (mounted) {
        if (e is BlockedChatException) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).blockedInteraction,
            kind: ToastKind.block,
          );
          return;
        }
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).directMessageFailed(e.toString()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final requestCount = _incoming.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.friends),
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/notifications');
              _loadUnread();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppStyle.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () async {
              await context.push('/search');
              _load(silent: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppStyle.brand,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: AppStyle.brand,
          tabs: [
            Tab(text: t.friends),
            Tab(
              text: requestCount > 0
                  ? '${t.friendRequests} ($requestCount)'
                  : t.friendRequests,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [_buildFriendsTab(t), _buildRequestsTab(t)],
            ),
    );
  }

  Widget _buildFriendsTab(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _friends.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: PremiumEmptyState(
                    icon: Icons.group_outlined,
                    title: t.noFriends,
                    subtitle: t.noFriendsSubtitle,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _friends.length,
              separatorBuilder: (_, i) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final f = _friends[i];
                final p = f.other!;
                return ListTile(
                  leading: _Avatar(profile: p),
                  title: Text(
                    p.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('@${p.username}'),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppStyle.brand,
                    ),
                    onPressed: () => _openChat(p),
                  ),
                  onTap: () async {
                    await context.push('/profile/${p.id}');
                    _load(silent: true);
                  },
                  onLongPress: () => _confirmRemoveFriend(f),
                );
              },
            ),
    );
  }

  Widget _buildRequestsTab(AppLocalizations t) {
    final hasAny = _incoming.isNotEmpty || _outgoing.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: !hasAny
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: PremiumEmptyState(
                    icon: Icons.mark_email_unread_outlined,
                    title: t.noFriendRequests,
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final f in _incoming)
                  ListTile(
                    leading: _Avatar(profile: f.other!),
                    title: Text(
                      f.other!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('@${f.other!.username}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _accept(f),
                          style: TextButton.styleFrom(
                            backgroundColor: AppStyle.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(t.accept),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => _removeFriendship(f),
                          child: Text(
                            t.decline,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/profile/${f.other!.id}'),
                  ),
                if (_outgoing.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: Text(
                      t.outgoingRequests,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  for (final f in _outgoing)
                    ListTile(
                      leading: _Avatar(profile: f.other!),
                      title: Text(f.other!.displayName),
                      subtitle: Text('@${f.other!.username}'),
                      trailing: TextButton(
                        onPressed: () => _removeFriendship(f),
                        child: Text(
                          t.cancelRequest,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      onTap: () => context.push('/profile/${f.other!.id}'),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Profile profile;

  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundImage: profile.avatarUrl != null
          ? CachedNetworkImageProvider(profile.avatarUrl!)
          : null,
      child: profile.avatarUrl == null
          ? Text(avatarInitial(profile.displayName))
          : null,
    );
  }
}
