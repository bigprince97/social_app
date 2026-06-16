import '../l10n/app_localizations.dart';

/// 中文书名 → 当前语言书名（圣经书卷网格用）
String localizedBibleBook(AppLocalizations t, String cn) {
  final map = <String, String>{
    '创世记': t.bookGenesis,
    '出埃及记': t.bookExodus,
    '利未记': t.bookLeviticus,
    '民数记': t.bookNumbers,
    '申命记': t.bookDeuteronomy,
    '约书亚记': t.bookJoshua,
    '士师记': t.bookJudges,
    '路得记': t.bookRuth,
    '撒母耳记上': t.book1Samuel,
    '撒母耳记下': t.book2Samuel,
    '列王纪上': t.book1Kings,
    '列王纪下': t.book2Kings,
    '历代志上': t.book1Chronicles,
    '历代志下': t.book2Chronicles,
    '以斯拉记': t.bookEzra,
    '尼希米记': t.bookNehemiah,
    '以斯帖记': t.bookEsther,
    '约伯记': t.bookJob,
    '诗篇': t.bookPsalms,
    '箴言': t.bookProverbs,
    '传道书': t.bookEcclesiastes,
    '雅歌': t.bookSongOfSongs,
    '以赛亚书': t.bookIsaiah,
    '耶利米书': t.bookJeremiah,
    '耶利米哀歌': t.bookLamentations,
    '以西结书': t.bookEzekiel,
    '但以理书': t.bookDaniel,
    '何西阿书': t.bookHosea,
    '约珥书': t.bookJoel,
    '阿摩司书': t.bookAmos,
    '俄巴底亚书': t.bookObadiah,
    '约拿书': t.bookJonah,
    '弥迦书': t.bookMicah,
    '那鸿书': t.bookNahum,
    '哈巴谷书': t.bookHabakkuk,
    '西番雅书': t.bookZephaniah,
    '哈该书': t.bookHaggai,
    '撒迦利亚书': t.bookZechariah,
    '玛拉基书': t.bookMalachi,
    '马太福音': t.bookMatthew,
    '马可福音': t.bookMark,
    '路加福音': t.bookLuke,
    '约翰福音': t.bookJohn,
    '使徒行传': t.bookActs,
    '罗马书': t.bookRomans,
    '哥林多前书': t.book1Corinthians,
    '哥林多后书': t.book2Corinthians,
    '加拉太书': t.bookGalatians,
    '以弗所书': t.bookEphesians,
    '腓立比书': t.bookPhilippians,
    '歌罗西书': t.bookColossians,
    '帖撒罗尼迦前书': t.book1Thessalonians,
    '帖撒罗尼迦后书': t.book2Thessalonians,
    '提摩太前书': t.book1Timothy,
    '提摩太后书': t.book2Timothy,
    '提多书': t.bookTitus,
    '腓利门书': t.bookPhilemon,
    '希伯来书': t.bookHebrews,
    '雅各书': t.bookJames,
    '彼得前书': t.book1Peter,
    '彼得后书': t.book2Peter,
    '约翰一书': t.book1John,
    '约翰二书': t.book2John,
    '约翰三书': t.book3John,
    '犹大书': t.bookJude,
    '启示录': t.bookRevelation,
  };
  return map[cn] ?? cn;
}

/// 经书分类 key → 当前语言标签
String localizedScriptureCategory(AppLocalizations t, String key) {
  switch (key) {
    case '道':
      return t.categoryDaoism;
    case '佛':
      return t.categoryBuddhism;
    case '基督':
      return t.categoryChrisiandity;
    default:
      return key;
  }
}

/// 地区 code → 当前语言
String localizedRegion(AppLocalizations t, String code) {
  switch (code) {
    case 'CN-BJ':
      return t.regionCNBJ;
    case 'CN-SH':
      return t.regionCNSH;
    case 'CN-GD':
      return t.regionCNGD;
    case 'CN-ZJ':
      return t.regionCNZJ;
    case 'CN-JS':
      return t.regionCNJS;
    case 'CN-SC':
      return t.regionCNSC;
    case 'HK':
      return t.regionHK;
    case 'TW':
      return t.regionTW;
    case 'SG':
      return t.regionSG;
    case 'MY':
      return t.regionMY;
    case 'US':
      return t.regionUS;
    case 'CA':
      return t.regionCA;
    case 'AU':
      return t.regionAU;
    case 'GB':
      return t.regionGB;
    case 'JP':
      return t.regionJP;
    case 'KR':
      return t.regionKR;
    case 'OTHER':
      return t.regionOTHER;
    default:
      return code;
  }
}
