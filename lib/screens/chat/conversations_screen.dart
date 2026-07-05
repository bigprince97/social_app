import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/locale_controller.dart';
import '../../models/conversation.dart';
import '../../models/profile.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_style.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../widgets/premium_toast.dart';

class ConversationsScreen extends StatefulWidget {
  final VoidCallback? onUnreadChanged;

  const ConversationsScreen({super.key, this.onUnreadChanged});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  final _chatService = ChatService();
  final _searchCtrl = TextEditingController();
  List<Conversation> _conversations = [];
  String _query = '';
  bool _loading = true;
  RealtimeChannel? _msgChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _setupRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台期间 realtime 长连接被系统挂起、事件丢失；
    // 回前台立即重拉数据并重建订阅，保证列表是最新的。
    if (state == AppLifecycleState.resumed) {
      _loadConversations(silent: true);
      _setupRealtime();
    }
  }

  void _setupRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _msgChannel?.unsubscribe();
    _msgChannel = Supabase.instance.client
        .channel('conv_list_$userId')
        // 新消息
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) {
              _loadConversations(silent: true);
              widget.onUnreadChanged?.call();
            }
          },
        )
        // 会话本身的变更：触发器写入的最新预览/时间、撤回刷新、群名修改等
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (mounted) _loadConversations(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(Conversation conv) async {
    final t = AppLocalizations.of(context);
    return showPremiumConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: t.deleteConversation,
      message: t.deleteConversationConfirm,
      confirmLabel: t.delete,
      destructive: true,
    );
  }

  Future<void> _deleteConversation(Conversation conv) async {
    setState(() => _conversations.removeWhere((c) => c.id == conv.id));
    try {
      await _chatService.deleteConversation(conv.id);
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).conversationDeleted,
          kind: ToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).operationFailed('$e'),
        );
        _loadConversations(silent: true);
      }
    }
  }

  Future<void> _loadConversations({bool silent = false}) async {
    // 缓存优先：先秒显本地缓存的会话列表，再后台拉新
    if (!silent && _conversations.isEmpty) {
      try {
        final cached = await _chatService.getCachedConversations();
        if (mounted && cached.isNotEmpty) {
          setState(() {
            _conversations = cached;
            _loading = false;
          });
        }
      } catch (_) {}
    }
    if (!silent && _conversations.isEmpty) setState(() => _loading = true);
    try {
      final convs = await _chatService.getConversations().timeout(
        const Duration(seconds: 12),
      );
      if (mounted) setState(() => _conversations = convs);
    } catch (e) {
      if (mounted && !silent) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).loadFailed(e),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<Conversation> get _filtered {
    if (_query.isEmpty) return _conversations;
    final q = _query.toLowerCase();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return _conversations.where((c) {
      final name = c.displayName(userId).toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).messages),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => _showNewChatDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchConversations,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF9575CD),
                    width: 1.5,
                  ),
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                child: PremiumEmptyState(
                                  icon: _query.isEmpty
                                      ? Icons.forum_outlined
                                      : Icons.search_off_rounded,
                                  title: _query.isEmpty
                                      ? AppLocalizations.of(context).noMessages
                                      : AppLocalizations.of(
                                          context,
                                        ).noSearchResults,
                                  subtitle: _query.isEmpty
                                      ? AppLocalizations.of(
                                          context,
                                        ).createNewChat
                                      : null,
                                  color: AppStyle.brand,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final conv = filtered[i];
                              return Dismissible(
                                key: ValueKey(conv.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  color: AppStyle.red,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (_) => _confirmDelete(conv),
                                onDismissed: (_) => _deleteConversation(conv),
                                child: _ConversationTile(
                                  conversation: conv,
                                  currentUserId: userId,
                                  onTap: () => context
                                      .push('/chat/${conv.id}', extra: conv)
                                      .then((_) {
                                        _loadConversations(silent: true);
                                        widget.onUnreadChanged?.call();
                                      }),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewChatSheet(
        onCreated: (conv) {
          context
              .push('/chat/${conv.id}', extra: conv)
              .then((_) => _loadConversations(silent: true));
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation.displayName(currentUserId);
    final avatar = conversation.displayAvatar(currentUserId);
    final hasUnread = conversation.unreadCount > 0;
    final isGroup = conversation.type == 'group';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Avatar with optional group badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF9575CD),
                  backgroundImage: avatar != null
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                if (isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF9575CD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (conversation.lastMessageAt != null)
                        Text(
                          timeago.format(
                            conversation.lastMessageAt!,
                            locale: LocaleController.instance.timeagoLocale,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? const Color(0xFF9575CD)
                                : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ??
                              AppLocalizations.of(context).noMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? Colors.black87
                                : Colors.grey.shade500,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9575CD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final void Function(Conversation) onCreated;

  const _NewChatSheet({required this.onCreated});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  final _profileService = ProfileService();
  final _chatService = ChatService();
  final _friendService = FriendService();
  List<Profile> _searchResults = [];
  List<Profile> _friends = [];
  bool _friendsLoading = true;
  final Set<String> _selectedIds = {};
  bool _creatingDirect = false;
  bool _creatingGroup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  /// 私聊仅限好友：载入好友列表供选择（搜索框做本地过滤）。
  Future<void> _loadFriends() async {
    try {
      final friends = await _friendService.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends.map((f) => f.other).whereType<Profile>().toList();
        });
      }
    } catch (_) {
      // 离线静默
    } finally {
      if (mounted) setState(() => _friendsLoading = false);
    }
  }

  List<Profile> get _filteredFriends {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends
        .where(
          (p) =>
              p.displayName.toLowerCase().contains(q) ||
              p.username.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _profileService.searchUsers(q);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {}
  }

  Future<void> _startDirectChat(Profile profile) async {
    if (_creatingDirect) return;
    setState(() => _creatingDirect = true);
    try {
      final conv = await _chatService.createDirectConversation(profile.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(conv);
      }
    } catch (e) {
      if (mounted) {
        if (e is NotFriendsChatException) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).notFriendsCannotDm,
            kind: ToastKind.block,
          );
          return;
        }
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).createFailed2(e),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingDirect = false);
    }
  }

  Future<void> _createGroup() async {
    if (_creatingGroup) return;
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty || _selectedIds.isEmpty) return;
    setState(() => _creatingGroup = true);
    try {
      final conv = await _chatService.createGroupConversation(
        name: name,
        memberIds: _selectedIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(conv);
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(
          context,
          e,
          AppLocalizations.of(context).createFailed2(e),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: AppLocalizations.of(context).privateChat),
              Tab(text: AppLocalizations.of(context).group),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 私聊 tab：仅好友可私信，列好友、搜索框本地过滤
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).searchUsers,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: _friendsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _friends.isEmpty
                          ? PremiumEmptyState(
                              icon: Icons.group_outlined,
                              title: AppLocalizations.of(context).noFriends,
                              subtitle: AppLocalizations.of(
                                context,
                              ).noFriendsSubtitle,
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _filteredFriends.length,
                              itemBuilder: (context, i) {
                                final p = _filteredFriends[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: p.avatarUrl != null
                                        ? CachedNetworkImageProvider(
                                            p.avatarUrl!,
                                          )
                                        : null,
                                    child: p.avatarUrl == null
                                        ? Text(avatarInitial(p.displayName))
                                        : null,
                                  ),
                                  title: Text(p.displayName),
                                  subtitle: Text('@${p.username}'),
                                  onTap: _creatingDirect
                                      ? null
                                      : () => _startDirectChat(p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                // 群聊 tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _groupNameCtrl,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              ).groupChatName,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              ).searchMembers,
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: _search,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final p = _searchResults[i];
                          final selected = _selectedIds.contains(p.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(p.id);
                                } else {
                                  _selectedIds.remove(p.id);
                                }
                              });
                            },
                            title: Text(p.displayName),
                            subtitle: Text('@${p.username}'),
                            secondary: CircleAvatar(
                              backgroundImage: p.avatarUrl != null
                                  ? CachedNetworkImageProvider(p.avatarUrl!)
                                  : null,
                              child: p.avatarUrl == null
                                  ? Text(avatarInitial(p.displayName))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: _selectedIds.isEmpty || _creatingGroup
                            ? null
                            : _createGroup,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: _creatingGroup
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(
                                  context,
                                ).createGroupButton(_selectedIds.length),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
