import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/bible_version.dart';
import '../../models/scripture.dart';
import '../../services/bible_content_service.dart';
import '../../services/bible_version_controller.dart';
import '../../services/locale_controller.dart';
import '../../services/scripture_service.dart';
import '../../theme/app_style.dart';

class ScriptureSearchScreen extends StatefulWidget {
  final Scripture? scripture;
  final String? scriptureId;
  final List<ScriptureChapter> chapters;

  const ScriptureSearchScreen({
    super.key,
    this.scripture,
    this.scriptureId,
    this.chapters = const [],
  }) : assert(scripture != null || scriptureId != null);

  @override
  State<ScriptureSearchScreen> createState() => _ScriptureSearchScreenState();
}

class _ScriptureSearchScreenState extends State<ScriptureSearchScreen> {
  final _service = ScriptureService();
  final _bibleContentService = BibleContentService.instance;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  Scripture? _scripture;
  List<ScriptureChapter> _chapters = [];
  List<ScriptureSearchResult> _results = [];
  bool _loading = true;
  bool _searching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  bool get _isBible => _scripture?.category == '基督';
  String get _lang => LocaleController.instance.bibleLang;
  bool get _usesRemoteBibleSearch =>
      _isBible && (_lang == 'en' || _lang == 'ja');
  BibleVersion? get _bibleVersion =>
      BibleVersionController.instance.versionForLanguage(_lang);

  @override
  void initState() {
    super.initState();
    _scripture = widget.scripture;
    _chapters = widget.chapters;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _scripture ??= await _service.getScriptureById(widget.scriptureId!);
      if (_chapters.isEmpty) {
        _chapters = await _service.getChapters(_scripture!.id);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    final scripture = _scripture;
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    if (scripture == null || q == _lastQuery) return;
    _lastQuery = q;
    setState(() => _searching = true);
    try {
      final results = _usesRemoteBibleSearch && _bibleVersion != null
          ? [
              for (final hit in await _bibleContentService.search(
                query: q,
                version: _bibleVersion!,
                chapters: _chapters,
              ))
                ScriptureSearchResult(
                  scripture: scripture,
                  chapter: hit.chapter,
                  verseNumber: hit.verseNumber,
                  snippet: hit.snippet,
                ),
            ]
          : await _service.searchScriptureText(
              q,
              scriptureId: scripture.id,
              scripture: scripture,
            );
      if (mounted && q == _lastQuery) {
        setState(() {
          _results = results;
          _hasSearched = true;
        });
      }
    } catch (_) {
      if (mounted && q == _lastQuery) {
        setState(() {
          _results = [];
          _hasSearched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _reference(ScriptureSearchResult result) {
    final chapterTitle = result.chapter.localizedTitle(_lang);
    if (_isBible && result.verseNumber != null) {
      return AppLocalizations.of(
        context,
      ).crossRefVerse(chapterTitle, result.verseNumber!);
    }
    return chapterTitle;
  }

  void _selectResult(ScriptureSearchResult result) {
    Navigator.of(context).pop(result);
  }

  String _emptySubtitle(BuildContext context) {
    final lang = Localizations.localeOf(context).toLanguageTag();
    if (lang.startsWith('zh-Hant')) return '只搜尋目前這本經書的正文';
    if (lang.startsWith('zh')) return '只搜索当前这本经书的正文';
    if (lang.startsWith('ja')) return 'この経典の本文だけを検索します';
    return 'Search only within this scripture';
  }

  @override
  Widget build(BuildContext context) {
    final scripture = _scripture;
    final version = _usesRemoteBibleSearch ? _bibleVersion : null;
    final title =
        scripture?.displayTitle ?? AppLocalizations.of(context).scripture;
    final searchTitle = version == null ? title : '$title ${version.label}';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '${AppLocalizations.of(context).search}《$searchTitle》',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onChanged: (value) {
            setState(() {});
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 350),
              () => _search(value),
            );
          },
          onSubmitted: _search,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _loading || _searching
          ? Center(child: CircularProgressIndicator(color: scripture?.color))
          : !_hasSearched
          ? PremiumEmptyState(
              icon: Icons.search_rounded,
              title: '${AppLocalizations.of(context).search}《$searchTitle》',
              subtitle: _chapters.isEmpty
                  ? AppLocalizations.of(context).noChapterContent
                  : _emptySubtitle(context),
            )
          : _results.isEmpty
          ? PremiumEmptyState(
              icon: Icons.menu_book_rounded,
              title: AppLocalizations.of(context).emptyScriptures,
            )
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _results[index];
                final color = scripture?.color ?? result.scripture.color;
                return ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: color),
                  ),
                  title: Text(
                    _reference(result),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    result.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectResult(result),
                );
              },
            ),
    );
  }
}
