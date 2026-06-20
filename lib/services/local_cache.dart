import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/premium_toast.dart';

/// 轻量文件缓存：把静态数据（经书/章节正文等）以 JSON 存到 app 文档目录，
/// 首次联网取到后写入，离线时读回。仅缓存“静态、与用户无关”的数据。
class LocalCache {
  LocalCache._();
  static final LocalCache instance = LocalCache._();

  Directory? _dir;
  final _memory = <String, dynamic>{}; // 进程内二级缓存，避免重复读盘

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/scripture_cache');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  String _safe(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<void> write(String key, Object json) async {
    if (kIsWeb) return; // web 不做文件缓存
    _memory[key] = json;
    try {
      final d = await _cacheDir();
      final f = File('${d.path}/${_safe(key)}.json');
      await f.writeAsString(jsonEncode(json));
    } catch (_) {}
  }

  /// 清空全部缓存（登出时调用，避免下一个登录用户看到上一个用户的缓存）。
  Future<void> clear() async {
    _memory.clear();
    if (kIsWeb) return;
    try {
      final d = await _cacheDir();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }

  /// 读缓存；不存在返回 null
  Future<dynamic> read(String key) async {
    if (_memory.containsKey(key)) return _memory[key];
    if (kIsWeb) return null;
    try {
      final d = await _cacheDir();
      final f = File('${d.path}/${_safe(key)}.json');
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      _memory[key] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }
}

/// 判断是否网络类错误（离线/连接失败），用于决定是否回退缓存、是否静默。
bool isNetworkError(Object e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return true;
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('clientexception') ||
      s.contains('connection') ||
      s.contains('network is unreachable') ||
      s.contains('xmlhttprequest') ||
      s.contains('authretryablefetchexception') ||
      s.contains('retryable') ||
      s.contains('no address associated');
}

/// 统一错误提示：网络/离线类错误一律静默（任何情况下离线不弹红错），
/// 仅非网络错误才提示。所有页面的加载/操作失败都应走这里。
void showErrorIfNotNetwork(BuildContext context, Object e, String message) {
  if (isNetworkError(e)) return;
  if (!context.mounted) return;
  // 会话失效（令牌过期/本地 currentUser 为空/RLS 拒）：统一提示重新登录，
  // 不把 SessionExpiredException / RLS 等原始文案暴露给用户。
  final s = e.toString();
  if (s.contains('SessionExpiredException') ||
      s.contains('row-level security') ||
      s.contains('JWT expired') ||
      s.contains('statusCode: 401') ||
      s.contains('statusCode: 403')) {
    showPremiumToast(context, AppLocalizations.of(context).sessionExpired,
        kind: ToastKind.error);
    return;
  }
  showPremiumToast(context, message, kind: ToastKind.error);
}
