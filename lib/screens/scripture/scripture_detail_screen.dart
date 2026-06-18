import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
import '../../services/local_cache.dart';
import '../../models/scripture.dart';
import '../../services/locale_controller.dart';
import '../../services/scripture_service.dart';
import '../../services/scripture_download_service.dart';
import '../../utils/bible_books.dart';
import '../../widgets/premium_action_sheet.dart';

class ScriptureDetailScreen extends StatefulWidget {
  final Scripture? scripture;
  final String? scriptureId;
  final bool autoStart;

  const ScriptureDetailScreen({
    super.key,
    this.scripture,
    this.scriptureId,
    this.autoStart = false,
  }) : assert(scripture != null || scriptureId != null);

  @override
  State<ScriptureDetailScreen> createState() => _ScriptureDetailScreenState();
}

class _ScriptureDetailScreenState extends State<ScriptureDetailScreen> {
  final _service = ScriptureService();
  List<ScriptureChapter> _chapters = [];
  bool _loading = true;
  Scripture? _scripture;

  @override
  void initState() {
    super.initState();
    _scripture = widget.scripture;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _scripture ??= await _service.getScriptureById(widget.scriptureId!);
      final chapters = await _service.getChapters(_scripture!.id);
      if (mounted) {
        setState(() => _chapters = chapters);
        if (widget.autoStart && chapters.isNotEmpty) {
          // small delay so the screen finishes building first
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              final lastIdx = chapters.indexWhere(
                  (c) => c.id == _scripture!.lastChapterId);
              _openChapter(lastIdx >= 0 ? lastIdx : 0);
            }
          });
        }
      }
    } catch (e) {
      if (mounted && !isNetworkError(e)) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChapter(int index) {
    context.push(
      '/scripture/read/${_chapters[index].id}',
      extra: {
        'chapter': _chapters[index],
        'scripture': _scripture,
        'allChapters': _chapters,
        'initialIndex': index,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scripture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _scripture!;

    if (s.category == '基督') {
      return _BibleDetailScreen(
        scripture: s,
        chapters: _chapters,
        loading: _loading,
        onOpen: _openChapter,
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(s),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                Text(AppLocalizations.of(context).contents,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (_loading) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: s.color),
                  ),
                ],
              ]),
            ),
          ),
          if (_loading && _chapters.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: s.color)),
              ),
            )
          else if (_chapters.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(AppLocalizations.of(context).noChapterContent)),
              ),
            )
          else if (s.category == '道')
            _DaoDeJingContents(
                chapters: _chapters, color: s.color, onTap: _openChapter)
          else
            _DefaultContents(
                chapters: _chapters, color: s.color, onTap: _openChapter),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _chapters.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final lastIdx =
                    _chapters.indexWhere((c) => c.id == s.lastChapterId);
                _openChapter(lastIdx >= 0 ? lastIdx : 0);
              },
              backgroundColor: s.color,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                s.progressPercent != null && s.progressPercent! > 0
                    ? AppLocalizations.of(context).continueReading
                    : AppLocalizations.of(context).startReading,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  SliverAppBar _buildAppBar(Scripture s) {
    final progress = (s.progressPercent ?? 0) / 100.0;
    final hasProgress = (s.progressPercent ?? 0) > 0;
    final coverText =
        s.displayTitle.length > 2 ? s.displayTitle.substring(0, 2) : s.displayTitle;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: s.color,
      iconTheme: const IconThemeData(color: Colors.white),
      // Title only shown in collapsed (pinned) state
      title: Text(s.displayTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      actions: [
        ScriptureDownloadButton(scriptureId: s.id, color: Colors.white),
      ],
      flexibleSpace: FlexibleSpaceBar(
        // No title here — avoids overlap with background content
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [s.color, s.color.withAlpha(190), s.color.withAlpha(150)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(12),
                  ),
                ),
              ),
              // Content: top-aligned inside safe area
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Book cover
                      Container(
                        width: 64,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withAlpha(60), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            coverText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.displayTitle,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            if (s.author != null || s.dynasty != null)
                              Text(
                                [
                                  if (s.displayDynasty != null) s.displayDynasty!,
                                  if (s.displayAuthor != null) s.displayAuthor!,
                                ].join(' · '),
                                style: TextStyle(
                                    color: Colors.white.withAlpha(190),
                                    fontSize: 13),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.menu_book_rounded,
                                    size: 13,
                                    color: Colors.white.withAlpha(200)),
                                const SizedBox(width: 4),
                                Text(AppLocalizations.of(context).chaptersCountLabel(s.chaptersCount),
                                    style: TextStyle(
                                        color: Colors.white.withAlpha(200),
                                        fontSize: 12.5)),
                                if (hasProgress) ...[
                                  const SizedBox(width: 10),
                                  Text('· ${AppLocalizations.of(context).readPercent(s.progressPercent ?? 0)}',
                                      style: TextStyle(
                                          color: Colors.white.withAlpha(180),
                                          fontSize: 12)),
                                ],
                              ],
                            ),
                            if (hasProgress) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      Colors.white.withAlpha(40),
                                  valueColor:
                                      const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 圣经专属 UI ──────────────────────────────────────────────────

class _BibleDetailScreen extends StatefulWidget {
  final Scripture scripture;
  final List<ScriptureChapter> chapters;
  final bool loading;
  final void Function(int) onOpen;

  const _BibleDetailScreen({
    required this.scripture,
    required this.chapters,
    required this.loading,
    required this.onOpen,
  });

  @override
  State<_BibleDetailScreen> createState() => _BibleDetailScreenState();
}

class _BibleDetailScreenState extends State<_BibleDetailScreen> {
  static const _accent = Color(0xFF9575CD);
  static const _bg = Color(0xFFF5F4EE);
  static const _selected = Color(0xFFE8956D);

  bool _isBookView = true;
  String? _viewBook; // 当前章 view 对应的书
  bool _otExpanded = true;
  bool _ntExpanded = true;

  static const _otBooks = [
    '创世记','出埃及记','利未记','民数记','申命记',
    '约书亚记','士师记','路得记','撒母耳记上','撒母耳记下',
    '列王纪上','列王纪下','历代志上','历代志下','以斯拉记',
    '尼希米记','以斯帖记','约伯记','诗篇','箴言',
    '传道书','雅歌','以赛亚书','耶利米书','耶利米哀歌',
    '以西结书','但以理书','何西阿书','约珥书','阿摩司书',
    '俄巴底亚书','约拿书','弥迦书','那鸿书','哈巴谷书',
    '西番雅书','哈该书','撒迦利亚书','玛拉基书',
  ];
  static const _ntBooks = [
    '马太福音','马可福音','路加福音','约翰福音','使徒行传',
    '罗马书','哥林多前书','哥林多后书','加拉太书','以弗所书',
    '腓立比书','歌罗西书','帖撒罗尼迦前书','帖撒罗尼迦后书',
    '提摩太前书','提摩太后书','提多书','腓利门书','希伯来书',
    '雅各书','彼得前书','彼得后书','约翰一书','约翰二书',
    '约翰三书','犹大书','启示录',
  ];
  static const Map<String, String> _abbrev = {
    '创世记':'创','出埃及记':'出','利未记':'利','民数记':'民','申命记':'申',
    '约书亚记':'书','士师记':'士','路得记':'得','撒母耳记上':'撒上','撒母耳记下':'撒下',
    '列王纪上':'王上','列王纪下':'王下','历代志上':'代上','历代志下':'代下',
    '以斯拉记':'拉','尼希米记':'尼','以斯帖记':'斯','约伯记':'伯',
    '诗篇':'诗','箴言':'箴','传道书':'传','雅歌':'歌',
    '以赛亚书':'赛','耶利米书':'耶','耶利米哀歌':'哀','以西结书':'结',
    '但以理书':'但','何西阿书':'何','约珥书':'珥','阿摩司书':'摩',
    '俄巴底亚书':'俄','约拿书':'拿','弥迦书':'弥','那鸿书':'鸿',
    '哈巴谷书':'哈','西番雅书':'番','哈该书':'该','撒迦利亚书':'亚','玛拉基书':'玛',
    '马太福音':'太','马可福音':'可','路加福音':'路','约翰福音':'约',
    '使徒行传':'徒','罗马书':'罗','哥林多前书':'林前','哥林多后书':'林后',
    '加拉太书':'加','以弗所书':'弗','腓立比书':'腓','歌罗西书':'西',
    '帖撒罗尼迦前书':'帖前','帖撒罗尼迦后书':'帖后',
    '提摩太前书':'提前','提摩太后书':'提后','提多书':'多','腓利门书':'门',
    '希伯来书':'来','雅各书':'雅','彼得前书':'彼前','彼得后书':'彼后',
    '约翰一书':'约壹','约翰二书':'约贰','约翰三书':'约叁','犹大书':'犹','启示录':'启',
  };

  // 每次 build 直接从 widget.chapters 计算，不存状态
  Map<String, List<ScriptureChapter>> _buildBookMap() {
    final map = <String, List<ScriptureChapter>>{};
    for (final ch in widget.chapters) {
      final book = ch.title.contains(' ') ? ch.title.split(' ').first : ch.title;
      map.putIfAbsent(book, () => []).add(ch);
    }
    return map;
  }

  String _progressBook(Map<String, List<ScriptureChapter>> bm) {
    final lastId = widget.scripture.lastChapterId;
    if (lastId == null) return '';
    for (final entry in bm.entries) {
      if (entry.value.any((c) => c.id == lastId)) return entry.key;
    }
    return '';
  }

  int _localNum(ScriptureChapter ch) {
    final m = RegExp(r'第(\d+)章').firstMatch(ch.title);
    return m != null ? int.parse(m.group(1)!) : 0;
  }

  void _openCh(ScriptureChapter ch) {
    final idx = widget.chapters.indexWhere((c) => c.id == ch.id);
    if (idx >= 0) widget.onOpen(idx);
  }

  @override
  Widget build(BuildContext context) {
    final bm = _buildBookMap();
    final progBook = _progressBook(bm);
    // 默认选中：有进度→进度书，否则取第一本可用书
    final fallback = progBook.isNotEmpty
        ? progBook
        : [..._otBooks, ..._ntBooks]
            .firstWhere((b) => bm.containsKey(b), orElse: () => '');
    final activeBook = _viewBook ?? fallback;
    final activeChapters = bm[activeBook] ?? [];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _SegmentedControl(
          left: AppLocalizations.of(context).books,
          right: AppLocalizations.of(context).chapters,
          leftSelected: _isBookView,
          onLeft: () => setState(() => _isBookView = true),
          onRight: () => setState(() => _isBookView = false),
        ),
        centerTitle: true,
        actions: [
          ScriptureDownloadButton(
            scriptureId: widget.scripture.id,
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              final hasProgress = widget.scripture.progressPercent != null &&
                  widget.scripture.progressPercent! > 0;
              showPremiumActionSheet(
                context,
                actions: [
                  PremiumAction(
                    icon: hasProgress
                        ? Icons.play_arrow_rounded
                        : Icons.menu_book_rounded,
                    label: hasProgress ? AppLocalizations.of(context).continueReading : AppLocalizations.of(context).startReading,
                    onTap: () {
                      Navigator.pop(context);
                      final lastIdx = widget.chapters.indexWhere(
                          (c) => c.id == widget.scripture.lastChapterId);
                      widget.onOpen(lastIdx >= 0 ? lastIdx : 0);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: widget.loading && widget.chapters.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _isBookView
              ? _buildBookView(bm, progBook)
              : _buildChapterView(activeBook, activeChapters),
      bottomNavigationBar: _buildStatusBar(activeBook, activeChapters),
    );
  }

  // ── 书卷 grid ─────────────────────────────────────────────────

  Widget _buildBookView(
      Map<String, List<ScriptureChapter>> bm, String progBook) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            label: AppLocalizations.of(context).oldTestament,
            count: _otBooks.where((b) => bm.containsKey(b)).length,
            expanded: _otExpanded,
            onTap: () => setState(() => _otExpanded = !_otExpanded),
          ),
          if (_otExpanded)
            _buildBookGrid(
                _otBooks.where((b) => bm.containsKey(b)).toList(), bm, progBook),
          _SectionHeader(
            label: AppLocalizations.of(context).newTestament,
            count: _ntBooks.where((b) => bm.containsKey(b)).length,
            expanded: _ntExpanded,
            onTap: () => setState(() => _ntExpanded = !_ntExpanded),
          ),
          if (_ntExpanded)
            _buildBookGrid(
                _ntBooks.where((b) => bm.containsKey(b)).toList(), bm, progBook),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBookGrid(List<String> books,
      Map<String, List<ScriptureChapter>> bm, String progBook) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 0.85,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) {
          final name = books[i];
          final isCurrent = name == progBook;
          final isZh = LocaleController.instance.bibleLang.startsWith('zh');
          final t = AppLocalizations.of(context);
          final localName = isZh ? name : localizedBibleBook(t, name);
          final abbr = isZh ? (_abbrev[name] ?? name.substring(0, 1)) : localName;
          final shortLabel = isZh ? _shortName(name) : '';
          return GestureDetector(
            onTap: () => setState(() {
              _viewBook = name;
              _isBookView = false;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: isCurrent ? _selected : _bg,
                border: Border.all(
                    color: const Color(0xFFDDDDD0), width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        abbr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Colors.white
                              : const Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shortLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: isCurrent
                          ? Colors.white.withAlpha(220)
                          : const Color(0xFF777777),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _shortName(String name) {
    if (name.length <= 4) return name;
    // 截短：去掉"书"、"记"、"福音" 等后缀
    final s = name
        .replaceAll('福音', '')
        .replaceAll('书', '')
        .replaceAll('记', '');
    return s.length <= 4 ? s : '${s.substring(0, 3)}…';
  }

  // ── 章 grid ───────────────────────────────────────────────────

  Widget _buildChapterView(
      String bookName, List<ScriptureChapter> chapters) {
    if (bookName.isEmpty || chapters.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).selectBookFirst,
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    final lastId = widget.scripture.lastChapterId;
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final ch = chapters[i];
        final isCurrent = ch.id == lastId;
        final num = _localNum(ch);
        return GestureDetector(
          onTap: () => _openCh(ch),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrent ? _selected : _bg,
              border: Border.all(
                  color: const Color(0xFFDDDDD0), width: 0.5),
            ),
            child: Center(
              child: Text(
                '$num',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Colors.white
                      : const Color(0xFF333333),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 底部状态栏 ────────────────────────────────────────────────

  Widget _buildStatusBar(
      String bookName, List<ScriptureChapter> chapters) {
    String display;
    if (_isBookView) {
      display = widget.scripture.displayTitle;
    } else {
      final lastId = widget.scripture.lastChapterId;
      int currentNum = 1;
      if (bookName.isNotEmpty && chapters.isNotEmpty) {
        final ch = lastId != null
            ? chapters.firstWhere((c) => c.id == lastId,
                orElse: () => chapters.first)
            : chapters.first;
        currentNum = _localNum(ch);
      }
      display = bookName.isNotEmpty ? AppLocalizations.of(context).bookChapterDisplay(bookName, currentNum) : widget.scripture.displayTitle;
    }
    return Container(
      height: 44,
      color: _accent,
      alignment: Alignment.center,
      child: Text(
        display,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── 辅助：段落控件 ────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _SegmentedControl({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(label: left, selected: leftSelected, onTap: onLeft),
          _Seg(label: right, selected: !leftSelected, onTap: onRight),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: selected ? const Color(0xFF9575CD) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFFEDE7F6),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              color: const Color(0xFF9575CD),
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9575CD),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).volumeCount(count),
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFAA88CC)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 道德经：宫格 ──────────────────────────────────────────────────
class _DaoDeJingContents extends StatelessWidget {
  final List<ScriptureChapter> chapters;
  final Color color;
  final void Function(int) onTap;

  const _DaoDeJingContents(
      {required this.chapters, required this.color, required this.onTap});

  static const _nums = [
    '一','二','三','四','五','六','七','八','九','十',
    '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
    '廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十',
    '卅一','卅二','卅三','卅四','卅五','卅六','卅七','卅八','卅九','四十',
    '四一','四二','四三','四四','四五','四六','四七','四八','四九','五十',
    '五一','五二','五三','五四','五五','五六','五七','五八','五九','六十',
    '六一','六二','六三','六四','六五','六六','六七','六八','六九','七十',
    '七一','七二','七三','七四','七五','七六','七七','七八','七九','八十',
    '八一',
  ];

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.15,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final ch = chapters[i];
            final label = i < _nums.length ? _nums[i] : '${i + 1}';
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                decoration: BoxDecoration(
                  color: ch.isBookmarked ? color : color.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: color.withAlpha(50), width: 0.5),
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: ch.isBookmarked ? Colors.white : color,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            );
          },
          childCount: chapters.length,
        ),
      ),
    );
  }
}

// ── 金刚经等：清单 ────────────────────────────────────────────────
class _DefaultContents extends StatelessWidget {
  final List<ScriptureChapter> chapters;
  final Color color;
  final void Function(int) onTap;

  const _DefaultContents(
      {required this.chapters, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang =
        LocaleController.instance.bibleLang == 'zh_Hant' ? 'zh_Hant' : 'zh';
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final ch = chapters[i];
          return InkWell(
            onTap: () => onTap(i),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          ch.isBookmarked ? color : color.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: ch.isBookmarked
                          ? const Icon(Icons.bookmark,
                              size: 14, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(ch.localizedTitle(lang),
                          style: const TextStyle(fontSize: 15))),
                  if (ch.isHighlighted)
                    Icon(Icons.highlight, size: 14, color: color),
                  Icon(Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(80)),
                ],
              ),
            ),
          );
        },
        childCount: chapters.length,
      ),
    );
  }
}

/// 经书下载按钮：未下载→下载图标；下载中→进度圈；已下载→对勾
class ScriptureDownloadButton extends StatefulWidget {
  final String scriptureId;
  final Color color;
  const ScriptureDownloadButton({
    super.key,
    required this.scriptureId,
    this.color = Colors.white,
  });

  @override
  State<ScriptureDownloadButton> createState() =>
      _ScriptureDownloadButtonState();
}

class _ScriptureDownloadButtonState extends State<ScriptureDownloadButton> {
  final _svc = ScriptureDownloadService.instance;
  bool _downloaded = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final d = await _svc.isDownloaded(widget.scriptureId);
    if (mounted) setState(() => _downloaded = d);
  }

  Future<void> _start() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final t = AppLocalizations.of(context);
    try {
      await _svc.download(
        widget.scriptureId,
        onProgress: (done, total) {
          if (mounted && total > 0) {
            setState(() => _progress = done / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _downloaded = true;
          _downloading = false;
        });
        showPremiumToast(context, t.downloadComplete, kind: ToastKind.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        showErrorIfNotNetwork(context, e, t.downloadFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: _progress == 0 ? null : _progress,
              color: widget.color,
              backgroundColor: widget.color.withAlpha(60),
            ),
          ),
        ),
      );
    }
    if (_downloaded) {
      return IconButton(
        icon: Icon(Icons.download_done_rounded, color: widget.color),
        tooltip: AppLocalizations.of(context).downloadedOffline,
        onPressed: () => showPremiumToast(
            context, AppLocalizations.of(context).downloadedOffline,
            kind: ToastKind.info),
      );
    }
    return IconButton(
      icon: Icon(Icons.download_rounded, color: widget.color),
      tooltip: AppLocalizations.of(context).downloadForOffline,
      onPressed: _start,
    );
  }
}
