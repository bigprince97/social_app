import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      final all = await _service.getAllScriptures();

      // 按指定顺序排列
      all.sort((a, b) {
        final ia = _displayOrder.indexOf(a.title);
        final ib = _displayOrder.indexOf(b.title);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });

      // 先把经书列表显示出来（命中缓存即可），
      if (mounted) setState(() => _scriptures = all);

      if (mounted) {
        setState(() {
          _scriptures = all;
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
