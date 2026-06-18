import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/scripture.dart';
import '../../services/scripture_service.dart';
import '../../utils/bible_books.dart';
import '../../l10n/app_localizations.dart';

class ScriptureHomeScreen extends StatefulWidget {
  const ScriptureHomeScreen({super.key});

  @override
  State<ScriptureHomeScreen> createState() => _ScriptureHomeScreenState();
}

class _ScriptureHomeScreenState extends State<ScriptureHomeScreen> {
  final _service = ScriptureService();
  List<Scripture> _scriptures = [];
  Scripture? _recentScripture;
  String? _recentChapterTitle;
  bool _loading = true;

  // 固定展示顺序（圣经优先）
  static const _displayOrder = ['圣经', '道德经', '金刚经'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final all = await _service.getAllScriptures();

      // 按指定顺序排列
      all.sort((a, b) {
        final ia = _displayOrder.indexOf(a.title);
        final ib = _displayOrder.indexOf(b.title);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });

      // 先把经书列表显示出来（命中缓存即可），
      // 避免下面“上次阅读”请求离线失败连累整个列表为空。
      if (mounted) setState(() => _scriptures = all);

      Scripture? recent;
      String? recentChapterTitle;
      if (uid != null) {
        try {
        final data = await Supabase.instance.client
            .from('reading_progress')
            .select('scripture_id, scriptures(*), progress_percent, chapter_id')
            .eq('user_id', uid)
            .order('updated_at', ascending: false)
            .limit(1);
        if ((data as List).isNotEmpty) {
          final row = data.first;
          final s = Scripture.fromJson(
            row['scriptures'] as Map<String, dynamic>,
          );
          s.progressPercent = (row['progress_percent'] as int?) ?? 0;
          s.lastChapterId = row['chapter_id'] as String?;
          recent = s;
          if (s.lastChapterId != null) {
            final ch = await Supabase.instance.client
                .from('scripture_chapters')
                .select('title')
                .eq('id', s.lastChapterId!)
                .maybeSingle();
            if (ch != null) {
              recentChapterTitle = ch['title'] as String?;
            }
          }
        }
        } catch (_) {/* 离线时“上次阅读”取不到，忽略，不影响经书列表 */}
      }

      if (mounted) {
        setState(() {
          _scriptures = all;
          _recentScripture = recent;
          _recentChapterTitle = recentChapterTitle;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scripture),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            onPressed: () => context.push('/scripture/bookmarks'),
            tooltip: AppLocalizations.of(context).myBookmarks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_recentScripture != null) ...[
                  _sectionTitle(AppLocalizations.of(context).lastReading),
                  const SizedBox(height: 12),
                  _RecentBanner(
                    scripture: _recentScripture!,
                    chapterTitle: _recentChapterTitle,
                  ),
                  const SizedBox(height: 24),
                ],
                _sectionTitle(AppLocalizations.of(context).allScriptures),
                const SizedBox(height: 12),
                ..._scriptures.map((s) => _ScriptureCard(scripture: s)),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _RecentBanner extends StatelessWidget {
  final Scripture scripture;
  final String? chapterTitle;
  const _RecentBanner({required this.scripture, this.chapterTitle});

  String _shortChapterTitle(String title) {
    // 截短章节标题：优先显示书名+章节号
    final m = RegExp(r'^(.+?)\s+(第\d+章)').firstMatch(title);
    if (m != null) return '${m.group(1)} ${m.group(2)}';
    if (title.length > 16) return '${title.substring(0, 15)}…';
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (scripture.progressPercent ?? 0) / 100;
    final dispTitle = scripture.displayTitle;
    final shortTitle = dispTitle.length > 2 ? dispTitle.substring(0, 2) : dispTitle;

    return GestureDetector(
      onTap: () => context.push(
        '/scripture/detail/${scripture.id}',
        extra: {'scripture': scripture, 'autoStart': true},
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scripture.color,
              scripture.color.withAlpha(200),
              scripture.color.withAlpha(160),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scripture.color.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative circle
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Book cover
                  Container(
                    width: 56,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        shortTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dispTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        if (chapterTitle != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.bookmark_rounded,
                                size: 12,
                                color: Colors.white.withAlpha(200),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _shortChapterTitle(chapterTitle!),
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(210),
                                    fontSize: 12.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withAlpha(50),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).readPercent(scripture.progressPercent ?? 0),
                          style: TextStyle(
                            color: Colors.white.withAlpha(190),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Continue button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(80),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppLocalizations.of(context).continueLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScriptureCard extends StatelessWidget {
  final Scripture scripture;
  const _ScriptureCard({required this.scripture});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(8),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 16),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            context.push('/scripture/detail/${scripture.id}', extra: scripture),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scripture.color, scripture.color.withAlpha(200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: scripture.color.withAlpha(80),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    scripture.displayTitle.length > 2
                        ? scripture.displayTitle.substring(0, 2)
                        : scripture.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          scripture.displayTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scripture.color.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            localizedScriptureCategory(
                              AppLocalizations.of(context),
                              scripture.category,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: scripture.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (scripture.author != null || scripture.dynasty != null)
                      Text(
                        [
                          if (scripture.displayDynasty != null)
                            scripture.displayDynasty!,
                          if (scripture.displayAuthor != null)
                            scripture.displayAuthor!,
                        ].join(' · '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scripture.color),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 14,
                          color: scripture.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).chaptersCountLabel(scripture.chaptersCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: scripture.color,
                          ),
                        ),
                        if ((scripture.progressPercent ?? 0) > 0) ...[
                          const Spacer(),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).readPercent(scripture.progressPercent ?? 0),
                            style: TextStyle(
                              fontSize: 11,
                              color: scripture.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (scripture.progressPercent ?? 0) / 100,
                                backgroundColor: scripture.color.withAlpha(40),
                                valueColor: AlwaysStoppedAnimation(
                                  scripture.color,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
