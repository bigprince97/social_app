import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
import '../../utils/bible_books.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/event_bus.dart';
import '../../services/post_service.dart';
import '../../services/local_cache.dart';
import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/post_card.dart';
import '../../widgets/premium_action_sheet.dart';
import 'follow_list_screen.dart';
import 'my_posts_screen.dart';
import '../settings/blocked_users_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _postService = PostService();
  final _authService = AuthService();
  final _chatService = ChatService();
  final _blockService = BlockService();
  final _scrollController = ScrollController();
  Profile? _profile;
  List<Post> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _followLoading = false;
  bool _dmLoading = false;
  StreamSubscription<void>? _postCreatedSub;
  StreamSubscription<void>? _profileUpdatedSub;
  StreamSubscription<Post>? _postInteractedSub;
  StreamSubscription<String>? _postDeletedSub;

  late final bool _isMe;

  @override
  void initState() {
    super.initState();
    final currentId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _isMe = widget.userId == currentId;
    _loadData();
    _postCreatedSub = onPostCreated.listen((_) {
      if (mounted) _loadData();
    });
    if (_isMe)
      _profileUpdatedSub = onProfileUpdated.listen((_) {
        if (mounted) _loadData();
      });
    _postInteractedSub = onPostInteracted.listen((updatedPost) {
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == updatedPost.id);
          if (index != -1) {
            _posts[index] = updatedPost;
          }
        });
      }
    });
    _postDeletedSub = onPostDeleted.listen((postId) {
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.id == postId);
        });
      }
    });
  }

  @override
  void dispose() {
    _postCreatedSub?.cancel();
    _profileUpdatedSub?.cancel();
    _postInteractedSub?.cancel();
    _postDeletedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 资料单独加载：getProfile 自带离线缓存回退，
      // 不让帖子/关注等其它请求的失败连累资料展示（离线时避免“用户不存在”）。
      try {
        final profile = await _profileService.getProfile(widget.userId);
        if (mounted) setState(() => _profile = profile);
      } catch (_) {/* 无缓存且离线时保持 null，由下方网络态兜底 */}

      // 帖子无缓存：离线失败不影响资料展示
      try {
        final posts = await _postService.getUserPosts(widget.userId);
        if (mounted) setState(() => _posts = posts);
      } catch (_) {}

      if (!_isMe) {
        try {
          final isFollowing = await _profileService.isFollowing(widget.userId);
          final isBlocked = await _blockService.isBlocked(widget.userId);
          if (mounted) {
            setState(() {
              _isFollowing = isFollowing;
              _isBlocked = isBlocked;
            });
          }
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_isBlocked) {
      await _blockService.unblockUser(widget.userId);
      setState(() => _isBlocked = false);
    } else {
      final confirm = await showPremiumConfirm(
        context,
        icon: Icons.block_rounded,
        title: AppLocalizations.of(context).blockUserTitle,
        message: AppLocalizations.of(
          context,
        ).blockUserConfirm3(_profile?.displayName ?? '该用户'),
        confirmLabel: AppLocalizations.of(context).block,
        destructive: true,
      );
      if (confirm) {
        await _blockService.blockUser(widget.userId);
        setState(() => _isBlocked = true);
        if (mounted) {
          showPremiumToast(context, AppLocalizations.of(context).userBlocked, kind: ToastKind.info);
        }
      }
    }
  }

  Future<void> _startDirectMessage() async {
    setState(() => _dmLoading = true);
    try {
      final conv = await _chatService.createDirectConversation(widget.userId);
      if (mounted) context.push('/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).directMessageFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _dmLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await _profileService.unfollowUser(widget.userId);
        setState(() {
          _isFollowing = false;
          _profile = _profile?.copyWith(
            followersCount: (_profile!.followersCount - 1).clamp(0, 999999),
          );
        });
      } else {
        await _profileService.followUser(widget.userId);
        setState(() {
          _isFollowing = true;
          _profile = _profile?.copyWith(
            followersCount: _profile!.followersCount + 1,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).operationFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  void _showSettings() {
    showPremiumActionSheet(
      context,
      title: AppLocalizations.of(context).settings,
      actions: [
        PremiumAction(
          icon: Icons.language_rounded,
          label: AppLocalizations.of(context).languageSettings,
          color: const Color(0xFF5AC8FA),
          onTap: () {
            Navigator.pop(context);
            context.push('/settings/language');
          },
        ),
        PremiumAction(
          icon: Icons.block_rounded,
          label: AppLocalizations.of(context).blockedUsers,
          color: const Color(0xFFFF9F0A),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen()),
            );
          },
        ),
        PremiumAction(
          icon: Icons.logout_rounded,
          label: AppLocalizations.of(context).logout,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _confirmLogout();
          },
        ),
        PremiumAction(
          icon: Icons.person_remove_rounded,
          label: AppLocalizations.of(context).deleteAccount,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _confirmDeleteAccount();
          },
        ),
      ],
    );
  }

  void _showMoreMenu() {
    showPremiumActionSheet(
      context,
      actions: [
        PremiumAction(
          icon: _isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
          label: _isBlocked
              ? AppLocalizations.of(context).unblock
              : AppLocalizations.of(context).block,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _toggleBlock();
          },
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showPremiumConfirm(
      context,
      icon: Icons.logout_rounded,
      title: AppLocalizations.of(context).logout,
      message: AppLocalizations.of(context).confirmLogout,
      confirmLabel: AppLocalizations.of(context).confirmButton,
      destructive: true,
    );
    if (confirm) await _authService.signOut();
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showPremiumConfirm(
      context,
      icon: Icons.person_remove_rounded,
      title: AppLocalizations.of(context).deleteAccount,
      message: AppLocalizations.of(context).deleteAccountConfirm,
      confirmLabel: AppLocalizations.of(context).deleteAccount,
      destructive: true,
    );
    if (confirm) {
      try {
        await _authService.deleteAccount();
        if (mounted) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).deleteAccountSuccess,
            kind: ToastKind.success,
          );
        }
      } catch (e) {
        if (mounted) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).deleteAccountFailed(e.toString()),
            kind: ToastKind.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).userNotFound),
              if (_isMe) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    AppLocalizations.of(context).logout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile!.username),
        actions: [
          if (_isMe)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _showSettings,
            )
          else
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: _showMoreMenu,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isMe)
              SliverToBoxAdapter(child: _buildMyActions())
            else ...[
              // 他人主页：直接展示其帖子
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => PostCard(post: _posts[i]),
                  childCount: _posts.length,
                ),
              ),
              if (_posts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(AppLocalizations.of(context).noPosts),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyActions() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 我的发帖（左） / 我的书签（右）入口
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _ProfileEntry(
                  icon: Icons.article_outlined,
                  color: const Color(0xFF9575CD),
                  label: l10n.myPosts,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyPostsScreen(userId: widget.userId),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProfileEntry(
                  icon: Icons.bookmark_outline_rounded,
                  color: const Color(0xFFFF9F0A),
                  label: l10n.myBookmarks,
                  onTap: () => context.push('/scripture/bookmarks'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }


  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF9575CD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Avatar row ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gradient ring avatar (Instagram style)
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isFollowing || _isMe
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF9575CD),
                            Color(0xFFE040FB),
                            Color(0xFFFF6D00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFCCCCCC), Color(0xFFCCCCCC)],
                        ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF111111) : Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: primary,
                    backgroundImage: _profile!.avatarUrl != null
                        ? CachedNetworkImageProvider(_profile!.avatarUrl!)
                        : null,
                    child: _profile!.avatarUrl == null
                        ? Text(
                            avatarInitial(_profile!.displayName),
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Stats row
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(10)
                        : const Color(0xFF9575CD).withAlpha(14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat(
                        AppLocalizations.of(context).posts,
                        _profile!.postsCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyPostsScreen(userId: widget.userId),
                          ),
                        ),
                      ),
                      _buildStat(
                        AppLocalizations.of(context).followers,
                        _profile!.followersCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListScreen(
                              userId: widget.userId,
                              displayName: _profile!.displayName,
                              type: FollowListType.followers,
                            ),
                          ),
                        ),
                      ),
                      _buildStat(
                        AppLocalizations.of(context).following,
                        _profile!.followingCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListScreen(
                              userId: widget.userId,
                              displayName: _profile!.displayName,
                              type: FollowListType.following,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Name + bio ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile!.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '@${_profile!.username}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
              if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _profile!.bio!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
              if (_profile!.region != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      localizedRegion(
                        AppLocalizations.of(context),
                        _profile!.region!,
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Action buttons ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: !_isMe
              ? Row(
                  children: [
                    Expanded(
                      child: _isFollowing
                          ? _PillButton(
                              label: AppLocalizations.of(
                                context,
                              ).alreadyFollowing,
                              icon: Icons.check_rounded,
                              filled: false,
                              onTap: _followLoading ? null : _toggleFollow,
                            )
                          : PremiumButton(
                              label: AppLocalizations.of(context).following,
                              icon: Icons.add_rounded,
                              expand: true,
                              onTap: _followLoading ? null : _toggleFollow,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PillButton(
                        label: AppLocalizations.of(context).directMessage,
                        icon: Icons.chat_bubble_outline_rounded,
                        filled: false,
                        loading: _dmLoading,
                        onTap: _dmLoading ? null : _startDirectMessage,
                      ),
                    ),
                  ],
                )
              : _PillButton(
                  label: AppLocalizations.of(context).editProfile,
                  icon: Icons.edit_outlined,
                  filled: false,
                  onTap: () async {
                    await context.push('/edit-profile');
                    if (mounted) _loadData();
                  },
                ),
        ),

        const Divider(height: 8, thickness: 0.5),
      ],
    );
  }


  Widget _buildStat(String label, int count, {VoidCallback? onTap}) {
    final col = Column(
      children: [
        Text(
          (count < 0 ? 0 : count).toString(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
          ),
        ),
      ],
    );
    if (onTap == null) return col;
    return GestureDetector(onTap: onTap, child: col);
  }
}

/// 「我的」页入口卡片（编辑资料 / 我的书签）。
class _ProfileEntry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ProfileEntry({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFFB0B0B5)),
          ],
        ),
      ),
    );
  }
}

/// 描边胶囊按钮（次要操作：已关注/私信/编辑资料）。
class _PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;

  const _PillButton({
    required this.label,
    this.icon,
    this.onTap,
    this.filled = true,
    this.loading = false,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 44,
          width: null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(16)
                : const Color(0xFF9575CD).withAlpha(16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppStyle.brand.withAlpha(isDark ? 90 : 70),
              width: 1,
            ),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppStyle.brand,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: AppStyle.brand),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppStyle.brand,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
