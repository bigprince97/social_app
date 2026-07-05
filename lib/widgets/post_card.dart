import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../services/block_service.dart';
import '../services/event_bus.dart';
import '../services/post_service.dart';
import '../services/report_service.dart';
import '../theme/app_style.dart';
import 'image_viewer.dart';
import 'premium_action_sheet.dart';
import 'premium_toast.dart';
import 'video_player_widget.dart';

// ─── Instagram / premium style PostCard ──────────────────────────────────────

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onDeleted;
  final void Function(String topic)? onTopicTap;

  /// 是否整卡点击进入详情。详情页里的卡片应设为 false，避免重复跳转。
  final bool tappable;

  const PostCard({
    super.key,
    required this.post,
    this.onDeleted,
    this.onTopicTap,
    this.tappable = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likesCount;
  late bool _isBookmarked;
  final _postService = PostService();
  final _blockService = BlockService();
  // 用 getter 实时计算，避免列表复用 State 后归属判断错乱
  bool get _isOwn {
    final myId = _postService.currentUserId;
    return myId != null && myId == widget.post.userId;
  }

  // Heart animation
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isBookmarked = widget.post.isBookmarked;

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 列表刷新/跨页同步后 post 数据变了，同步本地点赞状态，避免显示旧值
    if (widget.post.id != oldWidget.post.id ||
        widget.post.isLiked != _isLiked ||
        widget.post.likesCount != _likesCount ||
        widget.post.isBookmarked != _isBookmarked) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
      _isBookmarked = widget.post.isBookmarked;
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    if (_isLiked) _heartCtrl.forward(from: 0);
    try {
      if (_isLiked) {
        await _postService.likePost(widget.post.id);
      } else {
        await _postService.unlikePost(widget.post.id);
      }
      notifyPostInteracted(
        widget.post.copyWith(isLiked: _isLiked, likesCount: _likesCount),
      );
    } catch (e) {
      if (mounted) {
        if (e is BlockedInteractionException) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).blockedInteraction,
            kind: ToastKind.block,
          );
          return;
        }
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (_isBookmarked) {
        await _postService.bookmarkPost(widget.post.id);
      } else {
        await _postService.unbookmarkPost(widget.post.id);
      }
      notifyPostInteracted(widget.post.copyWith(isBookmarked: _isBookmarked));
    } catch (e) {
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        if (e is BlockedInteractionException) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).blockedInteraction,
            kind: ToastKind.block,
          );
        }
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showPremiumConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: AppLocalizations.of(context).deletePost,
      message: AppLocalizations.of(context).deletePostConfirm,
      confirmLabel: AppLocalizations.of(context).delete,
      destructive: true,
    );
    if (!ok) return;
    await _postService.deletePost(widget.post.id);
    notifyPostDeleted(widget.post.id);
    if (mounted) {
      widget.onDeleted?.call();
    }
  }

  void _showReportMenu() {
    final t = AppLocalizations.of(context);
    showPremiumActionSheet(
      context,
      title: t.reportReason,
      actions: [
        PremiumAction(
          icon: Icons.announcement_outlined,
          label: t.reportReasonSpam,
          onTap: () {
            Navigator.pop(context);
            _reportPost(t.reportReasonSpam);
          },
        ),
        PremiumAction(
          icon: Icons.sentiment_very_dissatisfied_outlined,
          label: t.reportReasonHarassment,
          onTap: () {
            Navigator.pop(context);
            _reportPost(t.reportReasonHarassment);
          },
        ),
        PremiumAction(
          icon: Icons.gavel_outlined,
          label: t.reportReasonObjectionable,
          onTap: () {
            Navigator.pop(context);
            _reportPost(t.reportReasonObjectionable);
          },
        ),
        PremiumAction(
          icon: Icons.report_problem_outlined,
          label: t.reportReasonViolence,
          onTap: () {
            Navigator.pop(context);
            _reportPost(t.reportReasonViolence);
          },
        ),
        PremiumAction(
          icon: Icons.help_outline_rounded,
          label: t.reportReasonOther,
          onTap: () {
            Navigator.pop(context);
            _reportPost(t.reportReasonOther);
          },
        ),
      ],
    );
  }

  Future<void> _reportPost(String reason) async {
    try {
      await ReportService().reportContent(
        targetType: 'post',
        targetId: widget.post.id,
        reason: reason,
      );
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).reportSuccess,
          kind: ToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).reportFailed(''),
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _blockAuthor() async {
    final authorName =
        widget.post.author?.displayName ??
        AppLocalizations.of(context).thisUser;
    final ok = await showPremiumConfirm(
      context,
      icon: Icons.block_rounded,
      title: AppLocalizations.of(context).blockUserTitle,
      message: AppLocalizations.of(context).blockUserConfirm3(authorName),
      confirmLabel: AppLocalizations.of(context).block,
      destructive: true,
    );
    if (!ok) return;
    try {
      await _blockService.blockUser(widget.post.userId);
      notifyUserBlocked(widget.post.userId);
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).userBlocked,
          kind: ToastKind.block,
        );
      }
    } catch (_) {
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).operationFailed(''),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.tappable
          ? () => context.push('/post/${widget.post.id}')
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppStyle.rLg),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.black.withAlpha(8),
            width: 0.6,
          ),
          boxShadow: AppStyle.softShadow(isDark),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  // Avatar with gradient ring
                  GestureDetector(
                    onTap: () => context.push('/profile/${widget.post.userId}'),
                    child: _GradientAvatar(
                      url: author?.avatarUrl,
                      initial: avatarInitial(author?.displayName),
                      radius: 19,
                      hasRing: !_isOwn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/profile/${widget.post.userId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author?.displayName ??
                                AppLocalizations.of(context).unknownUser,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          if (author?.username != null)
                            Text(
                              '@${author!.username}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    timeago.format(
                      widget.post.createdAt,
                      locale: LocaleController.instance.timeagoLocale,
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: () => showPremiumActionSheet(
                      context,
                      actions: [
                        if (_isOwn)
                          PremiumAction(
                            icon: Icons.delete_outline_rounded,
                            label: AppLocalizations.of(context).delete,
                            destructive: true,
                            onTap: () {
                              Navigator.pop(context);
                              _delete();
                            },
                          )
                        else ...[
                          PremiumAction(
                            icon: Icons.report_problem_outlined,
                            label: AppLocalizations.of(context).report,
                            destructive: true,
                            onTap: () {
                              Navigator.pop(context);
                              _showReportMenu();
                            },
                          ),
                          PremiumAction(
                            icon: Icons.block_rounded,
                            label: AppLocalizations.of(context).blockThisUser,
                            destructive: true,
                            onTap: () {
                              Navigator.pop(context);
                              _blockAuthor();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scripture quote ──────────────────────────────────────────────
            if (widget.post.scriptureQuote != null)
              _ScriptureCard(
                quote: widget.post.scriptureQuote!,
                isDark: isDark,
              ),

            // ── Content text ─────────────────────────────────────────────────
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  widget.post.content,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),

            // ── Media ────────────────────────────────────────────────────────
            if (widget.post.videoUrl != null) ...[
              VideoThumbnailWidget(url: widget.post.videoUrl!),
              const SizedBox(height: 2),
            ] else if (widget.post.imageUrls.isNotEmpty) ...[
              _buildImageGrid(),
              const SizedBox(height: 2),
            ],

            // ── Topics ───────────────────────────────────────────────────────
            if (widget.post.topics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: widget.post.topics
                      .map(
                        (t) => GestureDetector(
                          onTap: () => widget.onTopicTap?.call(t),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            // ── Action bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
              child: Row(
                children: [
                  // Like
                  _ActionButton(
                    icon: ScaleTransition(
                      scale: _heartScale,
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: _isLiked ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                    label: _likesCount > 0 ? '$_likesCount' : '',
                    onTap: _toggleLike,
                  ),
                  // Comment
                  _ActionButton(
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 21,
                      color: Colors.grey.shade600,
                    ),
                    label: widget.post.commentsCount > 0
                        ? '${widget.post.commentsCount}'
                        : '',
                    onTap: () => context.push('/post/${widget.post.id}'),
                  ),
                  const Spacer(),
                  // Bookmark
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleBookmark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Icon(
                        _isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 22,
                        color: _isBookmarked
                            ? AppStyle.brand
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final images = widget.post.imageUrls;
    if (images.length == 1) {
      return GestureDetector(
        onTap: () => ImageViewer.show(context, imageUrls: images),
        child: CachedNetworkImage(
          imageUrl: images[0],
          width: double.infinity,
          height: 320,
          fit: BoxFit.cover,
        ),
      );
    }
    if (images.length == 2) {
      return Row(
        children: images.take(2).toList().asMap().entries.map((e) {
          return Expanded(
            child: GestureDetector(
              onTap: () => ImageViewer.show(
                context,
                imageUrls: images,
                initialIndex: e.key,
              ),
              child: Container(
                margin: EdgeInsets.only(left: e.key == 0 ? 0 : 1),
                child: CachedNetworkImage(
                  imageUrl: e.value,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
    // 3+ images: 3-col or 2+1 layout
    final display = images.take(9).toList();
    final cols = display.length == 3 ? 3 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: display.length > 9 ? 9 : display.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () =>
            ImageViewer.show(context, imageUrls: images, initialIndex: i),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: display[i], fit: BoxFit.cover),
            if (i == 8 && images.length > 9)
              Container(
                color: Colors.black.withAlpha(160),
                child: Center(
                  child: Text(
                    '+${images.length - 9}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Gradient avatar ring (Instagram story style) ─────────────────────────────

class _GradientAvatar extends StatelessWidget {
  final String? url;
  final String initial;
  final double radius;
  final bool hasRing;

  const _GradientAvatar({
    required this.url,
    required this.initial,
    required this.radius,
    this.hasRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF9575CD),
      backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );

    if (!hasRing) return avatar;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF9575CD), Color(0xFFE040FB), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: avatar,
      ),
    );
  }
}

// ─── Scripture quote card ─────────────────────────────────────────────────────

class _ScriptureCard extends StatelessWidget {
  final Map<String, dynamic> quote;
  final bool isDark;

  const _ScriptureCard({required this.quote, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2A1F3D), const Color(0xFF1E1E2E)]
                : [const Color(0xFFF3EDF9), const Color(0xFFEDE7F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF5E3F8E).withAlpha(80)
                : const Color(0xFFCE93D8).withAlpha(100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  size: 13,
                  color: Color(0xFF9575CD),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).scriptureQuote(
                      quote['scripture'] ?? '',
                      quote['chapter'] ?? '',
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9575CD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              quote['text'] as String? ?? '',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.65,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : const Color(0xFF3E2060),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action button row ────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
