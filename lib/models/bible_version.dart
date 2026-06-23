class BibleVersion {
  final String id;
  final String label;
  final String language;
  final String description;

  const BibleVersion({
    required this.id,
    required this.label,
    required this.language,
    required this.description,
  });

  bool get isEnglish => language == 'en';
  bool get isJapanese => language == 'ja';

  static const niv = BibleVersion(
    id: 'niv',
    label: 'NIV',
    language: 'en',
    description: 'New International Version',
  );

  static const esv = BibleVersion(
    id: 'esv',
    label: 'ESV',
    language: 'en',
    description: 'English Standard Version',
  );

  static const nlt = BibleVersion(
    id: 'nlt',
    label: 'NLT',
    language: 'en',
    description: 'New Living Translation',
  );

  static const bsb = BibleVersion(
    id: 'bsb',
    label: 'BSB',
    language: 'en',
    description: 'Berean Standard Bible',
  );

  static const shinkyodo = BibleVersion(
    id: 'ja_shinkyodo',
    label: '新共同訳',
    language: 'ja',
    description: '新共同訳聖書',
  );

  static const all = [niv, esv, nlt, bsb, shinkyodo];

  static List<BibleVersion> forLanguage(String lang) {
    if (lang == 'ja') return all.where((v) => v.isJapanese).toList();
    if (lang == 'en') return all.where((v) => v.isEnglish).toList();
    return const [];
  }

  static BibleVersion? byId(String id) {
    for (final version in all) {
      if (version.id == id) return version;
    }
    return null;
  }

  static BibleVersion? defaultForLanguage(String lang) {
    if (lang == 'en') return niv;
    if (lang == 'ja') return shinkyodo;
    return null;
  }
}
