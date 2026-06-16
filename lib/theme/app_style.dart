import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// 全 app「高级风格」设计令牌 + 可复用组件。
/// 详见 memory: project_premium_menu_style。
class AppStyle {
  AppStyle._();

  // ── 品牌色 ──────────────────────────────────────────────
  static const brand = Color(0xFF9575CD);
  static const brandDark = Color(0xFFB39DDB);
  static const brandDeep = Color(0xFF7B5EA7);

  // ── iOS 系统色板 ────────────────────────────────────────
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const purple = Color(0xFFAF52DE);
  static const teal = Color(0xFF5AC8FA);
  static const pink = Color(0xFFFF2D92);

  // ── 圆角 ────────────────────────────────────────────────
  static const rSm = 12.0;
  static const rMd = 18.0;
  static const rLg = 24.0;
  static const rXl = 28.0;

  // ── 渐变 ────────────────────────────────────────────────
  static const brandGradient = LinearGradient(
    colors: [brandDeep, brand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient gradientOf(Color c) => LinearGradient(
    colors: [c, c.withAlpha(205)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── 面板色（毛玻璃）────────────────────────────────────
  static Color panel(bool isDark) => isDark
      ? const Color(0xFF1C1C1E).withAlpha(220)
      : Colors.white.withAlpha(235);

  static Color cardColor(bool isDark) =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;

  static Color hairline(bool isDark) =>
      isDark ? Colors.white.withAlpha(18) : Colors.white.withAlpha(160);

  // ── 阴影 ────────────────────────────────────────────────
  static List<BoxShadow> softShadow(bool isDark, {double blur = 18}) => [
    BoxShadow(
      color: Colors.black.withAlpha(isDark ? 70 : 18),
      blurRadius: blur,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> floatingShadow(bool isDark) => [
    BoxShadow(
      color: Colors.black.withAlpha(isDark ? 90 : 28),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  /// 柔和色调瓷砖图标背景装饰（_AttachItem 风格）
  static BoxDecoration tintTile(
    Color color,
    bool isDark, {
    double radius = 13,
  }) => BoxDecoration(
    color: color.withAlpha(isDark ? 46 : 30),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color.withAlpha(isDark ? 60 : 40), width: 0.8),
  );
}

/// 浮动圆角玻璃卡片，全 app 列表项/分组统一使用。
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;
  final Color? color;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.radius = AppStyle.rLg,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              color: gradient == null
                  ? (color ?? AppStyle.cardColor(isDark))
                  : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(8),
                width: 0.6,
              ),
              boxShadow: AppStyle.softShadow(isDark),
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 高级风格空状态：柔和瓷砖图标 + 标题 + 副标题。
class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? action;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppStyle.brand;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: AppStyle.tintTile(c, isDark, radius: 26),
              child: Icon(icon, size: 38, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// 渐变品牌按钮（发布/确认/主操作）。
class PremiumButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;
  final bool expand;
  final bool loading;

  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.destructive = false,
    this.expand = false,
    this.loading = false,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.destructive
        ? AppStyle.gradientOf(AppStyle.red)
        : AppStyle.brandGradient;
    final accent = widget.destructive ? AppStyle.red : AppStyle.brand;
    final enabled = widget.onTap != null && !widget.loading;

    final content = Container(
      height: 50,
      width: widget.expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        color: enabled ? null : Colors.grey.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accent.withAlpha(90),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: widget.loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: content,
      ),
    );
  }
}

/// 高级风格确认对话框（替代 AlertDialog）。返回 true=确认。
Future<bool> showPremiumConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
  IconData? icon,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = destructive ? AppStyle.red : AppStyle.brand;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierLabel: title,
    barrierDismissible: true,
    barrierColor: Colors.black.withAlpha(90),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppStyle.rXl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppStyle.panel(isDark),
                        borderRadius: BorderRadius.circular(AppStyle.rXl),
                        border: Border.all(
                          color: AppStyle.hairline(isDark),
                          width: 0.8,
                        ),
                        boxShadow: AppStyle.floatingShadow(isDark),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Container(
                                width: 60,
                                height: 60,
                                decoration: AppStyle.tintTile(
                                  accent,
                                  isDark,
                                  radius: 19,
                                ),
                                child: Icon(icon, color: accent, size: 30),
                              ),
                              const SizedBox(height: 18),
                            ],
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (message != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _DialogBtn(
                                    label: cancelLabel,
                                    onTap: () => Navigator.pop(ctx, false),
                                    isDark: isDark,
                                    filled: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DialogBtn(
                                    label: confirmLabel,
                                    onTap: () => Navigator.pop(ctx, true),
                                    isDark: isDark,
                                    filled: true,
                                    accent: accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool filled;
  final Color? accent;

  const _DialogBtn({
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.filled,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled
              ? AppStyle.gradientOf(accent ?? AppStyle.brand)
              : null,
          color: filled
              ? null
              : (isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(10)),
          borderRadius: BorderRadius.circular(15),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: (accent ?? AppStyle.brand).withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: filled
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
