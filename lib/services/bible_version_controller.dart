import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_version.dart';

class BibleVersionController {
  BibleVersionController._();
  static final BibleVersionController instance = BibleVersionController._();

  static const _prefsPrefix = 'bible_version_';

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, String> _selectedByLanguage = {};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final lang in const ['en', 'ja']) {
        final id = prefs.getString('$_prefsPrefix$lang');
        final version = id == null ? null : BibleVersion.byId(id);
        if (version != null && version.language == lang) {
          _selectedByLanguage[lang] = version.id;
        }
      }
    } catch (_) {}
  }

  BibleVersion? versionForLanguage(String lang) {
    final normalized = _normalizeLanguage(lang);
    final selected = _selectedByLanguage[normalized];
    if (selected != null) return BibleVersion.byId(selected);
    return BibleVersion.defaultForLanguage(normalized);
  }

  List<BibleVersion> versionsForLanguage(String lang) =>
      BibleVersion.forLanguage(_normalizeLanguage(lang));

  Future<void> setVersion(BibleVersion version) async {
    _selectedByLanguage[version.language] = version.id;
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix${version.language}', version.id);
    } catch (_) {}
  }

  String _normalizeLanguage(String lang) {
    if (lang == 'ja') return 'ja';
    if (lang == 'en') return 'en';
    return 'zh';
  }
}
