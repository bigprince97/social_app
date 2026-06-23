import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/bible_version.dart';
import '../../models/scripture.dart';
import '../../services/bible_content_service.dart';
import '../../services/bible_version_controller.dart';
import '../../services/chat_service.dart';
import '../../services/locale_controller.dart';
import '../../services/scripture_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/premium_action_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/scripture_download_button.dart';

class ChapterReaderScreen extends StatefulWidget {
  final ScriptureChapter chapter;
  final Scripture scripture;
  final List<ScriptureChapter> allChapters;
  final int initialIndex;
  final int? initialVerse;

  const ChapterReaderScreen({
    super.key,
    required this.chapter,
    required this.scripture,
    required this.allChapters,
    required this.initialIndex,
    this.initialVerse,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final _service = ScriptureService();
  late int _currentIndex;
  late ScriptureChapter _chapter;
  bool _isBookmarked = false;
  bool _isHighlighted = false;
  String? _userNote;
  bool _loadingState = true;
  double _fontSize = 20;
  bool _uiBusy = false;
  final _scrollController = ScrollController();
  double _swipeDx = 0;
  int? _targetVerse;
  int? _flashVerse;
  final Map<int, GlobalKey> _verseKeys = {};
  final _bibleContentService = BibleContentService.instance;
  BibleVersion? _bibleVersion;
  String? _remoteBibleText;
  String? _remoteBibleTitle;
  String? _remoteBibleCopyright;
  String? _remoteBibleError;
  bool _remoteBibleLoading = false;

  bool get _isBible => widget.scripture.category == '基督';

  // 圣经按 app 语言显示；非圣经经书(道德经/金刚经)只有简/繁，繁体 locale 用 zh_Hant，其余回退简体
  String get _lang {
    final bl = LocaleController.instance.bibleLang;
    if (_isBible) return bl;
    return bl == 'zh_Hant' ? 'zh_Hant' : 'zh';
  }

  bool get _usesRemoteBible => _isBible && (_lang == 'en' || _lang == 'ja');
  BibleVersion? get _activeBibleVersion =>
      _bibleVersion ??
      BibleVersionController.instance.versionForLanguage(_lang);

  String get _displayText => _usesRemoteBible
      ? (_remoteBibleText ?? '')
      : _chapter.localizedText(_lang);
  String get _displayTitle => _usesRemoteBible
      ? (_remoteBibleTitle ?? _chapter.localizedTitle(_lang))
      : _chapter.localizedTitle(_lang);

  // ── 交叉引用（新约引用旧约）──────────────────────────────────
  Map<int, List<CrossReference>> _crossRefs = {};

  // ── 逐节选中 ──────────────────────────────────────────────────
  final Set<int> _selectedVerses = {};

  void _toggleVerseSelection(int verseNum) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedVerses.contains(verseNum)) {
        _selectedVerses.remove(verseNum);
      } else {
        _selectedVerses.add(verseNum);
      }
    });
  }

  String _selectedVersesText() {
    if (_displayText.isEmpty || _selectedVerses.isEmpty) return '';
    final sorted = _selectedVerses.toList()..sort();
    final verses = _parseBibleVerses(_displayText);
    final verseMap = {for (final v in verses) v.number: v};
    return sorted
        .map((n) => verseMap[n])
        .whereType<_BibleVerse>()
        .map((v) => '${v.number} ${v.text}')
        .join('\n');
  }

  void _copySelectedVerses() {
    final text = _selectedVersesText();
    if (text.isEmpty) return;
    Clipboard.setData(
      ClipboardData(
        text: '"$text"\n——《${widget.scripture.displayTitle}》$_displayTitle',
      ),
    );
    setState(() => _selectedVerses.clear());
    showPremiumToast(
      context,
      AppLocalizations.of(context).copiedToClipboard,
      kind: ToastKind.success,
    );
  }

  Future<void> _quoteSelectedVerses() async {
    final text = _selectedVersesText();
    if (text.isEmpty) return;
    setState(() => _selectedVerses.clear());
    final ctx = context;
    final convs = await _chatService.getConversations();
    if (!mounted || !ctx.mounted) return;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (bCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).selectConversation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: convs.length,
                itemBuilder: (_, i) {
                  final conv = convs[i];
                  return ListTile(
                    title: Text(conv.displayName(myId ?? '')),
                    subtitle: Text(
                      conv.type == 'group'
                          ? AppLocalizations.of(context).group
                          : AppLocalizations.of(context).privateChat,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(bCtx);
                      await _chatService.sendScriptureMessage(
                        conversationId: conv.id,
                        quoteText: text,
                        scriptureTitle: widget.scripture.title,
                        chapterTitle: _displayTitle,
                      );
                      if (mounted) {
                        showPremiumToast(
                          context,
                          AppLocalizations.of(context).sentToChat,
                          kind: ToastKind.success,
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _chapter = widget.chapter;
    _targetVerse = widget.initialVerse;
    _flashVerse = widget.initialVerse;
    _bibleVersion = BibleVersionController.instance.versionForLanguage(_lang);
    _ensureContent();
    _loadUserState();
    _loadCrossRefs();
    _scheduleVerseScroll();
    _clearVerseFlashLater();
  }

  Future<void> _ensureContent() async {
    if (_usesRemoteBible) {
      await _loadRemoteBibleContent();
      return;
    }
    if (_chapter.originalText != null) return;
    final full = await _service.getChapterContent(_chapter.id);
    if (mounted) {
      setState(() => _chapter = full);
      _scheduleVerseScroll();
    }
  }

  Future<void> _loadCrossRefs() async {
    if (!_isBible) return;
    final chapterId = _chapter.id;
    try {
      final refs = await _service.getCrossReferences(chapterId);
      // 防止快速翻章时旧请求覆盖
      if (mounted && _chapter.id == chapterId) {
        setState(() => _crossRefs = refs);
      }
    } catch (_) {}
  }

  Future<void> _loadUserState() async {
    setState(() => _loadingState = true);
    try {
      final state = await _service.getChapterUserState(_chapter.id);
      if (mounted) {
        setState(() {
          _isBookmarked = state['bookmarked'] as bool;
          _isHighlighted = state['highlighted'] as bool;
          _userNote = state['note'] as String?;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingState = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    if (_uiBusy) return;
    setState(() => _uiBusy = true);
    try {
      final result = await _service.toggleBookmark(
        _chapter.id,
        widget.scripture.id,
      );
      if (mounted) setState(() => _isBookmarked = result);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _uiBusy = false);
    }
  }

  Future<void> _toggleHighlight() async {
    if (_uiBusy) return;
    setState(() => _uiBusy = true);
    try {
      final result = await _service.toggleHighlight(_chapter.id, _displayText);
      if (mounted) setState(() => _isHighlighted = result);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _uiBusy = false);
    }
  }

  void _showNoteDialog() {
    final ctrl = TextEditingController(text: _userNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).noteTitle(_displayTitle)),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).noteHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          if (_userNote != null)
            TextButton(
              onPressed: () async {
                await _service.deleteNote(_chapter.id);
                if (!mounted) return;
                setState(() => _userNote = null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(
                AppLocalizations.of(context).delete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () async {
              final content = ctrl.text.trim();
              if (content.isEmpty) return;
              await _service.saveNote(
                _chapter.id,
                widget.scripture.id,
                content,
              );
              if (!mounted) return;
              setState(() => _userNote = content);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }

  final _chatService = ChatService();

  void _showQuoteOptions() {
    final plainQuote =
        '"$_displayText"\n——《${widget.scripture.displayTitle}》$_displayTitle';
    showPremiumActionSheet(
      context,
      title: _displayTitle,
      actions: [
        PremiumAction(
          icon: Icons.copy_rounded,
          label: AppLocalizations.of(context).copyScripture,
          color: AppStyle.blue,
          onTap: () {
            Clipboard.setData(ClipboardData(text: plainQuote));
            Navigator.pop(context);
            showPremiumToast(
              context,
              AppLocalizations.of(context).copiedToClipboard,
              kind: ToastKind.success,
            );
          },
        ),
        PremiumAction(
          icon: Icons.chat_bubble_outline_rounded,
          label: AppLocalizations.of(context).sendToChat,
          color: AppStyle.green,
          onTap: () {
            Navigator.pop(context);
            _pickConversationAndSend();
          },
        ),
      ],
    );
  }

  Future<void> _pickConversationAndSend() async {
    final ctx = context;
    final convs = await _chatService.getConversations();
    if (!mounted || !ctx.mounted) return;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).selectConversation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: convs.length,
                itemBuilder: (_, i) {
                  final conv = convs[i];
                  return ListTile(
                    title: Text(conv.displayName(myId ?? '')),
                    subtitle: Text(
                      conv.type == 'group'
                          ? AppLocalizations.of(context).group
                          : AppLocalizations.of(context).privateChat,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _chatService.sendScriptureMessage(
                        conversationId: conv.id,
                        quoteText: _displayText,
                        scriptureTitle: widget.scripture.title,
                        chapterTitle: _displayTitle,
                      );
                      if (mounted) {
                        showPremiumToast(
                          context,
                          AppLocalizations.of(context).sentToChat,
                          kind: ToastKind.success,
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToChapter(int index, {int? verse}) {
    if (index < 0 || index >= widget.allChapters.length) return;
    _verseKeys.clear();
    setState(() {
      _currentIndex = index;
      _chapter = widget.allChapters[index];
      _targetVerse = verse;
      _flashVerse = verse;
      _userNote = null;
      _isBookmarked = false;
      _isHighlighted = false;
      _selectedVerses.clear();
      _crossRefs = {};
      _remoteBibleText = null;
      _remoteBibleTitle = null;
      _remoteBibleCopyright = null;
      _remoteBibleError = null;
      _remoteBibleLoading = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _ensureContent();
    _loadUserState();
    _loadCrossRefs();
    _scheduleVerseScroll();
    _clearVerseFlashLater();
  }

  Future<void> _loadRemoteBibleContent({bool force = false}) async {
    final version = _activeBibleVersion;
    if (!_usesRemoteBible || version == null) return;
    if (!force &&
        _remoteBibleText != null &&
        _remoteBibleText!.isNotEmpty &&
        _remoteBibleError == null) {
      return;
    }
    final chapterId = _chapter.id;
    setState(() {
      _remoteBibleLoading = true;
      _remoteBibleError = null;
      _remoteBibleText = null;
      _remoteBibleTitle = null;
      _remoteBibleCopyright = null;
      _selectedVerses.clear();
    });
    try {
      final content = await _bibleContentService.getChapter(
        version: version,
        chapter: _chapter,
        fallbackIndex: _currentIndex,
      );
      if (!mounted || _chapter.id != chapterId) return;
      setState(() {
        _remoteBibleText = content.text;
        _remoteBibleTitle = content.title;
        _remoteBibleCopyright = content.copyright;
        _remoteBibleLoading = false;
      });
      _scheduleVerseScroll();
    } catch (e) {
      if (!mounted || _chapter.id != chapterId) return;
      setState(() {
        _remoteBibleError = e.toString();
        _remoteBibleLoading = false;
      });
    }
  }

  Future<void> _changeBibleVersion(BibleVersion version) async {
    setState(() => _bibleVersion = version);
    await BibleVersionController.instance.setVersion(version);
    await _loadRemoteBibleContent(force: true);
  }

  Future<void> _openApiBible() async {
    final uri = Uri.parse('https://api.bible');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _scheduleVerseScroll({int retry = 0}) {
    final verse = _targetVerse;
    if (!_isBible || verse == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _verseKeys[verse]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      } else if (retry < 4) {
        Future.delayed(
          const Duration(milliseconds: 120),
          () => _scheduleVerseScroll(retry: retry + 1),
        );
      }
    });
  }

  void _clearVerseFlashLater() {
    final verse = _flashVerse;
    if (verse == null) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _flashVerse == verse) {
        setState(() => _flashVerse = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
      onHorizontalDragCancel: () => _swipeDx = 0,
      onHorizontalDragEnd: (_) {
        final dx = _swipeDx;
        _swipeDx = 0;
        if (dx < -60) _goToChapter(_currentIndex + 1);
        if (dx > 60) _goToChapter(_currentIndex - 1);
      },
      child: _isBible ? _buildBibleReader() : _buildClassicReader(),
    );
  }

  static const _bibleAccent = Color(0xFF9575CD);
  static const _bibleVerseColor = Color(0xFF5D8A35);
  static const _bibleBg = Color(0xFFF5F4EE);

  int get _localChapterNum {
    final m = RegExp(r'第(\d+)章').firstMatch(_chapter.title);
    return m != null ? int.parse(m.group(1)!) : _currentIndex + 1;
  }

  String get _bibleBookName {
    // 用本地化标题，去掉结尾的「第N章」或「 N」得到书名
    final t = _displayTitle
        .replaceAll(RegExp(r'\s*第\d+章$'), '')
        .replaceAll(RegExp(r'\s+\d+$'), '')
        .trim();
    return t.isNotEmpty ? t : widget.scripture.displayTitle;
  }

  /// 某章对应的「书卷」原始名（用 raw title 分组，稳定不随语言变）
  String _rawBookOf(ScriptureChapter ch) {
    final raw = ch.title;
    return raw.contains(' ') ? raw.split(' ').first : raw;
  }

  /// 点击书名 → 原详情页「书卷」选择视图；选中后原地切章。
  void _openBookSelector() => _openSelector(chapterView: false);

  /// 点击章节号 → 原详情页「章」选择视图（当前书卷）；选中后原地切章。
  void _openChapterSelector() => _openSelector(chapterView: true);

  Future<void> _openSelector({required bool chapterView}) async {
    final id = await context.push<String>(
      '/scripture/detail/${widget.scripture.id}',
      extra: {
        'scripture': widget.scripture,
        'book': _rawBookOf(_chapter),
        if (chapterView) 'chapterView': true,
      },
    );
    if (!mounted || id == null) return;
    final idx = widget.allChapters.indexWhere((c) => c.id == id);
    if (idx >= 0 && idx != _currentIndex) _goToChapter(idx);
  }

  Future<void> _openSearch() async {
    final result = await context.push<ScriptureSearchResult>(
      '/scripture/search/${widget.scripture.id}',
      extra: {'scripture': widget.scripture, 'chapters': widget.allChapters},
    );
    if (!mounted || result == null) return;
    final idx = widget.allChapters.indexWhere((c) => c.id == result.chapter.id);
    if (idx >= 0) {
      _goToChapter(idx, verse: result.verseNumber);
    } else {
      showPremiumToast(
        context,
        AppLocalizations.of(context).chapterNotFound,
        kind: ToastKind.info,
      );
    }
  }

  // ── 圣经专属阅读器 ─────────────────────────────────────────────

  Widget _buildBibleReader() {
    final loading = _usesRemoteBible
        ? _remoteBibleLoading
        : _chapter.originalText == null;
    return Scaffold(
      backgroundColor: _bibleBg,
      appBar: _buildBibleAppBar(),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: _bibleAccent),
                  )
                : _usesRemoteBible &&
                      (_remoteBibleError != null || _displayText.isEmpty)
                ? _buildBibleUnavailable()
                : _buildBibleContent(),
          ),
          if (_selectedVerses.isNotEmpty) _buildVerseSelectionBar(),
          _buildBibleBottomBar(),
        ],
      ),
    );
  }

  Widget _buildVerseSelectionBar() {
    return Container(
      color: _bibleAccent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).selectedVerses(_selectedVerses.length),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _copySelectedVerses,
            icon: const Icon(Icons.copy, color: Colors.white, size: 17),
            label: Text(
              AppLocalizations.of(context).copy,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          TextButton.icon(
            onPressed: _quoteSelectedVerses,
            icon: const Icon(
              Icons.format_quote_outlined,
              color: Colors.white,
              size: 17,
            ),
            label: Text(
              AppLocalizations.of(context).quoteToChat,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedVerses.clear()),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  AppBar _buildBibleAppBar() {
    final canPrev = _currentIndex > 0;
    final canNext = _currentIndex < widget.allChapters.length - 1;
    return AppBar(
      backgroundColor: _bibleAccent,
      leading: const BackButton(color: Colors.white),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: _openBookSelector,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _bibleBookName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: canPrev ? () => _goToChapter(_currentIndex - 1) : null,
            child: Icon(
              Icons.arrow_left,
              color: canPrev ? Colors.white : Colors.white38,
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: _openChapterSelector,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                '$_localChapterNum',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: canNext ? () => _goToChapter(_currentIndex + 1) : null,
            child: Icon(
              Icons.arrow_right,
              color: canNext ? Colors.white : Colors.white38,
              size: 28,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (_usesRemoteBible) _buildBibleVersionMenu(),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: _openSearch,
          tooltip: AppLocalizations.of(context).search,
        ),
        PopupMenuButton<double>(
          icon: const Icon(Icons.format_size, color: Colors.white),
          onSelected: (v) => setState(() => _fontSize = v),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 16,
              child: Text(AppLocalizations.of(context).fontSizeSmall),
            ),
            PopupMenuItem(
              value: 20,
              child: Text(AppLocalizations.of(context).fontSizeNormal),
            ),
            PopupMenuItem(
              value: 24,
              child: Text(AppLocalizations.of(context).fontSizeLarge),
            ),
            PopupMenuItem(
              value: 28,
              child: Text(AppLocalizations.of(context).fontSizeExtraLarge),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBibleVersionMenu() {
    final current = _activeBibleVersion;
    final versions = BibleVersionController.instance.versionsForLanguage(_lang);
    return PopupMenuButton<BibleVersion>(
      icon: const Icon(Icons.translate_rounded, color: Colors.white),
      tooltip: '圣经版本',
      onSelected: _changeBibleVersion,
      itemBuilder: (_) => [
        for (final version in versions)
          PopupMenuItem(
            value: version,
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    version.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    version.description,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (current?.id == version.id)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBibleContent() {
    final verses = _parseBibleVerses(_displayText);
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bibleBookName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _bibleAccent,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_usesRemoteBible && _activeBibleVersion != null) ...[
                  const SizedBox(height: 8),
                  _BibleVersionChip(version: _activeBibleVersion!),
                ],
                const SizedBox(height: 4),
                Text(
                  _lang == 'en'
                      ? 'Chapter $_localChapterNum'
                      : '第$_localChapterNum章',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFD8D8CC), thickness: 0.8),
              ],
            ),
          ),

          // 笔记标签
          if (_userNote != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _userNote!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // 全章经文：所有节流排成一段，节号内联绿色
          Container(
            width: double.infinity,
            decoration: _isHighlighted
                ? BoxDecoration(
                    border: const Border(
                      left: BorderSide(color: Color(0xFF5D8A35), width: 3),
                    ),
                    color: const Color(0xFFF0F7E8),
                  )
                : null,
            padding: _isHighlighted
                ? const EdgeInsets.fromLTRB(12, 4, 0, 4)
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: verses.map(_buildVerseRow).toList(),
            ),
          ),

          const SizedBox(height: 48),
          if (_usesRemoteBible) _buildRemoteBibleAttribution(),
          const SizedBox(height: 18),
          if ((_remoteBibleCopyright ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                _remoteBibleCopyright!,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Color(0xFF777777),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteBibleAttribution() {
    final version = _activeBibleVersion;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF9575CD).withAlpha(14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9575CD).withAlpha(42),
          width: 0.7,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            version == null
                ? 'Bible text provided by'
                : '${version.label} provided by',
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: Color(0xFF777777),
              fontWeight: FontWeight.w600,
            ),
          ),
          InkWell(
            onTap: _openApiBible,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                'API.Bible',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0xFF6D53B3),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBibleUnavailable() {
    final version = _activeBibleVersion;
    final title = version == null ? '当前语言没有配置圣经版本' : '${version.label} 暂时不可用';
    final detail =
        _remoteBibleError ??
        '请先在 Supabase Edge Function secrets 中配置 API.Bible key 和该版本的 Bible ID。';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _bibleAccent, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF777777),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _loadRemoteBibleContent(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBibleBottomBar() {
    final canPrev = _currentIndex > 0;
    final canNext = _currentIndex < widget.allChapters.length - 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // 上一章
              _BibleBarBtn(
                icon: Icons.chevron_left,
                label: AppLocalizations.of(context).previousChapter,
                onTap: canPrev ? () => _goToChapter(_currentIndex - 1) : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BibleBarBtn(
                      icon: _userNote != null
                          ? Icons.edit_note
                          : Icons.edit_outlined,
                      label: AppLocalizations.of(context).note,
                      active: _userNote != null,
                      onTap: _showNoteDialog,
                    ),
                    _BibleBarBtn(
                      icon: _isHighlighted
                          ? Icons.highlight
                          : Icons.highlight_outlined,
                      label: AppLocalizations.of(context).highlight,
                      active: _isHighlighted,
                      activeColor: const Color(0xFFDDAA00),
                      onTap: _loadingState ? null : _toggleHighlight,
                    ),
                    _BibleBarBtn(
                      icon: _isBookmarked ? Icons.star : Icons.star_border,
                      label: AppLocalizations.of(context).bookmark,
                      active: _isBookmarked,
                      activeColor: const Color(0xFFE8956D),
                      onTap: _loadingState ? null : _toggleBookmark,
                    ),
                    _BibleBarBtn(
                      icon: Icons.format_quote_outlined,
                      label: AppLocalizations.of(context).quote,
                      onTap: _showQuoteOptions,
                    ),
                  ],
                ),
              ),
              // 下一章
              _BibleBarBtn(
                icon: Icons.chevron_right,
                label: AppLocalizations.of(context).nextChapter,
                onTap: canNext ? () => _goToChapter(_currentIndex + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 经典阅读器（道德经、金刚经） ────────────────────────────────

  Widget _buildClassicReader() {
    final s = widget.scripture;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: s.color.withAlpha(20),
        title: Column(
          children: [
            Text(s.title, style: const TextStyle(fontSize: 14)),
            Text(
              _displayTitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: s.color),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ScriptureDownloadButton(scriptureId: s.id),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
            tooltip: AppLocalizations.of(context).search,
          ),
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: _isBookmarked ? s.color : null,
            ),
            onPressed: _loadingState ? null : _toggleBookmark,
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            onSelected: (v) => setState(() => _fontSize = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 16,
                child: Text(AppLocalizations.of(context).fontSizeSmall),
              ),
              PopupMenuItem(
                value: 20,
                child: Text(AppLocalizations.of(context).fontSizeNormal),
              ),
              PopupMenuItem(
                value: 24,
                child: Text(AppLocalizations.of(context).fontSizeLarge),
              ),
              PopupMenuItem(
                value: 28,
                child: Text(AppLocalizations.of(context).fontSizeExtraLarge),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chapter.originalText == null
                ? const Center(child: CircularProgressIndicator())
                : SelectionArea(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 章节标题
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.scripture.displayTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: s.color,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displayTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Divider(
                                  color: s.color.withAlpha(60),
                                  thickness: 0.8,
                                ),
                              ],
                            ),
                          ),
                          if (_isHighlighted)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(50),
                                borderRadius: BorderRadius.circular(4),
                                border: Border(
                                  left: BorderSide(color: s.color, width: 3),
                                ),
                              ),
                              child: Text(
                                _displayText,
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  height: 1.9,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            )
                          else
                            Text(
                              _displayText,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.9,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          if (_userNote != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withAlpha(80),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.edit_note,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _userNote!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ), // SelectionArea
          ),
          _buildBottomBar(s),
        ],
      ),
    );
  }

  // ── 底部操作栏（共用） ────────────────────────────────────────

  Widget _buildBottomBar(Scripture s) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(50),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentIndex > 0
                    ? () => _goToChapter(_currentIndex - 1)
                    : null,
                tooltip: AppLocalizations.of(context).previousChapter,
              ),
              Expanded(
                child: Text(
                  '${_currentIndex + 1} / ${widget.allChapters.length}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isHighlighted ? Icons.highlight : Icons.highlight_outlined,
                  color: _isHighlighted ? Colors.amber.shade700 : null,
                ),
                onPressed: _loadingState ? null : _toggleHighlight,
                tooltip: AppLocalizations.of(context).highlight,
              ),
              IconButton(
                icon: Icon(
                  _userNote != null ? Icons.edit_note : Icons.note_add_outlined,
                  color: _userNote != null ? Colors.orange : null,
                ),
                onPressed: _showNoteDialog,
                tooltip: AppLocalizations.of(context).note,
              ),
              IconButton(
                icon: const Icon(Icons.format_quote_outlined),
                onPressed: _showQuoteOptions,
                tooltip: AppLocalizations.of(context).quote,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentIndex < widget.allChapters.length - 1
                    ? () => _goToChapter(_currentIndex + 1)
                    : null,
                tooltip: AppLocalizations.of(context).nextChapter,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 逐节行 Widget ─────────────────────────────────────────────

  Widget _buildVerseRow(_BibleVerse verse) {
    final isSelected = _selectedVerses.contains(verse.number);
    final isTarget = _flashVerse == verse.number;
    final refs = _crossRefs[verse.number];
    final hasRefs = refs != null && refs.isNotEmpty;
    return GestureDetector(
      key: _verseKeys.putIfAbsent(verse.number, GlobalKey.new),
      onTap: () => _toggleVerseSelection(verse.number),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          isSelected || isTarget ? 10.0 : 0.0,
          4,
          4,
          4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF9C4)
              : isTarget
              ? AppStyle.orange.withAlpha(34)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected || isTarget
              ? Border(
                  left: BorderSide(
                    color: isSelected ? _bibleAccent : AppStyle.orange,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${verse.number} ',
                style: const TextStyle(
                  fontSize: 11,
                  color: _bibleVerseColor,
                  fontWeight: FontWeight.bold,
                  height: 1.9,
                ),
              ),
              TextSpan(
                text: verse.text,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.9,
                  color: const Color(0xFF222222),
                ),
              ),
              if (hasRefs)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => _showCrossRefs(verse.number, refs),
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyle.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: AppStyle.orange.withAlpha(70),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_stories_rounded,
                            size: 11,
                            color: AppStyle.orange,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).oldTestamentCount(refs.length),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppStyle.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展示某节引用的旧约出处列表，点击跳转到对应章节和具体节。
  void _showCrossRefs(int verse, List<CrossReference> refs) {
    showPremiumActionSheet(
      context,
      title: AppLocalizations.of(
        context,
      ).crossReferenceTitle(_displayTitle, verse),
      actions: [
        for (final ref in refs)
          PremiumAction(
            icon: Icons.auto_stories_rounded,
            label: ref.label,
            color: AppStyle.orange,
            onTap: () {
              Navigator.pop(context);
              _jumpToChapter(ref.toChapterId, verse: ref.toVerseStart);
            },
          ),
      ],
    );
  }

  void _jumpToChapter(String chapterId, {int? verse}) {
    final idx = widget.allChapters.indexWhere((c) => c.id == chapterId);
    if (idx >= 0) {
      _goToChapter(idx, verse: verse);
    } else {
      showPremiumToast(
        context,
        AppLocalizations.of(context).chapterNotFound,
        kind: ToastKind.info,
      );
    }
  }

  // ── 圣经逐节解析 ─────────────────────────────────────────────

  List<_BibleVerse> _parseBibleVerses(String text) {
    final lines = text.split('\n');
    final verses = <_BibleVerse>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final space = trimmed.indexOf(' ');
      if (space > 0) {
        final num = int.tryParse(trimmed.substring(0, space));
        if (num != null) {
          verses.add(
            _BibleVerse(number: num, text: trimmed.substring(space + 1)),
          );
          continue;
        }
      }
      // continuation line — append to last verse
      if (verses.isNotEmpty) {
        final last = verses.last;
        verses[verses.length - 1] = _BibleVerse(
          number: last.number,
          text: '${last.text}$trimmed',
        );
      }
    }
    return verses;
  }
}

class _BibleVerse {
  final int number;
  final String text;
  const _BibleVerse({required this.number, required this.text});
}

class _BibleVersionChip extends StatelessWidget {
  final BibleVersion version;

  const _BibleVersionChip({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9575CD).withAlpha(22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF9575CD).withAlpha(70),
          width: 0.7,
        ),
      ),
      child: Text(
        '${version.label} · ${version.description}',
        style: const TextStyle(
          color: Color(0xFF6D53B3),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BibleBarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  const _BibleBarBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.activeColor = const Color(0xFF9575CD),
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : const Color(0xFF666666);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
