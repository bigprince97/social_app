import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_style.dart';

enum ToastKind { success, error, info, block }

/// 高级提示：毛玻璃浮层 + 柔和图标徽标 + 圆角阴影，顶部滑入。
/// 替代朴素 SnackBar，用于全 App 的操作反馈。
void showPremiumToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  IconData? icon,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final (Color accent, IconData defIcon) = switch (kind) {
    ToastKind.success => (AppStyle.green, Icons.check_circle_rounded),
    ToastKind.error => (AppStyle.red, Icons.error_rounded),
    ToastKind.block => (AppStyle.orange, Icons.block_rounded),
    ToastKind.info => (AppStyle.brand, Icons.info_rounded),
  };

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _PremiumToastWidget(
      message: message,
      accent: accent,
      icon: icon ?? defIcon,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _PremiumToastWidget extends StatefulWidget {
  final String message;
  final Color accent;
  final IconData icon;
  final VoidCallback onDismissed;
  const _PremiumToastWidget({
    required this.message,
    required this.accent,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<_PremiumToastWidget> createState() => _PremiumToastWidgetState();
}

class _PremiumToastWidgetState extends State<_PremiumToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, child) => Opacity(
            opacity: _slide.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _slide.value) * -30),
              child: child,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withAlpha(isDark ? 200 : 230),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.accent.withAlpha(40),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 90 : 28),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: widget.accent.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, color: widget.accent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
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
    );
  }
}
