import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import '../models/scripture.dart';
import 'local_cache.dart';

class ScriptureService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
  final _cache = LocalCache.instance;

  Future<List<Scripture>> getScripturesByCategory(String category) async {
    final cacheKey = 'scriptures_cat2_$category';
    List rawList;
    final cached0 = await _cache.read(cacheKey);
    if (cached0 is List && cached0.isNotEmpty) {
      // 缓存优先：经书列表基本静态，命中即秒出（弱网不卡）
      rawList = cached0;
    } else {
      final data = await _client
          .from('scriptures')
          .select()
          .eq('category', category)
          .order('chapters_count', ascending: true);
      rawList = data as List;
      await _cache.write(cacheKey, rawList);
    }
    final list = rawList.map((e) => Scripture.fromJson(e)).toList();
    return list;
  }

  Future<Scripture> getScriptureById(String id) async {
    final data = await _client
        .from('scriptures')
        .select()
        .eq('id', id)
        .single();
    return Scripture.fromJson(data);
  }

  Future<List<Scripture>> getAllScriptures() async {
    const cacheKey = 'scriptures_all_v2';
    // 缓存优先：列表静态，命中秒出，弱网不卡
    final cached = await _cache.read(cacheKey);
    if (cached is List && cached.isNotEmpty) {
      return cached.map((e) => Scripture.fromJson(e)).toList();
    }
    final data = await _client
        .from('scriptures')
        .select()
        .order('category', ascending: true)
        .order('chapters_count', ascending: true);
    await _cache.write(cacheKey, data as List);
    return data.map((e) => Scripture.fromJson(e)).toList();
  }

  Future<List<ScriptureChapter>> getChapters(String scriptureId) async {
    final cacheKey = 'chapters2_$scriptureId';
    final all = <ScriptureChapter>[];
    // 缓存优先：章节列表静态，命中即秒出，不等网络
    final cachedList = await _cache.read(cacheKey);
    if (cachedList is List && cachedList.isNotEmpty) {
      all.addAll(cachedList.map((e) => ScriptureChapter.fromJson(e)));
    } else {
      try {
        // 分页拉取，绕过 Supabase 服务端 max-rows=1000 限制
        const batch = 1000;
        final rawRows = <dynamic>[];
        var from = 0;
        while (true) {
          final data = await _client
              .from('scripture_chapters')
              .select(
                'id, scripture_id, chapter_number, title, title_i18n, created_at',
              )
              .eq('scripture_id', scriptureId)
              .order('chapter_number', ascending: true)
              .range(from, from + batch - 1);
          final page = data as List;
          rawRows.addAll(page);
          if (page.length < batch) break;
          from += batch;
        }
        await _cache.write(cacheKey, rawRows);
        all.addAll(rawRows.map((e) => ScriptureChapter.fromJson(e)));
      } catch (e) {
        rethrow;
      }
    }

    // 只有章节数量合理时才批量预取书签/划线状态（防止 URL 超长 400）
    final uid = _userId;
    if (uid != null && all.isNotEmpty && all.length <= 200) {
      // 书签/划线是联网增强项，离线跳过
      try {
        final ids = all.map((c) => c.id).toList();
        final results = await Future.wait([
          _client
              .from('bookmarks')
              .select('chapter_id')
              .eq('user_id', uid)
              .inFilter('chapter_id', ids),
          _client
              .from('highlights')
              .select('chapter_id')
              .eq('user_id', uid)
              .inFilter('chapter_id', ids),
        ]);
        final bkIds = {
          for (final r in results[0] as List) r['chapter_id'] as String,
        };
        final hlIds = {
          for (final r in results[1] as List) r['chapter_id'] as String,
        };
        for (final c in all) {
          c.isBookmarked = bkIds.contains(c.id);
          c.isHighlighted = hlIds.contains(c.id);
        }
      } catch (_) {
        /* 离线忽略书签/划线 */
      }
    }
    return all;
  }

  /// 按需加载单章正文（章节列表不预加载正文）。
  /// 缓存优先：经文是静态内容，已缓存/已下载则直接秒出，不等网络往返；
  /// 无缓存才联网取并写入。
  Future<ScriptureChapter> getChapterContent(String chapterId) async {
    final cacheKey = 'chapter2_$chapterId';
    final cached = await _cache.read(cacheKey);
    // 缓存中正文为空视为脏数据，忽略并重新联网取
    if (cached is Map && cached['original_text'] != null) {
      return ScriptureChapter.fromJson(Map<String, dynamic>.from(cached));
    }
    final data = await _client
        .from('scripture_chapters')
        .select()
        .eq('id', chapterId)
        .single();
    // 空正文不写缓存，避免之后每次进该章都读到空内容
    if (data['original_text'] != null) {
      await _cache.write(cacheKey, data);
    }
    return ScriptureChapter.fromJson(data);
  }

  Future<List<ScriptureSearchResult>> searchScriptureText(
    String query, {
    String? scriptureId,
    Scripture? scripture,
    int limit = 40,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    var request = _client
        .from('scripture_chapters')
        .select(
          'id, scripture_id, chapter_number, title, original_text, annotation, '
          'translation, text_i18n, title_i18n, created_at',
        )
        .ilike('original_text', '%$q%');
    if (scriptureId != null) {
      request = request.eq('scripture_id', scriptureId);
    }
    final rows = await request
        .order('chapter_number', ascending: true)
        .limit(limit);

    final chapters = (rows as List)
        .map((e) => ScriptureChapter.fromJson(e as Map<String, dynamic>))
        .toList();
    if (chapters.isEmpty) return [];

    final scriptures = <String, Scripture>{};
    if (scripture != null) {
      scriptures[scripture.id] = scripture;
    }
    final missingIds = chapters
        .map((c) => c.scriptureId)
        .where((id) => !scriptures.containsKey(id))
        .toSet()
        .toList();
    if (missingIds.isNotEmpty) {
      final scriptureRows = await _client
          .from('scriptures')
          .select()
          .inFilter('id', missingIds);
      for (final row in scriptureRows as List) {
        final map = row as Map<String, dynamic>;
        scriptures[map['id'] as String] = Scripture.fromJson(map);
      }
    }

    return [
      for (final chapter in chapters)
        if (scriptures[chapter.scriptureId] != null)
          ScriptureSearchResult(
            scripture: scriptures[chapter.scriptureId]!,
            chapter: chapter,
            verseNumber: _matchedVerseNumber(chapter.originalText ?? '', q),
            snippet: _matchedSnippet(chapter.originalText ?? '', q),
          ),
    ];
  }

  int? _matchedVerseNumber(String text, String query) {
    final lowerQuery = query.toLowerCase();
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.toLowerCase().contains(lowerQuery)) continue;
      final space = trimmed.indexOf(' ');
      if (space <= 0) return null;
      return int.tryParse(trimmed.substring(0, space));
    }
    return null;
  }

  String _matchedSnippet(String text, String query) {
    final lowerQuery = query.toLowerCase();
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().contains(lowerQuery)) {
        final space = trimmed.indexOf(' ');
        final body = space > 0 ? trimmed.substring(space + 1) : trimmed;
        return _compactSnippet(body, query);
      }
    }
    return _compactSnippet(text.replaceAll('\n', ' '), query);
  }

  String _compactSnippet(String text, String query) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 96) return normalized;
    final idx = normalized.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return '${normalized.substring(0, 96)}...';
    final start = (idx - 36).clamp(0, normalized.length);
    final end = (idx + query.length + 56).clamp(0, normalized.length);
    return '${start > 0 ? '...' : ''}${normalized.substring(start, end)}${end < normalized.length ? '...' : ''}';
  }

  /// 取本章每节的交叉引用（当前为新约引用旧约），按节号 → 引用列表分组，
  /// 每节内按 votes 降序。
  Future<Map<int, List<CrossReference>>> getCrossReferences(
    String chapterId,
  ) async {
    final cacheKey = 'xref_$chapterId';
    List rows;
    try {
      final data = await _client
          .from('scripture_cross_references')
          .select(
            'id, from_verse, to_chapter_id, to_verse_start, to_verse_end, votes, '
            'to_chapter:scripture_chapters!scripture_cross_references_to_chapter_id_fkey(title)',
          )
          .eq('from_chapter_id', chapterId)
          .order('votes', ascending: false);
      rows = data as List;
      await _cache.write(cacheKey, rows);
    } catch (e) {
      final cached = await _cache.read(cacheKey);
      if (cached is List) {
        rows = cached;
      } else {
        // 交叉引用是增强项，离线且无缓存时返回空，不抛错
        return {};
      }
    }

    final grouped = <int, List<CrossReference>>{};
    for (final row in rows) {
      final ref = CrossReference.fromJson(row as Map<String, dynamic>);
      grouped.putIfAbsent(ref.fromVerse, () => []).add(ref);
    }
    return grouped;
  }

  Future<Map<String, dynamic>> getChapterUserState(String chapterId) async {
    final uid = _userId;
    if (uid == null) {
      return {'bookmarked': false, 'highlighted': false, 'note': null};
    }
    final results = await Future.wait([
      _client
          .from('bookmarks')
          .select('id')
          .eq('user_id', uid)
          .eq('chapter_id', chapterId)
          .maybeSingle(),
      _client
          .from('highlights')
          .select('id')
          .eq('user_id', uid)
          .eq('chapter_id', chapterId)
          .maybeSingle(),
      _client
          .from('reading_notes')
          .select('content')
          .eq('user_id', uid)
          .eq('chapter_id', chapterId)
          .maybeSingle(),
    ]);
    return {
      'bookmarked': results[0] != null,
      'highlighted': results[1] != null,
      'note': results[2]?['content'],
    };
  }

  Future<bool> toggleBookmark(String chapterId, String scriptureId) async {
    final uid = requireUid(_client);
    final existing = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('bookmarks')
          .delete()
          .eq('id', existing['id'] as String);
      return false;
    }
    await _client.from('bookmarks').insert({
      'user_id': uid,
      'chapter_id': chapterId,
      'scripture_id': scriptureId,
    });
    return true;
  }

  Future<bool> toggleHighlight(String chapterId, String text) async {
    final uid = requireUid(_client);
    final existing = await _client
        .from('highlights')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('highlights')
          .delete()
          .eq('id', existing['id'] as String);
      return false;
    }
    await _client.from('highlights').insert({
      'user_id': uid,
      'chapter_id': chapterId,
      'selected_text': text,
      'start_offset': 0,
      'end_offset': text.length,
    });
    return true;
  }

  Future<void> saveNote(
    String chapterId,
    String scriptureId,
    String content,
  ) async {
    final uid = requireUid(_client);
    final existing = await _client
        .from('reading_notes')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('reading_notes')
          .update({
            'content': content,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('reading_notes').insert({
        'user_id': uid,
        'chapter_id': chapterId,
        'scripture_id': scriptureId,
        'content': content,
      });
    }
  }

  Future<void> deleteNote(String chapterId) async {
    final uid = requireUid(_client);
    await _client
        .from('reading_notes')
        .delete()
        .eq('user_id', uid)
        .eq('chapter_id', chapterId);
  }

  Future<List<UserBookmark>> getMyBookmarks() async {
    final uid = _userId;
    if (uid == null) return [];
    final data = await _client
        .from('bookmarks')
        .select(
          '*, scripture_chapters!chapter_id(*), scriptures!scripture_id(*)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((e) => UserBookmark.fromJson(e)).toList();
  }
}
