import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/bible_books.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/event_bus.dart';
import '../../services/post_service.dart';
import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/post_card.dart';
import '../../widgets/premium_action_sheet.dart';
import 'follow_list_screen.dart';

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
  Profile? _profile;
  List<Post> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _followLoading = false;
  bool _dmLoading = false;
  StreamSubscription<void>? _postCreatedSub;
  StreamSubscription<void>? _profileUpdatedSub;
  StreamSubscription<void>? _postInteractedSub;

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
    _postInteractedSub = onPostInteracted.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _postCreatedSub?.cancel();
    _profileUpdatedSub?.cancel();
    _postInteractedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _profileService.getProfile(widget.userId),
        _postService.getUserPosts(widget.userId),
        if (!_isMe) _profileService.isFollowing(widget.userId),
        if (!_isMe) _blockService.isBlocked(widget.userId),
      ]);
      setState(() {
        _profile = results[0] as Profile;
        _posts = results[1] as List<Post>;
        if (!_isMe) {
          _isFollowing = results[2] as bool;
          _isBlocked = results[3] as bool;
        }
      });
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).userBlocked)),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).directMessageFailed(e.toString()),
            ),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).operationFailed(e.toString()),
            ),
          ),
        );
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
          icon: Icons.edit_outlined,
          label: AppLocalizations.of(context).editProfile,
          color: const Color(0xFF0A84FF),
          onTap: () async {
            Navigator.pop(context);
            await context.push('/edit-profile');
            if (mounted) _loadData();
          },
        ),
        PremiumAction(
          icon: Icons.bookmark_outline_rounded,
          label: AppLocalizations.of(context).myBookmarks,
          color: const Color(0xFFFF9F0A),
          onTap: () {
            Navigator.pop(context);
            context.push('/scripture/bookmarks');
          },
        ),
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
          icon: Icons.logout_rounded,
          label: AppLocalizations.of(context).logout,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _confirmLogout();
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
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
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
        ),
      ),
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
                            _profile!.displayName[0].toUpperCase(),
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
                        onTap: null,
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
                  expand: true,
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

  static const _regionLabels = {
    'CN-BJ': '北京', 'CN-SH': '上海', 'CN-GD': '广东',
    'CN-ZJ': '浙江', 'CN-JS': '江苏', 'CN-SC': '四川',
    'HK': '香港', 'TW': '台湾', 'SG': '新加坡',
    'MY': '马来西亚', 'US': '美国', 'CA': '加拿大',
    'AU': '澳大利亚', 'GB': '英国', 'JP': '日本',
    'KR': '韩国', 'OTHER': '其他',
  };

  String _regionLabel(String code) => _regionLabels[code] ?? code;

  Widget _buildStat(String label, int count, {VoidCallback? onTap}) {
    final col = Column(
      children: [
        Text(
          count.toString(),
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

/// 描边胶囊按钮（次要操作：已关注/私信/编辑资料）。
class _PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool expand;
  final bool loading;

  const _PillButton({
    required this.label,
    this.icon,
    this.onTap,
    this.filled = true,
    this.expand = false,
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
          width: widget.expand ? double.infinity : null,
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
