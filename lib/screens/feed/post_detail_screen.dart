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
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        if (_post != null)
                          SliverToBoxAdapter(
                            child: PostCard(
                              post: _post!,
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
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border:
            Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).writeCommentHint,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _submitting ? null : _submitComment,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
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
