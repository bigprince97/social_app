import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/locale_controller.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/profile.dart';
import '../../services/chat_service.dart';
import '../../services/message_sync_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_style.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../widgets/premium_toast.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _chatService = ChatService();
  final _messageSync = MessageSyncService.instance;
  final _searchCtrl = TextEditingController();
  List<Conversation> _conversations = [];
  String _query = '';
  bool _loading = true;
  StreamSubscription<ChatSyncEvent>? _chatEventsSub;
  Timer? _unknownConversationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _chatEventsSub = _messageSync.events.listen(_onChatSyncEvent);
    _loadConversations();
  }

  @override
  void dispose() {
    _chatEventsSub?.cancel();
    _unknownConversationRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChatSyncEvent(ChatSyncEvent event) {
    if (!mounted) return;
    if (event is ConversationMembershipChangedEvent) {
      _scheduleUnknownConversationRefresh();
      return;
    }
    if (event is UnreadCountsChangedEvent) {
      var changed = false;
      for (final conversation in _conversations) {
        final unread = _messageSync.unreadFor(conversation.id);
        if (conversation.unreadCount != unread) {
          conversation.unreadCount = unread;
          changed = true;
        }
      }
      if (changed) setState(() {});
      return;
    }
    if (event is! SyncedMessageEvent) return;

    final message = event.message;
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == message.conversationId,
    );
    if (index < 0) {
      // 新加入或之前隐藏的会话只补拉一次；普通已知会话永远局部更新。
      _scheduleUnknownConversationRefresh();
      return;
    }

    final current = _conversations[index];
    final isLatest =
        current.lastMessageAt == null ||
        !message.createdAt.isBefore(current.lastMessageAt!);
    final unread = _messageSync.unreadFor(current.id);
    final updated = current.copyWith(
      lastMessageAt: isLatest ? message.createdAt : current.lastMessageAt,
      lastMessagePreview: isLatest
          ? _conversationPreview(message)
          : current.lastMessagePreview,
      unreadCount: unread,
    );

    setState(() {
      _conversations[index] = updated;
      if (!event.isUpdate && isLatest && index > 0) {
        _conversations
          ..removeAt(index)
          ..insert(0, updated);
      }
    });
  }

  void _scheduleUnknownConversationRefresh() {
    _unknownConversationRefreshTimer ??= Timer(
      const Duration(milliseconds: 300),
      () {
        _unknownConversationRefreshTimer = null;
        unawaited(_loadConversations(silent: true));
      },
    );
  }

  String _conversationPreview(Message message) {
    if (message.isDeleted) return '[消息已撤回]';
    return switch (message.messageType) {
      'text' => message.content ?? '',
      'image' => '[图片]',
      'video' => '[视频]',
      'audio' => '[语音]',
      'file' => '[文件]',
      'scripture' => '[经文引用]',
      _ => '[消息]',
    };
  }

  List<Conversation> _mergeLoadedConversations(List<Conversation> loaded) {
    if (_conversations.isEmpty) return loaded;
    final localById = {for (final item in _conversations) item.id: item};
    final merged = loaded.map((remote) {
      final local = localById[remote.id];
      if (local == null || local.lastMessageAt == null) return remote;
      final remoteTime = remote.lastMessageAt;
      if (remoteTime != null && !local.lastMessageAt!.isAfter(remoteTime)) {
        return remote;
      }
      // 网络刷新与同步事件并发时，保留刷新开始后刚收到的本地最新消息。
      return remote.copyWith(
        lastMessageAt: local.lastMessageAt,
        lastMessagePreview: local.lastMessagePreview,
        unreadCount: local.unreadCount,
      );
    }).toList();
    merged.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null && bTime == null) return a.id.compareTo(b.id);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final byTime = bTime.compareTo(aTime);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return merged;
  }

  void _applySyncedUnread(List<Conversation> conversations) {
    if (!_messageSync.hasUnreadSnapshot) return;
    for (final conversation in conversations) {
      conversation.unreadCount = _messageSync.unreadFor(conversation.id);
    }
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
          _applySyncedUnread(cached);
          _messageSync.registerConversations(cached);
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
      if (mounted) {
        final merged = _mergeLoadedConversations(convs);
        _applySyncedUnread(merged);
        _messageSync.registerConversations(merged);
        setState(() => _conversations = merged);
      }
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
    return GestureDetector(
      // 点击列表空白处收回搜索键盘(translucent 不拦截子组件点击)
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
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
                textInputAction: TextInputAction.search,
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
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: PremiumEmptyState(
                                    icon: _query.isEmpty
                                        ? Icons.forum_outlined
                                        : Icons.search_off_rounded,
                                    title: _query.isEmpty
                                        ? AppLocalizations.of(
                                            context,
                                          ).noMessages
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
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
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
                                    onTap: () async {
                                      // 进入会话即本地清零，避免返回列表时旧红点闪一下；
                                      // 聊天页同时会把 last_read_at 写入数据库。
                                      if (conv.unreadCount > 0 && mounted) {
                                        setState(() => conv.unreadCount = 0);
                                      }
                                      _messageSync.markConversationRead(
                                        conv.id,
                                      );
                                      await context.push(
                                        '/chat/${conv.id}',
                                        extra: conv,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewChatSheet(
        onCreated: (conv) {
          final index = _conversations.indexWhere((c) => c.id == conv.id);
          setState(() {
            if (index < 0) {
              _conversations.insert(0, conv);
            } else {
              _conversations[index] = conv;
            }
          });
          _messageSync.registerConversations([conv]);
          context.push('/chat/${conv.id}', extra: conv);
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
                            color: AppStyle.red,
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
  List<Profile> _searchResults = [];
  final Set<String> _selectedIds = {};
  bool _searching = false;
  bool _creatingDirect = false;
  bool _creatingGroup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    setState(() => _searching = true);
    try {
      final results = await _profileService.searchUsers(q);
      setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
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
                // 私聊 tab
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
                        textInputAction: TextInputAction.search,
                        onChanged: _search,
                      ),
                    ),
                    Expanded(
                      child: _searching
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, i) {
                                final p = _searchResults[i];
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
                            textInputAction: TextInputAction.search,
                            onChanged: _search,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
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
