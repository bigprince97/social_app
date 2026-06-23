import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全 app 语言控制器：持久化所选语言，驱动 MaterialApp 重建。
/// 用 ValueNotifier，稳定、零额外依赖（不需要 ProviderScope）。
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();
  static const _prefsKey = 'app_locale';

  /// null = 跟随系统；当前只允许中文，系统为英文/日文时会落到简体中文。
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// 支持的语言（顺序即设置页展示顺序）
  static const List<Locale> supported = [
    Locale('zh'), // 简体中文
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), // 繁體中文
  ];

  static const Map<String, String> labels = {'zh': '简体中文', 'zh_Hant': '繁體中文'};

  static String keyOf(Locale l) => l.scriptCode != null
      ? '${l.languageCode}_${l.scriptCode}'
      : l.languageCode;

  /// 当前圣经文本应使用的语言键：zh / zh_Hant。
  /// 英文、日文暂时完全屏蔽；系统是英文/日文时默认简体。
  String get bibleLang {
    final l = locale.value ?? WidgetsBinding.instance.platformDispatcher.locale;
    if (l.languageCode == 'zh') {
      return l.scriptCode == 'Hant' ? 'zh_Hant' : 'zh';
    }
    return 'zh';
  }

  /// timeago 包的 locale
  String get timeagoLocale {
    final b = bibleLang;
    if (b == 'zh_Hant') return 'zh_Hant';
    return 'zh';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == null) return;
      final parsed = _parse(code);
      if (_isSupported(parsed)) {
        locale.value = parsed;
      } else {
        await prefs.remove(_prefsKey);
        locale.value = null;
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale? l) async {
    if (l != null && !_isSupported(l)) {
      l = const Locale('zh');
    }
    locale.value = l;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (l == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, keyOf(l));
      }
    } catch (_) {}
  }

  static Locale _parse(String s) {
    final parts = s.split('_');
    if (parts.length > 1) {
      return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
    }
    return Locale(parts[0]);
  }

  static bool _isSupported(Locale l) =>
      supported.any((s) => keyOf(s) == keyOf(l));
}
