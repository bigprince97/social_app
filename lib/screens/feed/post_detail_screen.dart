import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../models/post.dart';
import '../../services/event_bus.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = PostService();
  final _commentCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Post? _post;
  List<PostComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _postService.getPostById(widget.postId),
        _postService.getComments(widget.postId),
      ]);
      setState(() {
        _post = results[0] as Post;
        _comments = results[1] as List<PostComment>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _submitting = true);
    _commentCtrl.clear();
    try {
      final comment = await _postService.addComment(
        postId: widget.postId,
        content: content,
      );
      notifyPostInteracted();
      setState(() {
        _comments.add(comment);
        _post = _post?.copyWith(commentsCount: _comments.length);
      });
      // 发送后收起键盘（不强制滑到最新，键盘收起后新评论一般已在可视区）
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).commentFailed(e));
        _commentCtrl.text = content;
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).postDetail)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (_post != null)
                          SliverToBoxAdapter(
                            child: PostCard(
                              post: _post!,
                              tappable: false,
                              onDeleted: () => context.pop(),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              '评论 (${_comments.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        _comments.isEmpty
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(child: Text(AppLocalizations.of(context).emptyComments)),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) =>
                                      _CommentTile(comment: _comments[i]),
                                  childCount: _comments.length,
                                ),
                              ),
                      ],
                    ),
                  ),
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildInputBar() {
    const brand = Color(0xFF9575CD);
    return Container(
      padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          // 键盘弹出时 Scaffold 已上移，无需再留安全区空白，避免下方大空隙
          (MediaQuery.of(context).viewInsets.bottom > 0
                  ? 0.0
                  : MediaQuery.of(context).padding.bottom) +
              10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 输入框：浅灰圆角胶囊，自然贴合一行、最多 4 行
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).writeCommentHint,
                hintStyle: const TextStyle(color: Color(0xFF9A9AA0)),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(21),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮：品牌色圆形
          GestureDetector(
            onTap: _submitting ? null : _submitComment,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: brand,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${comment.userId}'),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: author?.avatarUrl != null
                  ? CachedNetworkImageProvider(author!.avatarUrl!)
                  : null,
              child: author?.avatarUrl == null
                  ? Text(author?.displayName[0].toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 12))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile/${comment.userId}'),
                      child: Text(
                        author?.displayName ?? AppLocalizations.of(context).unknownUser,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt, locale: LocaleController.instance.timeagoLocale),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
