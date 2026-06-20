import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/conversation.dart';
import 'services/chat_service.dart';
import 'models/scripture.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/feed/post_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/settings/language_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/scripture/bookmarks_screen.dart';
import 'screens/scripture/chapter_reader_screen.dart';
import 'screens/scripture/scripture_detail_screen.dart';
import 'screens/scripture/scripture_list_screen.dart';
import 'screens/search_screen.dart';

// go_router 在路由栈重建时会丢失底层路由的 extra（变 null）。
// 阅读器依赖 extra 里的章节/全卷数据，丢失后硬转型会崩溃灰屏。
// 用首次导航时缓存的 extra 兜底，保证重建时复用。
final Map<String, Map<String, dynamic>> _readerExtraCache = {};

final router = GoRouter(
  initialLocation: '/login',
  redirect: (_, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final onAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/verify-email';
    if (session == null && !onAuth) return '/login';
    if (session != null && onAuth) return '/';
    return null;
  },
  refreshListenable: _AuthChangeNotifier(),
  routes: [
    GoRoute(path: '/login', builder: (ctx, s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (ctx, s) => const RegisterScreen()),
    GoRoute(
        path: '/forgot-password',
        builder: (ctx, s) => const ForgotPasswordScreen()),
    GoRoute(
        path: '/verify-email',
        builder: (ctx, s) =>
            VerifyEmailScreen(email: (s.extra as String?) ?? '')),
    GoRoute(path: '/', builder: (ctx, s) => const HomeScreen()),
    GoRoute(
      path: '/post/:id',
      builder: (_, state) =>
          PostDetailScreen(postId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/profile/:id',
      builder: (_, state) =>
          ProfileScreen(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (_, state) {
        final conv = state.extra;
        if (conv is Conversation) return ChatScreen(conversation: conv);
        // extra lost on app restore — load conversation by id
        return _ConvLoader(conversationId: state.pathParameters['id']!);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (ctx, s) => const SearchScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (ctx, s) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (ctx, s) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/scripture/list/:category',
      builder: (_, state) => ScriptureListScreen(
        category: state.pathParameters['category']!,
      ),
    ),
    GoRoute(
      path: '/scripture/detail/:id',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic> && extra['scripture'] is Scripture) {
          return ScriptureDetailScreen(
            scripture: extra['scripture'] as Scripture,
            autoStart: extra['autoStart'] == true,
            initialBook: extra['book'] as String?,
            initialChapterView: extra['chapterView'] == true,
          );
        }
        if (extra is Scripture) {
          return ScriptureDetailScreen(scripture: extra);
        }
        return ScriptureDetailScreen(
            scriptureId: state.pathParameters['id']!);
      },
    ),
    GoRoute(
      path: '/scripture/read/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        // 重建时 extra 可能为 null，回退到首次缓存，避免崩溃灰屏。
        final extra = (state.extra as Map<String, dynamic>?) ??
            _readerExtraCache[id];
        if (extra == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // 只保留当前章节这一条，避免长会话里缓存上千章的全卷数据导致内存增长
        _readerExtraCache
          ..clear()
          ..[id] = extra;
        return ChapterReaderScreen(
          chapter: extra['chapter'] as ScriptureChapter,
          scripture: extra['scripture'] as Scripture,
          allChapters: extra['allChapters'] as List<ScriptureChapter>,
          initialIndex: extra['initialIndex'] as int,
        );
      },
    ),
    GoRoute(
      path: '/scripture/bookmarks',
      builder: (ctx, s) => const BookmarksScreen(),
    ),
  ],
);

// Loads a conversation by ID when GoRouter extra is lost (app restore)
class _ConvLoader extends StatefulWidget {
  final String conversationId;
  const _ConvLoader({required this.conversationId});

  @override
  State<_ConvLoader> createState() => _ConvLoaderState();
}

class _ConvLoaderState extends State<_ConvLoader> {
  Conversation? _conv;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final convs = await ChatService().getConversations();
      final conv = convs.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw Exception('not found'),
      );
      if (mounted) setState(() => _conv = conv);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // 直接内联渲染 ChatScreen，不再用 Navigator.pushReplacement 把页面推到
  // GoRouter 之外的原生栈——那样两套导航栈会错乱，返回时出现白屏。
  @override
  Widget build(BuildContext context) {
    if (_conv != null) return ChatScreen(conversation: _conv!);
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Icon(Icons.error_outline, size: 48, color: Colors.grey),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}
