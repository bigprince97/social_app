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
import 'services/locale_controller.dart';
import 'services/push_notification_service.dart';

const _kPrimary = Color(0xFF9575CD);   // app purple
const _kPrimaryDark = Color(0xFFB39DDB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase push notifications are not supported on web
  if (!kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await Supabase.initialize(
      url: supabaseUrl, publishableKey: supabasePublishableKey);

  timeago.setLocaleMessages('zh', timeago.ZhMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  await LocaleController.instance.load();

  runApp(const SocialApp());
}

class SocialApp extends StatefulWidget {
  const SocialApp({super.key});

  @override
  State<SocialApp> createState() => _SocialAppState();
}

class _SocialAppState extends State<SocialApp> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // signedIn = 刚登录；initialSession = 冷启动恢复已有登录态。
      // 两者都要初始化推送，否则冷启动后通知点击回调未注册。
      final signedIn = data.event == AuthChangeEvent.signedIn ||
          (data.event == AuthChangeEvent.initialSession &&
              data.session != null);
      if (!kIsWeb && signedIn) {
        PushNotificationService.initialize(
          onNotificationTap: (postId, actorId, type, conversationId) {
            final ctx = router.routerDelegate.navigatorKey.currentContext;
            if (ctx == null) return;
            if (type == 'chat' && conversationId != null) {
              ctx.push('/chat/$conversationId');
            } else if (postId != null && postId.isNotEmpty) {
              ctx.push('/post/$postId');
            } else if (type == 'follow' &&
                actorId != null &&
                actorId.isNotEmpty) {
              ctx.push('/profile/$actorId');
            }
          },
        );
      } else if (!kIsWeb && data.event == AuthChangeEvent.signedOut) {
        PushNotificationService.deleteToken();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          title: '教会社群',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supported,
          locale: locale,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          routerConfig: router,
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // Instagram/Telegram color palette
  final scaffoldBg = isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7);
  final surfaceBg  = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  final fillColor  = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F5);

  return ThemeData(
    textTheme: GoogleFonts.notoSansScTextTheme(ThemeData(brightness: brightness).textTheme),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
        borderSide: BorderSide(color: isDark ? _kPrimaryDark : _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
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
    listTileTheme: ListTileThemeData(
      tileColor: surfaceBg,
    ),

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
