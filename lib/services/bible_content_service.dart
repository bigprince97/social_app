import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bible_version.dart';
import '../models/scripture.dart';
import '../utils/bible_api_books.dart';

class BibleContent {
  final String text;
  final String title;
  final String? copyright;

  const BibleContent({required this.text, required this.title, this.copyright});
}

class BibleRemoteSearchHit {
  final ScriptureChapter chapter;
  final int? verseNumber;
  final String snippet;

  const BibleRemoteSearchHit({
    required this.chapter,
    required this.snippet,
    this.verseNumber,
  });
}

class BibleApiException implements Exception {
  final String code;
  final String message;

  const BibleApiException(this.code, this.message);

  @override
  String toString() => message;
}

class BibleContentService {
  BibleContentService._();
  static final BibleContentService instance = BibleContentService._();

  final _client = Supabase.instance.client;
  final _memoryCache = <String, BibleContent>{};

  Future<BibleContent> getChapter({
    required BibleVersion version,
    required ScriptureChapter chapter,
    required int fallbackIndex,
  }) async {
    final book = rawBibleBookName(chapter.title);
    final bookCode = bibleApiBookCodes[book];
    final chapterNumber = localBibleChapterNumber(
      chapter.title,
      fallbackIndex + 1,
    );
    if (bookCode == null) {
      throw BibleApiException('unknown_book', '找不到《$book》对应的 API.Bible 书卷代码。');
    }

    final cacheKey = '${version.id}:$bookCode:$chapterNumber';
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;

    final data = await _invoke({
      'action': 'chapter',
      'version': version.id,
      'book': bookCode,
      'chapter': chapterNumber,
    });
    final content = BibleContent(
      text: (data['text'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : chapter.localizedTitle(version.language),
      copyright: data['copyright'] as String?,
    );
    if (content.text.isEmpty) {
      throw const BibleApiException('empty_content', '这个版本没有返回当前章节正文。');
    }
    _memoryCache[cacheKey] = content;
    return content;
  }

  Future<List<BibleRemoteSearchHit>> search({
    required String query,
    required BibleVersion version,
    required List<ScriptureChapter> chapters,
    int limit = 40,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final data = await _invoke({
      'action': 'search',
      'version': version.id,
      'query': q,
      'limit': limit,
    });
    final rows = (data['results'] as List? ?? const []);
    if (rows.isEmpty) return const [];

    final chapterByKey = <String, ScriptureChapter>{};
    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final book = rawBibleBookName(ch.title);
      final bookCode = bibleApiBookCodes[book];
      if (bookCode == null) continue;
      final chapterNum = localBibleChapterNumber(ch.title, i + 1);
      chapterByKey['$bookCode.$chapterNum'] = ch;
    }

    final hits = <BibleRemoteSearchHit>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final book = row['book'] as String?;
      final chapterNum = row['chapter'] as int?;
      if (book == null || chapterNum == null) continue;
      final chapter = chapterByKey['$book.$chapterNum'];
      if (chapter == null) continue;
      hits.add(
        BibleRemoteSearchHit(
          chapter: chapter,
          verseNumber: row['verse'] as int?,
          snippet: (row['snippet'] as String?)?.trim() ?? '',
        ),
      );
    }
    return hits;
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'bible-passage',
      body: body,
    );
    final data = response.data;
    if (data is! Map) {
      throw const BibleApiException('bad_response', '圣经版本服务返回了无法识别的数据。');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['ok'] == false) {
      throw BibleApiException(
        (map['code'] as String?) ?? 'remote_error',
        (map['message'] as String?) ?? '圣经版本服务暂时不可用。',
      );
    }
    return map;
  }
}
