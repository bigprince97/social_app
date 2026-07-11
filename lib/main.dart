import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'config/firebase_options.dart';
import 'config/supabase_config.dart' show supabaseUrl, supabasePublishableKey;
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'services/active_conversation.dart';
import 'services/locale_controller.dart';
import 'services/local_cache.dart';
import 'services/message_sync_service.dart';
import 'services/bible_version_controller.dart';
import 'services/push_notification_service.dart';
import 'utils/timeout_http_client.dart';

const _kPrimary = Color(0xFF9575CD); // app purple
const _kPrimaryDark = Color(0xFFB39DDB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase push notifications are not supported on web。
  // 加超时兜底：网络/DNS 异常时初始化不能无限阻塞，否则永久卡在原生启动白屏。
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // 推送初始化失败不阻断启动（登录后 onAuthStateChange 会再次尝试注册推送）
    }
  }

  // Supabase.initialize 同步创建 client，await 主要等本地会话恢复；
  // 弱网下会话刷新可能拖慢，超时后照常进入 app（client 已可用，请求各自降级）。
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      // 所有请求 25s 兜底超时:弱网悬挂 → 异常 → 页面正常走错误路径,
      // 避免 loading 永不结束(见 utils/timeout_http_client.dart)
      httpClient: TimeoutHttpClient(),
    ).timeout(const Duration(seconds: 8));
  } catch (_) {}

  timeago.setLocaleMessages('zh', timeago.ZhCnMessages()); // 简体
  timeago.setLocaleMessages('zh_Hant', timeago.ZhMessages()); // 繁体
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  try {
    await LocaleController.instance.load().timeout(const Duration(seconds: 3));
  } catch (_) {}
  try {
    await BibleVersionController.instance.load().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {}

  runApp(const SocialApp());
}

class SocialApp extends StatefulWidget {
  const SocialApp({super.key});

  @override
  State<SocialApp> createState() => _SocialAppState();
}

class _SocialAppState extends State<SocialApp> {
  String? _pushRegistrationUserId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) PushNotificationService.syncAppIconBadge(0);
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // signedIn = 刚登录；initialSession = 冷启动恢复已有登录态。
      // 两者都要初始化推送，否则冷启动后通知点击回调未注册。
      final signedIn =
          data.event == AuthChangeEvent.signedIn ||
          (data.event == AuthChangeEvent.initialSession &&
              data.session != null);
      if (signedIn) {
        unawaited(MessageSyncService.instance.start());
        if (!kIsWeb) _registerPushNotifications();
      } else if (data.event == AuthChangeEvent.signedOut) {
        unawaited(_handleSignedOut());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(MessageSyncService.instance.start());
      if (!kIsWeb) _registerPushNotifications();
    });
  }

  Future<void> _handleSignedOut() async {
    // 先断开上一账号的私有消息频道，再清缓存，避免切换账号时串数据。
    await MessageSyncService.instance.stop();
    _pushRegistrationUserId = null;
    await LocalCache.instance.clear();
    if (!kIsWeb) {
      await PushNotificationService.syncAppIconBadge(0);
      await PushNotificationService.deleteToken();
    }
  }

  Future<void> _registerPushNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _pushRegistrationUserId == userId) return;
    _pushRegistrationUserId = userId;
    try {
      await PushNotificationService.initialize(
        onNotificationTap: (postId, actorId, type, conversationId) {
          final ctx = router.routerDelegate.navigatorKey.currentContext;
          if (ctx == null) return;
          if (type == 'chat' && conversationId != null) {
            // 已在该会话页则不再入栈:防止连点同会话的多条通知
            // 堆叠出多层相同页面(返回时像“刷新”,要点多次才退出)
            if (ActiveConversation.current != conversationId) {
              ctx.push('/chat/$conversationId');
            }
          } else if (postId != null && postId.isNotEmpty) {
            ctx.push('/post/$postId');
          } else if (type == 'follow' &&
              actorId != null &&
              actorId.isNotEmpty) {
            ctx.push('/profile/$actorId');
          }
        },
      );
    } catch (_) {
      _pushRegistrationUserId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          title: 'AlphaOmega',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supported,
          locale: locale,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            final requested = locale ?? deviceLocale;
            if (requested?.languageCode == 'zh' &&
                requested?.scriptCode == 'Hant') {
              return const Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hant',
              );
            }
            return const Locale('zh');
          },
          theme: _buildTheme(Brightness.light),
          // 去掉暗色模式：始终用浅色主题，不跟随系统
          themeMode: ThemeMode.light,
          routerConfig: router,
          // 全局键盘兜底：点击任何非交互区域收回键盘。
          // 交互控件（按钮/输入框/列表项）自己消费手势不受影响；
          // 一次性覆盖所有现有与将来的页面，避免逐页遗漏。
          builder: (context, child) {
            // 全局键盘兜底
            final content = GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () {
                final focus = FocusManager.instance.primaryFocus;
                if (focus != null && focus.context != null) focus.unfocus();
              },
              child: child,
            );
            // 非 Web 直接返回；Web 窄屏也全宽。
            if (!kIsWeb) return content;
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 600) return content;
                // Web 宽屏：把 App 居中约束成手机宽度（带阴影），
                // 避免移动端 UI 被拉伸到整屏。
                const frameWidth = 460.0;
                final media = MediaQuery.of(context);
                return ColoredBox(
                  color: const Color(0xFFEAE8F2),
                  child: Center(
                    child: SizedBox(
                      width: frameWidth,
                      height: constraints.maxHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: MediaQuery(
                          data: media.copyWith(
                            size: Size(frameWidth, constraints.maxHeight),
                          ),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // Instagram/Telegram color palette
  final scaffoldBg = isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7);
  final surfaceBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  final fillColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F5);

  return ThemeData(
    textTheme: GoogleFonts.notoSansScTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ),
    colorSchemeSeed: _kPrimary,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: scaffoldBg,

    // ── AppBar ────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: surfaceBg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.notoSansSc(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),

    // ── Card ─────────────────────────────────────────────────────────────
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // full-bleed Instagram style
      ),
    ),

    // ── Input ─────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? _kPrimaryDark : _kPrimary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
    ),

    // ── Bottom sheet ──────────────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: false,
      dragHandleColor: Colors.transparent,
      dragHandleSize: Size.zero,
      elevation: 0,
      backgroundColor: surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    // ── Navigation bar ────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      backgroundColor: surfaceBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: _kPrimary.withAlpha(30),
    ),

    // ── Chip ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ── Divider ───────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE),
      thickness: 0.5,
      space: 0,
    ),

    // ── ListTile ──────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(tileColor: surfaceBg),

    // ── Outlined button ───────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? _kPrimaryDark : _kPrimary,
        side: BorderSide(color: isDark ? _kPrimaryDark : _kPrimary, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 38),
      ),
    ),

    // ── Filled button ─────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? _kPrimaryDark : _kPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 42),
      ),
    ),
  );
}
