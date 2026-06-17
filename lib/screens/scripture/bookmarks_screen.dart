import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../models/scripture.dart';
import '../../services/scripture_service.dart';
import '../../theme/app_style.dart';

// cache chapters per scripture to avoid re-fetching
final _chaptersCache = <String, List<ScriptureChapter>>{};

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _service = ScriptureService();
  List<UserBookmark> _bookmarks = [];
  bool _loading = true;

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
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).myBookmarks)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? PremiumEmptyState(
                  icon: Icons.bookmark_outline_rounded,
                  title: AppLocalizations.of(context).noBookmarks,
                  subtitle: AppLocalizations.of(context).bookmarkHint,
                  color: AppStyle.orange,
                )
              : ListView.builder(
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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
                          allChapters = _chaptersCache[s.id] ??
                              await _service.getChapters(s.id);
                          _chaptersCache[s.id] = allChapters;
                          final idx = allChapters
                              .indexWhere((c) => c.id == ch.id);
                          if (!context.mounted) return;
                          context.push(
                            '/scripture/read/${ch.id}',
                            extra: {
                              'chapter': allChapters.isEmpty ? ch : allChapters[idx < 0 ? 0 : idx],
                              'scripture': s,
                              'allChapters': allChapters.isEmpty ? [ch] : allChapters,
                              'initialIndex': idx < 0 ? 0 : idx,
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
