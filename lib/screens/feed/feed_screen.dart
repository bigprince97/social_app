import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../models/post.dart';
import '../../services/event_bus.dart';
import '../../services/post_service.dart';
import '../../utils/content_filter.dart';
import '../../widgets/premium_toast.dart';
import '../../services/storage_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/post_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_cache.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _postService = PostService();

  // Keys to call refresh() on each tab after posting
  final _followingKey = GlobalKey<_PostListState>();
  final _latestKey = GlobalKey<_PostListState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePostSheet({String? initialQuote, Map<String, dynamic>? scriptureQuote}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        onPosted: (_) {
          _followingKey.currentState?.refresh();
          _latestKey.currentState?.refresh();
          notifyPostCreated();
        },
        initialQuote: initialQuote,
        scriptureQuote: scriptureQuote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).square),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: AppStyle.brand,
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          indicatorSize: TabBarIndicatorSize.label,
          indicator: UnderlineTabIndicator(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppStyle.brand, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 8),
          ),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: AppLocalizations.of(context).following),
            Tab(text: AppLocalizations.of(context).latest),
            Tab(text: AppLocalizations.of(context).hot),
            Tab(text: AppLocalizations.of(context).topics),
          ],
        ),
      ),
      // 抬高，避开 HomeScreen 的毛玻璃底栏（extendBody 让 body 延伸到底栏下方）
      // 叠加底部安全区，保证 iOS（home indicator 更高）上不被底栏遮挡
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: 70 + MediaQuery.of(context).padding.bottom),
        child: GestureDetector(
          onTap: () => _showCreatePostSheet(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppStyle.brandGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppStyle.brand.withAlpha(120),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostList(
            key: _followingKey,
            loader: (page) => _postService.getFollowingPosts(page: page),
            emptyTitle: AppLocalizations.of(context).noFollowing,
            emptySubtitle: AppLocalizations.of(context).emptyFollowingSubtitle,
            onTopicTap: (t) => _tabController.animateTo(3),
          ),
          _PostList(
            key: _latestKey,
            loader: (page) => _postService.getFeedPosts(page: page),
            onTopicTap: (t) => _tabController.animateTo(3),
          ),
          _PostList(
            key: const PageStorageKey('hot'),
            loader: (page) => _postService.getHotPosts(page: page),
            onTopicTap: (t) => _tabController.animateTo(3),
          ),
          _TopicsTab(
            onTopicTap: (t) {},
          ),
        ],
      ),
    );
  }
}

// ---------- generic paginated post list ----------

class _PostList extends StatefulWidget {
  final Future<List<Post>> Function(int page) loader;
  final void Function(String topic)? onTopicTap;
  final String? emptyTitle;
  final String? emptySubtitle;

  const _PostList({
    super.key,
    required this.loader,
    this.onTopicTap,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  State<_PostList> createState() => _PostListState();
}

class _PostListState extends State<_PostList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;
  int _newPostCount = 0;
  RealtimeChannel? _realtimeChannel;

  @override
  bool get wantKeepAlive => true;

  StreamSubscription<Post>? _interactedSub;
  StreamSubscription<String>? _deletedSub;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
    _subscribeToNew();
    // 评论/点赞等互动后刷新列表，使评论数等即时更新
    _interactedSub = onPostInteracted.listen((updatedPost) {
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == updatedPost.id);
          if (index != -1) {
            _posts[index] = updatedPost;
          }
        });
      }
    });
    _deletedSub = onPostDeleted.listen((postId) {
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.id == postId);
        });
      }
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _interactedSub?.cancel();
    _deletedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Called by parent after a new post is created
  void refresh() => _loadPosts();

  void _subscribeToNew() {
    _realtimeChannel = Supabase.instance.client
        .channel('feed_new_${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            final myId = Supabase.instance.client.auth.currentUser?.id;
            if (payload.newRecord['user_id'] != myId && mounted) {
              setState(() => _newPostCount++);
            }
          },
        )
        .subscribe();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadPosts({bool showFullLoading = true}) async {
    if (showFullLoading) {
      setState(() => _loading = true);
    }
    try {
      final posts = await widget.loader(0);
      if (mounted) {
        setState(() {
          _posts
            ..clear()
            ..addAll(posts);
          _page = 1;
          _hasMore = posts.length == 20;
          _newPostCount = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed(e));
      }
    } finally {
      if (mounted && showFullLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final posts = await widget.loader(_page);
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _page++;
          _hasMore = posts.length == 20;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed(e));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadPosts(showFullLoading: false),
          child: _posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: PremiumEmptyState(
                        icon: Icons.dynamic_feed_rounded,
                        title: widget.emptyTitle ??
                            AppLocalizations.of(context).emptyPostsHint,
                        subtitle: widget.emptySubtitle,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  itemCount: _posts.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return PostCard(
                      post: _posts[i],
                      onTopicTap: widget.onTopicTap,
                      onDeleted: () =>
                          setState(() => _posts.removeAt(i)),
                    );
                  },
                ),
        ),
        if (_newPostCount > 0)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _newPostCount = 0);
                  _loadPosts();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ]),
                  child: Text(
                    AppLocalizations.of(context).newPostsNotification(_newPostCount),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------- topics tab ----------

class _TopicsTab extends StatefulWidget {
  final void Function(String topic) onTopicTap;

  const _TopicsTab({required this.onTopicTap});

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<String> _hotTopics = [];
  bool _loading = true;
  String? _selectedTopic;
  List<Post> _topicPosts = [];
  bool _loadingPosts = false;
  final _postService = PostService();
  StreamSubscription<Post>? _interactedSub;
  StreamSubscription<String>? _deletedSub;

  @override
  void initState() {
    super.initState();
    _loadHotTopics();
    _interactedSub = onPostInteracted.listen((updatedPost) {
      if (mounted) {
        setState(() {
          final index = _topicPosts.indexWhere((p) => p.id == updatedPost.id);
          if (index != -1) {
            _topicPosts[index] = updatedPost;
          }
        });
      }
    });
    _deletedSub = onPostDeleted.listen((postId) {
      if (mounted) {
        setState(() {
          _topicPosts.removeWhere((p) => p.id == postId);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _interactedSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHotTopics({bool showFullLoading = true}) async {
    if (showFullLoading) {
      setState(() => _loading = true);
    }
    try {
      final data = await _client
          .from('posts')
          .select('topics')
          .not('topics', 'eq', '{}')
          .limit(500);
      // Count frequency of each topic, then sort by count descending
      final Map<String, int> freq = {};
      for (final row in data as List) {
        final tags = (row['topics'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];
        for (final tag in tags) {
          freq[tag] = (freq[tag] ?? 0) + 1;
        }
      }
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (mounted) {
        setState(() => _hotTopics = sorted.take(30).map((e) => e.key).toList());
      }
    } finally {
      if (mounted && showFullLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshTopicPosts(String topic) async {
    try {
      final posts = await _postService.getPostsByTopic(topic);
      if (mounted) setState(() => _topicPosts = posts);
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).loadFailed(e));
      }
    }
  }

  Future<void> _selectTopic(String topic) async {
    setState(() {
      _selectedTopic = topic;
      _loadingPosts = true;
      _topicPosts = [];
    });
    try {
      final posts = await _postService.getPostsByTopic(topic);
      if (mounted) setState(() => _topicPosts = posts);
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTopic != null) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: Text('#$_selectedTopic',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => setState(() {
              _selectedTopic = null;
              _topicPosts = [];
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingPosts
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _refreshTopicPosts(_selectedTopic!),
                    child: _topicPosts.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: Text(AppLocalizations.of(context).emptyTopicPosts),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _topicPosts.length,
                            itemBuilder: (ctx, i) => PostCard(
                              post: _topicPosts[i],
                              onDeleted: () =>
                                  setState(() => _topicPosts.removeAt(i)),
                              onTopicTap: _selectTopic,
                            ),
                          ),
                  ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchTopicsHint,
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _selectTopic(v.trim());
            },
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadHotTopics(showFullLoading: false),
              child: _hotTopics.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Text(AppLocalizations.of(context).emptyTopics),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        Text(AppLocalizations.of(context).hotTopics,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _hotTopics
                              .map((t) => ActionChip(
                                    label: Text('#$t'),
                                    onPressed: () => _selectTopic(t),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

// ---------- create post sheet ----------

class _CreatePostSheet extends StatefulWidget {
  final void Function(Post) onPosted;
  final String? initialQuote;
  final Map<String, dynamic>? scriptureQuote;

  const _CreatePostSheet({
    required this.onPosted,
    this.initialQuote,
    this.scriptureQuote,
  });

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _contentCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _postService = PostService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  XFile? _video;
  VideoPlayerController? _videoPreviewCtrl;
  final List<String> _topics = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuote != null) {
      _contentCtrl.text = widget.initialQuote!;
    }
    _contentCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _topicCtrl.dispose();
    _videoPreviewCtrl?.dispose();
    super.dispose();
  }

  void _addTopic(String t) {
    t = t.replaceAll('#', '').trim();
    if (t.isEmpty || _topics.contains(t)) return;
    setState(() {
      _topics.add(t);
      _topicCtrl.clear();
    });
  }

  Future<void> _pickImages() async {
    final picked =
        await _picker.pickMultiImage(maxWidth: 1080, imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
        if (_images.length > 9) _images.length = 9;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    final ctrl = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
        : VideoPlayerController.file(File(picked.path));
    await ctrl.initialize();
    setState(() {
      _video = picked;
      _images.clear();
      _videoPreviewCtrl?.dispose();
      _videoPreviewCtrl = ctrl;
    });
  }

  Future<void> _submit() async {
    // 收编话题输入框里尚未回车提交的内容，避免直接点发布时话题被静默丢弃
    if (_topicCtrl.text.trim().isNotEmpty) {
      _addTopic(_topicCtrl.text);
    }
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _images.isEmpty && _video == null &&
        widget.scriptureQuote == null) {
      return;
    }
    if (ContentFilter.hasBanned(content)) {
      showPremiumToast(context, AppLocalizations.of(context).contentBlocked,
          kind: ToastKind.error);
      return;
    }
    setState(() => _loading = true);
    try {
      List<String> imageUrls = [];
      String? videoUrl;
      if (_images.isNotEmpty) {
        imageUrls = await _storageService.uploadPostImages(_images);
      } else if (_video != null) {
        videoUrl = await _storageService.uploadPostVideo(_video!); // XFile
      }
      final post = await _postService.createPost(
        content: content,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        topics: _topics,
        scriptureQuote: widget.scriptureQuote,
      );
      widget.onPosted(post);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).publishFailed(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F8);
    final divColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(AppLocalizations.of(context).cancel,
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600)),
                  ),
                ),
                const Spacer(),
                Text(AppLocalizations.of(context).postTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black)),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: _loading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _loading ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context).publish,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 16, thickness: 0.5, color: divColor),

          // ── Scripture quote preview ──────────────────────────────────────
          if (widget.scriptureQuote != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF2A1F3D), Color(0xFF1E1E2E)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFF3EDF9), Color(0xFFEDE7F6)],
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF9575CD).withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      size: 14, color: Color(0xFF9575CD)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '《${widget.scriptureQuote!['scripture']}》${widget.scriptureQuote!['chapter']}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9575CD),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ── Text input ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _contentCtrl,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.5),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).shareThoughtsHint,
                hintStyle: TextStyle(
                    color: isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    fontSize: 16),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // ── Topic input + chips ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _topicCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).addTopicHint,
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400),
                  prefixIcon: Icon(Icons.tag_rounded,
                      size: 18,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  filled: false,
                ),
                onSubmitted: _addTopic,
              ),
            ),
          ),
          if (_topics.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _topics
                    .map((t) => Chip(
                          label: Text('#$t',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9575CD),
                                  fontWeight: FontWeight.w500)),
                          onDeleted: () =>
                              setState(() => _topics.remove(t)),
                          deleteIconColor:
                              const Color(0xFF9575CD).withAlpha(160),
                          backgroundColor:
                              const Color(0xFF9575CD).withAlpha(20),
                          side: BorderSide(
                              color: const Color(0xFF9575CD).withAlpha(60)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          ],
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount:
                    _images.length + (_images.length < 9 ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == _images.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.add, color: Colors.grey),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(_images[i].path,
                                width: 80, height: 80, fit: BoxFit.cover)
                            : Image.file(File(_images[i].path),
                                width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _images.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          if (_video != null && _videoPreviewCtrl != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: _videoPreviewCtrl!.value.aspectRatio,
                    child: VideoPlayer(_videoPreviewCtrl!),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      _videoPreviewCtrl?.dispose();
                      setState(() {
                        _video = null;
                        _videoPreviewCtrl = null;
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // ── Media toolbar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: divColor, width: 0.5)),
            ),
            child: Row(
              children: [
                _MediaToolBtn(
                  icon: Icons.image_rounded,
                  label: AppLocalizations.of(context).attachmentPhoto,
                  enabled: _video == null && _images.length < 9,
                  onTap: _pickImages,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _MediaToolBtn(
                  icon: Icons.videocam_rounded,
                  label: AppLocalizations.of(context).attachmentVideo,
                  enabled: _images.isEmpty && _video == null,
                  onTap: _pickVideo,
                  isDark: isDark,
                ),
                const Spacer(),
                Text(
                  '${_contentCtrl.text.length}/500',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  const _MediaToolBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isDark ? Colors.grey.shade300 : Colors.grey.shade700)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade400);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF0F0F5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
