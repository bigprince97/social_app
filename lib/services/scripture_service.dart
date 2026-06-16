import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scripture.dart';

class ScriptureService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<Scripture>> getScripturesByCategory(String category) async {
    final data = await _client
        .from('scriptures')
        .select()
        .eq('category', category)
        .order('chapters_count', ascending: true);
    final list = (data as List).map((e) => Scripture.fromJson(e)).toList();

    final uid = _userId;
    if (uid != null && list.isNotEmpty) {
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
    final data = await _client
        .from('scriptures')
        .select()
        .order('category', ascending: true)
        .order('chapters_count', ascending: true);
    return (data as List).map((e) => Scripture.fromJson(e)).toList();
  }

  Future<List<ScriptureChapter>> getChapters(String scriptureId) async {
    // 分页拉取，绕过 Supabase 服务端 max-rows=1000 限制
    const batch = 1000;
    final all = <ScriptureChapter>[];
    var from = 0;
    while (true) {
      final data = await _client
          .from('scripture_chapters')
          .select('id, scripture_id, chapter_number, title, title_i18n, created_at')
          .eq('scripture_id', scriptureId)
          .order('chapter_number', ascending: true)
          .range(from, from + batch - 1);
      final page =
          (data as List).map((e) => ScriptureChapter.fromJson(e)).toList();
      all.addAll(page);
      if (page.length < batch) break;
      from += batch;
    }

    // 只有章节数量合理时才批量预取书签/划线状态（防止 URL 超长 400）
    final uid = _userId;
    if (uid != null && all.isNotEmpty && all.length <= 200) {
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
    }
    return all;
  }

  /// 按需加载单章正文（章节列表不预加载正文）
  Future<ScriptureChapter> getChapterContent(String chapterId) async {
    final data = await _client
        .from('scripture_chapters')
        .select()
        .eq('id', chapterId)
        .single();
    return ScriptureChapter.fromJson(data);
  }

  /// 取本章每节的交叉引用（当前为新约引用旧约），按节号 → 引用列表分组，
  /// 每节内按 votes 降序。
  Future<Map<int, List<CrossReference>>> getCrossReferences(
      String chapterId) async {
    final data = await _client
        .from('scripture_cross_references')
        .select(
            'id, from_verse, to_chapter_id, to_verse_start, to_verse_end, votes, '
            'to_chapter:scripture_chapters!scripture_cross_references_to_chapter_id_fkey(title)')
        .eq('from_chapter_id', chapterId)
        .order('votes', ascending: false);

    final grouped = <int, List<CrossReference>>{};
    for (final row in data as List) {
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
