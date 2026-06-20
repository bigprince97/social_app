import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_cache.dart';

/// 经书离线下载：把整部经书的章节列表 + 每章正文写入本地缓存，
/// 并记录“已下载”状态。下载后即可离线阅读该经书。
class ScriptureDownloadService {
  ScriptureDownloadService._();
  static final ScriptureDownloadService instance =
      ScriptureDownloadService._();

  final _client = Supabase.instance.client;
  final _cache = LocalCache.instance;
  static const _prefsKey = 'downloaded_scriptures';

  Set<String>? _ids;

  Future<Set<String>> _loadIds() async {
    if (_ids != null) return _ids!;
    final p = await SharedPreferences.getInstance();
    _ids = (p.getStringList(_prefsKey) ?? []).toSet();
    return _ids!;
  }

  Future<bool> isDownloaded(String scriptureId) async {
    final ids = await _loadIds();
    return ids.contains(scriptureId);
  }

  Future<void> _setDownloaded(String scriptureId, bool v) async {
    final ids = await _loadIds();
    if (v) {
      ids.add(scriptureId);
    } else {
      ids.remove(scriptureId);
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_prefsKey, ids.toList());
  }

  /// 下载整部经书。onProgress(已完成章数, 总章数)。
  Future<void> download(
    String scriptureId, {
    void Function(int done, int total)? onProgress,
  }) async {
    const step = 200;
    var offset = 0;
    final listRows = <Map<String, dynamic>>[];
    // 先取一次总数（用于进度）
    var total = 0;
    while (true) {
      // 整页拉取「全字段」（含正文），逐章写 chapter2_<id> 缓存
      // （key 必须与 scripture_service 读取端 chapter2_/chapters2_ 一致，
      //  否则离线下载写入的内容读不出来）
      final data = await _client
          .from('scripture_chapters')
          .select()
          .eq('scripture_id', scriptureId)
          .order('chapter_number', ascending: true)
          .range(offset, offset + step - 1);
      final page = (data as List).cast<Map<String, dynamic>>();
      for (final row in page) {
        final id = row['id'] as String;
        await _cache.write('chapter2_$id', row);
        // 章节列表只留轻量字段（与 getChapters 选择一致）
        listRows.add({
          'id': row['id'],
          'scripture_id': row['scripture_id'],
          'chapter_number': row['chapter_number'],
          'title': row['title'],
          'title_i18n': row['title_i18n'],
          'created_at': row['created_at'],
        });
      }
      total = listRows.length;
      onProgress?.call(total, total + (page.length == step ? step : 0));
      if (page.length < step) break;
      offset += step;
    }
    // 写章节列表缓存
    await _cache.write('chapters2_$scriptureId', listRows);
    await _setDownloaded(scriptureId, true);
    onProgress?.call(total, total);
  }

  Future<void> remove(String scriptureId) async {
    await _setDownloaded(scriptureId, false);
    // 章节内容文件保留也无妨（占空间）；如需彻底清理可在此删除缓存文件。
  }
}
