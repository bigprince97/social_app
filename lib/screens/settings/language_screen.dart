import 'package:flutter/material.dart';
import '../../services/locale_controller.dart';
import '../../theme/app_style.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  @override
  Widget build(BuildContext context) {
    final current = LocaleController.instance.locale.value;
    final currentKey =
        current == null ? null : LocaleController.keyOf(current);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('语言 / Language')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 暂时只显示简体/繁体，隐藏英语和日语
          for (final loc in LocaleController.supported.where((l) =>
              LocaleController.keyOf(l) != 'en' &&
              LocaleController.keyOf(l) != 'ja'))
            _LangTile(
              label: LocaleController.labels[LocaleController.keyOf(loc)] ??
                  LocaleController.keyOf(loc),
              selected: currentKey == LocaleController.keyOf(loc),
              isDark: isDark,
              onTap: () async {
                await LocaleController.instance.setLocale(loc);
                if (mounted) setState(() {});
              },
            ),
          const SizedBox(height: 8),
          _LangTile(
            label: '跟随系统 / System',
            selected: current == null,
            isDark: isDark,
            onTap: () async {
              await LocaleController.instance.setLocale(null);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _LangTile({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppStyle.brand
              : (isDark
                  ? Colors.white.withAlpha(12)
                  : Colors.black.withAlpha(10)),
          width: selected ? 1.5 : 0.6,
        ),
        boxShadow: AppStyle.softShadow(isDark, blur: 10),
      ),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppStyle.brand : null)),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppStyle.brand)
            : null,
        onTap: onTap,
      ),
    );
  }
}
