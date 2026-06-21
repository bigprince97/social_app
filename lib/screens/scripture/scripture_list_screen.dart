import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';
import '../../models/scripture.dart';
import '../../services/scripture_service.dart';

class ScriptureListScreen extends StatefulWidget {
  final String category;

  const ScriptureListScreen({super.key, required this.category});

  @override
  State<ScriptureListScreen> createState() => _ScriptureListScreenState();
}

class _ScriptureListScreenState extends State<ScriptureListScreen> {
  final _service = ScriptureService();
  List<Scripture> _scriptures = [];
  bool _loading = true;

  String get _categoryLabel {
    final cat = Scripture.categoryDefs.firstWhere(
      (c) => c['key'] == widget.category,
      orElse: () => {'label': widget.category},
    );
    return cat['label'] as String;
  }

  Color get _categoryColor {
    final cat = Scripture.categoryDefs.firstWhere(
      (c) => c['key'] == widget.category,
      orElse: () => {'color': 0xFF8B4513},
    );
    return Color(cat['color'] as int);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.getScripturesByCategory(widget.category);
      if (mounted) setState(() => _scriptures = list);
    } catch (e) {
      // 离线/网络错误不弹红色报错，仅静默（页面显示空状态）
      if (mounted && !isNetworkError(e)) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} · $_categoryLabel'),
        backgroundColor: _categoryColor.withAlpha(30),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scriptures.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: _categoryColor),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context).noScriptureContent),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scriptures.length,
                  itemBuilder: (context, i) =>
                      _ScriptureCard(scripture: _scriptures[i]),
                ),
    );
  }
}

class _ScriptureCard extends StatelessWidget {
  final Scripture scripture;

  const _ScriptureCard({required this.scripture});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/scripture/detail/${scripture.id}',
          extra: scripture,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: scripture.color,
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
                    Text(
                      scripture.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scripture.color,
                            ),
                      ),
                    if (scripture.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        scripture.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(150),
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 14, color: scripture.color),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context).chaptersCountLabel(scripture.chaptersCount),
                            style: TextStyle(
                                fontSize: 12, color: scripture.color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
            ],
          ),
        ),
      ),
    );
  }
}
