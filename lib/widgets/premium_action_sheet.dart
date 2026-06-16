import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// 一条动作项
class PremiumAction {
  final IconData icon;
  final String label;
  final String? subtitle;

  /// 图标主色；不传则用品牌紫
  final Color? color;

  /// 危险/破坏性动作（拉黑、删除、退出等）→ 红色
  final bool destructive;
  final VoidCallback onTap;

  const PremiumAction({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color,
    this.destructive = false,
    required this.onTap,
  });
}

const _kBrand = Color(0xFF9575CD);
const _kDanger = Color(0xFFFF453A);

/// 高级风格底部动作面板：毛玻璃浮动卡片 + 滑入动画 + 柔和瓷砖图标。
/// 全 app 统一使用，详见 memory: project_premium_menu_style。
Future<T?> showPremiumActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<PremiumAction> actions,
  bool showCancel = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final panelColor = isDark
      ? const Color(0xFF1C1C1E).withAlpha(220)
      : Colors.white.withAlpha(235);

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: title ?? '操作',
    barrierDismissible: true,
    barrierColor: Colors.black.withAlpha(60),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Align(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(curved),
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Panel(
                        isDark: isDark,
                        panelColor: panelColor,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  6,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final a in actions)
                                      _ActionRow(action: a, isDark: isDark),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showCancel) ...[
                        const SizedBox(height: 8),
                        _CancelButton(isDark: isDark, panelColor: panelColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Panel extends StatelessWidget {
  final bool isDark;
  final Color panelColor;
  final Widget child;
  const _Panel({
    required this.isDark,
    required this.panelColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : Colors.white.withAlpha(160),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 90 : 28),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final PremiumAction action;
  final bool isDark;
  const _ActionRow({required this.action, required this.isDark});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final color = a.destructive ? _kDanger : (a.color ?? _kBrand);
    final textColor = a.destructive
        ? _kDanger
        : (widget.isDark ? Colors.grey.shade100 : Colors.grey.shade900);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: a.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? (widget.isDark
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(widget.isDark ? 46 : 30),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: color.withAlpha(widget.isDark ? 60 : 40),
                    width: 0.8,
                  ),
                ),
                child: Icon(a.icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    if (a.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500,
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
    );
  }
}

class _CancelButton extends StatefulWidget {
  final bool isDark;
  final Color panelColor;
  const _CancelButton({required this.isDark, required this.panelColor});

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.pop(context),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.panelColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withAlpha(18)
                      : Colors.white.withAlpha(160),
                  width: 0.8,
                ),
              ),
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
