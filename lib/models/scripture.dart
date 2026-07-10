import 'package:flutter/material.dart';
import '../services/locale_controller.dart';

class Scripture {
  final String id;
  final String title;
  final String category;
  final String? author;
  final String? dynasty;
  final String? description;
  final String coverColor;
  final int chaptersCount;
  final DateTime createdAt;
  // 目录多语言（目前繁体）：{'zh_Hant': {title,category,author,dynasty,description}}
  final Map<String, dynamic>? metaI18n;

  Scripture({
    required this.id,
    required this.title,
    required this.category,
    this.author,
    this.dynasty,
    this.description,
    this.coverColor = '#8B4513',
    this.chaptersCount = 0,
    required this.createdAt,
    this.metaI18n,
  });

  // 繁体 locale 下取目录的繁体字段，缺失回退原值（简体）。
  String _meta(String field, String fallback) {
    if (LocaleController.instance.bibleLang == 'zh_Hant') {
      final m = metaI18n?['zh_Hant'];
      if (m is Map && m[field] is String && (m[field] as String).isNotEmpty) {
        return m[field] as String;
      }
    }
    return fallback;
  }

  String get displayTitle => _meta('title', title);
  String get displayCategory => _meta('category', category);
  String? get displayAuthor => author == null ? null : _meta('author', author!);
  String? get displayDynasty =>
      dynasty == null ? null : _meta('dynasty', dynasty!);
  String? get displayDescription =>
      description == null ? null : _meta('description', description!);

  factory Scripture.fromJson(Map<String, dynamic> json) => Scripture(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    author: json['author'] as String?,
    dynasty: json['dynasty'] as String?,
    description: json['description'] as String?,
    coverColor: (json['cover_color'] as String?) ?? '#8B4513',
    chaptersCount: (json['chapters_count'] as int?) ?? 0,
    metaI18n: json['meta_i18n'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Color get color {
    try {
      final hex = coverColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.brown;
    }
  }

  static const List<Map<String, dynamic>> categoryDefs = [
    {
      'key': '道',
      'label': '道家',
      'icon': Icons.blur_circular,
      'color': 0xFF2F4F4F,
    },
    {
      'key': '佛',
      'label': '佛经',
      'icon': Icons.self_improvement,
      'color': 0xFF4A2F8B,
    },
    {'key': '基督', 'label': '基督教', 'icon': Icons.church, 'color': 0xFF8B1A1A},
  ];
}

/// 圣经章内段落标题（如「预言圣殿被毁」），渲染在第 before 节之前
class ChapterHeading {
  final int before;
  final String title;

  const ChapterHeading({required this.before, required this.title});

  factory ChapterHeading.fromJson(Map<String, dynamic> json) => ChapterHeading(
    before: (json['before'] as num).toInt(),
    title: json['title'] as String,
  );
}

class ScriptureChapter {
  final String id;
  final String scriptureId;
  final int chapterNumber;
  final String title;
  final String? originalText;
  final String? annotation;
  final String? translation;
  final DateTime createdAt;
  // 多语言文本/标题（圣经）：{'en':..,'zh_Hant':..,'ja':..}，zh 用 originalText/title
  final Map<String, dynamic>? textI18n;
  final Map<String, dynamic>? titleI18n;
  // 段落标题（中文圣经，按节号插入），无数据时为 null
  final List<ChapterHeading>? headings;
  bool isBookmarked;
  String? userNote;

  ScriptureChapter({
    required this.id,
    required this.scriptureId,
    required this.chapterNumber,
    required this.title,
    this.originalText,
    this.annotation,
    this.translation,
    this.textI18n,
    this.titleI18n,
    this.headings,
    required this.createdAt,
    this.isBookmarked = false,
    this.userNote,
  });

  /// 按语言取正文：'zh' 用 originalText，其它取 text_i18n，缺失回退中文。
  String localizedText(String lang) {
    if (lang == 'zh') return originalText ?? '';
    final t = textI18n?[lang] as String?;
    return (t != null && t.isNotEmpty) ? t : (originalText ?? '');
  }

  /// 按语言取标题。
  String localizedTitle(String lang) {
    if (lang == 'zh') return title;
    final t = titleI18n?[lang] as String?;
    return (t != null && t.isNotEmpty) ? t : title;
  }

  factory ScriptureChapter.fromJson(Map<String, dynamic> json) =>
      ScriptureChapter(
        id: json['id'] as String,
        scriptureId: json['scripture_id'] as String,
        chapterNumber: json['chapter_number'] as int,
        title: json['title'] as String,
        originalText: json['original_text'] as String?,
        annotation: json['annotation'] as String?,
        translation: json['translation'] as String?,
        textI18n: json['text_i18n'] as Map<String, dynamic>?,
        titleI18n: json['title_i18n'] as Map<String, dynamic>?,
        headings: (json['headings'] as List?)
            ?.map(
              (e) =>
                  ChapterHeading.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class UserBookmark {
  final String id;
  final String userId;
  final String chapterId;
  final String scriptureId;
  final String? note;
  final DateTime createdAt;
  final ScriptureChapter? chapter;
  final Scripture? scripture;

  const UserBookmark({
    required this.id,
    required this.userId,
    required this.chapterId,
    required this.scriptureId,
    this.note,
    required this.createdAt,
    this.chapter,
    this.scripture,
  });

  factory UserBookmark.fromJson(Map<String, dynamic> json) => UserBookmark(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    chapterId: json['chapter_id'] as String,
    scriptureId: json['scripture_id'] as String,
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    chapter: json['scripture_chapters'] != null
        ? ScriptureChapter.fromJson(
            json['scripture_chapters'] as Map<String, dynamic>,
          )
        : null,
    scripture: json['scriptures'] != null
        ? Scripture.fromJson(json['scriptures'] as Map<String, dynamic>)
        : null,
  );
}

/// 经文交叉引用：本章某节（fromVerse）引用了另一处经文（目标章 + 节范围）。
/// 当前数据为「新约引用旧约」。
class CrossReference {
  final String id;
  final int fromVerse;
  final String toChapterId;
  final String toChapterTitle;
  final int toVerseStart;
  final int toVerseEnd;
  final int votes;

  const CrossReference({
    required this.id,
    required this.fromVerse,
    required this.toChapterId,
    required this.toChapterTitle,
    required this.toVerseStart,
    required this.toVerseEnd,
    required this.votes,
  });

  /// 目标引用的显示标签，如「以赛亚书 第7章 14节」或「…7-10节」。
  String get label {
    final verses = toVerseStart == toVerseEnd
        ? '$toVerseStart节'
        : '$toVerseStart-$toVerseEnd节';
    return '$toChapterTitle $verses';
  }

  factory CrossReference.fromJson(Map<String, dynamic> json) {
    final tc = json['to_chapter'] as Map<String, dynamic>?;
    return CrossReference(
      id: json['id'] as String,
      fromVerse: json['from_verse'] as int,
      toChapterId: json['to_chapter_id'] as String,
      toChapterTitle: (tc?['title'] as String?) ?? '',
      toVerseStart: json['to_verse_start'] as int,
      toVerseEnd: json['to_verse_end'] as int,
      votes: (json['votes'] as int?) ?? 0,
    );
  }
}

class ScriptureSearchResult {
  final Scripture scripture;
  final ScriptureChapter chapter;
  final int? verseNumber;
  final String snippet;

  const ScriptureSearchResult({
    required this.scripture,
    required this.chapter,
    required this.snippet,
    this.verseNumber,
  });
}
