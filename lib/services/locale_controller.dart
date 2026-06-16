import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全 app 语言控制器：持久化所选语言，驱动 MaterialApp 重建。
/// 用 ValueNotifier，稳定、零额外依赖（不需要 ProviderScope）。
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();
  static const _prefsKey = 'app_locale';

  /// null = 跟随系统
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// 支持的语言（顺序即设置页展示顺序）
  static final List<Locale> supported = [
    const Locale('zh'), // 简体中文
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), // 繁體中文
    const Locale('en'), // English
    const Locale('ja'), // 日本語
  ];

  static const Map<String, String> labels = {
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
    'en': 'English',
    'ja': '日本語',
  };

  static String keyOf(Locale l) =>
      l.scriptCode != null ? '${l.languageCode}_${l.scriptCode}' : l.languageCode;

  /// 当前圣经文本应使用的语言键：zh / zh_Hant / en / ja
  /// （跟随 app 语言；未设置时跟随系统，默认简体）
  String get bibleLang {
    final l = locale.value ??
        WidgetsBinding.instance.platformDispatcher.locale;
    if (l.languageCode == 'ja') return 'ja';
    if (l.languageCode == 'en') return 'en';
    if (l.languageCode == 'zh') {
      return l.scriptCode == 'Hant' ? 'zh_Hant' : 'zh';
    }
    return 'zh';
  }

  /// timeago 包的 locale（繁中无对应，用 zh）
  String get timeagoLocale {
    final b = bibleLang;
    if (b == 'ja') return 'ja';
    if (b == 'en') return 'en';
    return 'zh';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null) locale.value = _parse(code);
    } catch (_) {}
  }

  Future<void> setLocale(Locale? l) async {
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
      return Locale.fromSubtags(
          languageCode: parts[0], scriptCode: parts[1]);
    }
    return Locale(parts[0]);
  }
}
