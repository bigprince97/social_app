import 'package:supabase_flutter/supabase_flutter.dart';
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

    final uid = _userId;
    if (uid != null && list.isNotEmpty) {
      // 进度是联网增强项，离线则跳过，不影响经书正常显示
      try {
        final ids = list.map((s) => s.id).toList();
        final progress = await _client
            .from('reading_progress')
            .select()
            .eq('user_id', uid)
            .inFilter('scripture_id', ids);
        final progressMap = {
          for (final p in progress as List) p['scripture_id'] as String: p
        };
        for (final s in list) {
          final p = progressMap[s.id];
          if (p != null) {
            s.progressPercent = (p['progress_percent'] as int?) ?? 0;
            s.lastChapterId = p['chapter_id'] as String?;
          }
        }
      } catch (_) {/* 离线忽略进度 */}
    }
    return list;
  }

  Future<Scripture> getScriptureById(String id) async {
    final data = await _client
        .from('scriptures')
        .select()
        .eq('id', id)
        .single();
    final s = Scripture.fromJson(data);
    final uid = _userId;
    if (uid != null) {
      final progress = await _client
          .from('reading_progress')
          .select()
          .eq('user_id', uid)
          .eq('scripture_id', id)
          .maybeSingle();
      if (progress != null) {
        s.progressPercent = (progress['progress_percent'] as int?) ?? 0;
        s.lastChapterId = progress['chapter_id'] as String?;
      }
    }
    return s;
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
                  'id, scripture_id, chapter_number, title, title_i18n, created_at')
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
          for (final r in results[0] as List) r['chapter_id'] as String
        };
        final hlIds = {
          for (final r in results[1] as List) r['chapter_id'] as String
        };
        for (final c in all) {
          c.isBookmarked = bkIds.contains(c.id);
          c.isHighlighted = hlIds.contains(c.id);
        }
      } catch (_) {/* 离线忽略书签/划线 */}
    }
    return all;
  }

  /// 按需加载单章正文（章节列表不预加载正文）。
  /// 缓存优先：经文是静态内容，已缓存/已下载则直接秒出，不等网络往返；
  /// 无缓存才联网取并写入。
  Future<ScriptureChapter> getChapterContent(String chapterId) async {
    final cacheKey = 'chapter2_$chapterId';
    final cached = await _cache.read(cacheKey);
    if (cached is Map) {
      return ScriptureChapter.fromJson(Map<String, dynamic>.from(cached));
    }
    final data = await _client
        .from('scripture_chapters')
        .select()
        .eq('id', chapterId)
        .single();
    await _cache.write(cacheKey, data);
    return ScriptureChapter.fromJson(data);
  }

  /// 取本章每节的交叉引用（当前为新约引用旧约），按节号 → 引用列表分组，
  /// 每节内按 votes 降序。
  Future<Map<int, List<CrossReference>>> getCrossReferences(
      String chapterId) async {
    final cacheKey = 'xref_$chapterId';
    List rows;
    try {
      final data = await _client
          .from('scripture_cross_references')
          .select(
              'id, from_verse, to_chapter_id, to_verse_start, to_verse_end, votes, '
              'to_chapter:scripture_chapters!scripture_cross_references_to_chapter_id_fkey(title)')
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
    final uid = _userId!;
    final existing = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client.from('bookmarks').delete().eq('id', existing['id'] as String);
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
    final uid = _userId!;
    final existing = await _client
        .from('highlights')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client.from('highlights').delete().eq('id', existing['id'] as String);
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
      String chapterId, String scriptureId, String content) async {
    final uid = _userId!;
    final existing = await _client
        .from('reading_notes')
        .select('id')
        .eq('user_id', uid)
        .eq('chapter_id', chapterId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('reading_notes')
          .update({'content': content, 'updated_at': DateTime.now().toIso8601String()})
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
    final uid = _userId!;
    await _client
        .from('reading_notes')
        .delete()
        .eq('user_id', uid)
        .eq('chapter_id', chapterId);
  }

  Future<void> saveProgress({
    required String scriptureId,
    required String chapterId,
    required int progressPercent,
  }) async {
    final uid = _userId;
    if (uid == null) return;
    await _client.from('reading_progress').upsert({
      'user_id': uid,
      'scripture_id': scriptureId,
      'chapter_id': chapterId,
      'progress_percent': progressPercent,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<UserBookmark>> getMyBookmarks() async {
    final uid = _userId;
    if (uid == null) return [];
    final data = await _client
        .from('bookmarks')
        .select('*, scripture_chapters!chapter_id(*), scriptures!scripture_id(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((e) => UserBookmark.fromJson(e)).toList();
  }
}
