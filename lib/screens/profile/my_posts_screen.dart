import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/post.dart';
import '../../services/event_bus.dart';
import '../../services/post_service.dart';
import '../../services/local_cache.dart';
import '../../widgets/post_card.dart';

/// 「我的发帖」独立页：点进来才加载并展示自己的帖子。
class MyPostsScreen extends StatefulWidget {
  final String userId;
  const MyPostsScreen({super.key, required this.userId});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final _postService = PostService();
  List<Post> _posts = [];
  bool _loading = true;
  StreamSubscription<Post>? _interactedSub;
  StreamSubscription<String>? _deletedSub;

  @override
  void initState() {
    super.initState();
    _load();
    _interactedSub = onPostInteracted.listen((updatedPost) {
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == updatedPost.id);
          if (index != -1) {
            _posts[index] = updatedPost;
          }
        });
      }
    });
    _deletedSub = onPostDeleted.listen((postId) {
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.id == postId);
        });
      }
    });
  }

  @override
  void dispose() {
    _interactedSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = await _postService.getUserPosts(widget.userId);
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) showErrorIfNotNetwork(context, e, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).myPosts)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Text(AppLocalizations.of(context).noPosts),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _posts.length,
                      itemBuilder: (context, i) => PostCard(post: _posts[i]),
                    ),
            ),
    );
  }
}
