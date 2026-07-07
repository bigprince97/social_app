import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'models/conversation.dart';
import 'services/chat_service.dart';
import 'models/scripture.dart';
import 'services/scripture_service.dart';
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
import 'screens/scripture/scripture_search_screen.dart';
import 'screens/search_screen.dart';

// go_router 在路由栈重建时会丢失底层路由的 extra（变 null）。
// 阅读器依赖 extra 里的章节/全卷数据，丢失后硬转型会崩溃灰屏。
// 用首次导航时缓存的 extra 兜底，保证重建时复用。
final Map<String, Map<String, dynamic>> _readerExtraCache = {};

// 按 id 保留最近几条（LRU），既避免长会话缓存上千章全卷数据导致内存增长，
// 也避免栈里同时有多条阅读器路由时互相清掉对方的缓存、重建落入死分支。
const int _readerExtraCacheCap = 3;

void _cacheReaderExtra(String id, Map<String, dynamic> extra) {
  _readerExtraCache
    ..remove(id)
    ..[id] = extra;
  while (_readerExtraCache.length > _readerExtraCacheCap) {
    _readerExtraCache.remove(_readerExtraCache.keys.first);
  }
}

final router = GoRouter(
  initialLocation: '/login',
  redirect: (_, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final onAuth =
        state.matchedLocation == '/login' ||
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
      builder: (ctx, s) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (ctx, s) => VerifyEmailScreen(email: (s.extra as String?) ?? ''),
    ),
    GoRoute(path: '/', builder: (ctx, s) => const HomeScreen()),
    GoRoute(
      path: '/post/:id',
      builder: (_, state) =>
          PostDetailScreen(postId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/profile/:id',
      builder: (_, state) => ProfileScreen(userId: state.pathParameters['id']!),
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
    GoRoute(path: '/search', builder: (ctx, s) => const SearchScreen()),
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
      builder: (_, state) =>
          ScriptureListScreen(category: state.pathParameters['category']!),
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
        return ScriptureDetailScreen(scriptureId: state.pathParameters['id']!);
      },
    ),
    GoRoute(
      path: '/scripture/search/:id',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic> && extra['scripture'] is Scripture) {
          return ScriptureSearchScreen(
            scripture: extra['scripture'] as Scripture,
            chapters:
                (extra['chapters'] as List<ScriptureChapter>?) ?? const [],
          );
        }
        if (extra is Scripture) {
          return ScriptureSearchScreen(scripture: extra);
        }
        return ScriptureSearchScreen(scriptureId: state.pathParameters['id']!);
      },
    ),
    GoRoute(
      path: '/scripture/read/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        // 重建时 extra 可能为 null，回退到首次缓存，避免崩溃灰屏。
        final extra =
            (state.extra as Map<String, dynamic>?) ?? _readerExtraCache[id];
        if (extra == null) {
          // 进程重启/深链直达时 extra 与缓存都为空，
          // 参照 _ConvLoader 按章节 id 兜底加载，不能停在永久转圈。
          return _ChapterLoader(chapterId: id);
        }
        _cacheReaderExtra(id, extra);
        return ChapterReaderScreen(
          chapter: extra['chapter'] as ScriptureChapter,
          scripture: extra['scripture'] as Scripture,
          allChapters: extra['allChapters'] as List<ScriptureChapter>,
          initialIndex: extra['initialIndex'] as int,
          initialVerse: extra['initialVerse'] as int?,
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

// 阅读器路由的兜底加载：进程重启/深链直达时 extra 丢失且缓存未命中，
// 按章节 id 重新拉取书卷与全卷章节后内联渲染 ChapterReaderScreen（同 _ConvLoader）。
// 失败给出错误提示 + 重试，加载/失败态都带返回入口，保证返回路径永远可用。
class _ChapterLoader extends StatefulWidget {
  final String chapterId;
  const _ChapterLoader({required this.chapterId});

  @override
  State<_ChapterLoader> createState() => _ChapterLoaderState();
}

class _ChapterLoaderState extends State<_ChapterLoader> {
  Map<String, dynamic>? _extra;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = ScriptureService();
      // 单章数据里带 scripture_id：先取章，再并发取书卷信息与全卷章节列表
      final chapter = await service.getChapterContent(widget.chapterId);
      final results = await Future.wait([
        service.getScriptureById(chapter.scriptureId),
        service.getChapters(chapter.scriptureId),
      ]);
      final scripture = results[0] as Scripture;
      final allChapters = results[1] as List<ScriptureChapter>;
      final idx = allChapters.indexWhere((c) => c.id == chapter.id);
      final extra = <String, dynamic>{
        'chapter': chapter,
        'scripture': scripture,
        // 缓存章节表里找不到当前章(缓存过期)时退化为单章,避免
        // 进度/翻页按错误的列表计算
        'allChapters': (allChapters.isEmpty || idx < 0)
            ? [chapter]
            : allChapters,
        'initialIndex': idx < 0 ? 0 : idx,
        'initialVerse': null,
      };
      // 注意:不要把 extra 写回 _readerExtraCache——builder 重跑命中缓存后
      // 会把路由顶层从 _ChapterLoader 换成 ChapterReaderScreen,整棵子树
      // remount(阅读位置丢失、选章 pop 回调落在已 dispose 的 State 上)。
      // State 自身持有 _extra,Element 复用即可,无需缓存兜底。
      if (mounted) setState(() => _extra = extra);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    _load();
  }

  // 深链直达时本路由可能是栈里唯一一条，AppBar 自动 leading 不会出现，
  // 显式提供返回：能 pop 就 pop，否则回首页。
  AppBar _buildBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = _extra;
    if (extra != null) {
      return ChapterReaderScreen(
        chapter: extra['chapter'] as ScriptureChapter,
        scripture: extra['scripture'] as Scripture,
        allChapters: extra['allChapters'] as List<ScriptureChapter>,
        initialIndex: extra['initialIndex'] as int,
        initialVerse: extra['initialVerse'] as int?,
      );
    }
    if (_failed) {
      return Scaffold(
        appBar: _buildBar(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).loadFailed('请稍后重试')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: _buildBar(context),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}
