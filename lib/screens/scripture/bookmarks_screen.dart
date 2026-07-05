import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../models/scripture.dart';
import '../../models/post.dart';
import '../../services/scripture_service.dart';
import '../../services/post_service.dart';
import '../../services/event_bus.dart';
import '../../widgets/post_card.dart';
import '../../theme/app_style.dart';

// cache chapters per scripture to avoid re-fetching
final _chaptersCache = <String, List<ScriptureChapter>>{};

/// 「我的书签」：经书书签 + 帖子收藏 两个 tab。
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.myBookmarks),
          bottom: TabBar(
            labelColor: AppStyle.brand,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: AppStyle.brand,
            tabs: [
              Tab(text: l.bookmarkTabScripture),
              Tab(text: l.bookmarkTabPosts),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ScriptureBookmarksTab(),
            _PostBookmarksTab(),
          ],
        ),
      ),
    );
  }
}

// ── 经书书签 tab ────────────────────────────────────────────────
class _ScriptureBookmarksTab extends StatefulWidget {
  const _ScriptureBookmarksTab();

  @override
  State<_ScriptureBookmarksTab> createState() => _ScriptureBookmarksTabState();
}

class _ScriptureBookmarksTabState extends State<_ScriptureBookmarksTab>
    with AutomaticKeepAliveClientMixin {
  final _service = ScriptureService();
  List<UserBookmark> _bookmarks = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.getMyBookmarks();
      if (mounted) setState(() => _bookmarks = list);
    } catch (e) {
      if (mounted && !isNetworkError(e)) {
        showErrorIfNotNetwork(
            context, e, AppLocalizations.of(context).loadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookmarks.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: AppLocalizations.of(context).noBookmarks,
        subtitle: AppLocalizations.of(context).bookmarkHint,
        color: AppStyle.orange,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, i) {
        final bk = _bookmarks[i];
        final s = bk.scripture;
        final ch = bk.chapter;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: s != null
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        s.title[0],
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : const Icon(Icons.bookmark),
            title: Row(
              children: [
                if (s != null)
                  Text('${s.title} · ',
                      style: TextStyle(
                          color: s.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                Expanded(
                  child: Text(
                    ch?.title ?? AppLocalizations.of(context).deletedChapter,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: ch != null
                ? Text(
                    ch.originalText ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (s == null || ch == null) return;
              List<ScriptureChapter> allChapters;
              allChapters =
                  _chaptersCache[s.id] ?? await _service.getChapters(s.id);
              _chaptersCache[s.id] = allChapters;
              final idx = allChapters.indexWhere((c) => c.id == ch.id);
              if (!context.mounted) return;
              context.push(
                '/scripture/read/${ch.id}',
                extra: {
                  'chapter':
                      allChapters.isEmpty ? ch : allChapters[idx < 0 ? 0 : idx],
                  'scripture': s,
                  'allChapters': allChapters.isEmpty ? [ch] : allChapters,
                  'initialIndex': idx < 0 ? 0 : idx,
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ── 帖子收藏 tab ────────────────────────────────────────────────
class _PostBookmarksTab extends StatefulWidget {
  const _PostBookmarksTab();

  @override
  State<_PostBookmarksTab> createState() => _PostBookmarksTabState();
}

class _PostBookmarksTabState extends State<_PostBookmarksTab>
    with AutomaticKeepAliveClientMixin {
  final _postService = PostService();
  List<Post> _posts = [];
  bool _loading = true;
  StreamSubscription<Post>? _interactedSub;
  StreamSubscription<String>? _deletedSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _interactedSub = onPostInteracted.listen((updatedPost) {
      if (!mounted) return;
      setState(() {
        if (!updatedPost.isBookmarked) {
          _posts.removeWhere((p) => p.id == updatedPost.id);
        } else {
          final i = _posts.indexWhere((p) => p.id == updatedPost.id);
          if (i != -1) _posts[i] = updatedPost;
        }
      });
    });
    _deletedSub = onPostDeleted.listen((postId) {
      if (mounted) setState(() => _posts.removeWhere((p) => p.id == postId));
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
      final posts = await _postService.getBookmarkedPosts();
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) showErrorIfNotNetwork(context, e, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(child: Text(l.noSavedPosts)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _posts.length,
              itemBuilder: (context, i) => PostCard(post: _posts[i]),
            ),
    );
  }
}
