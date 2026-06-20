import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import '../models/post.dart';
import 'local_cache.dart';

class PostService {
  final _client = Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;

  // 缓存优先（SWR）：成功写盘，离线读回，保证冷启动也有内容。
  List<Post> _parseCached(dynamic cached) => cached is List
      ? cached
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
      : <Post>[];

  /// 只读本地缓存（不碰网络），用于「缓存优先」秒显。
  /// which: 'feed_latest' | 'feed_hot' | 'feed_following'
  Future<List<Post>> getCachedFeed(String which) async =>
      _parseCached(await LocalCache.instance.read(which));

  Future<List<Post>> getFeedPosts({int page = 0, int limit = 20}) async {
    try {
      final data = await _client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      if (page == 0) await LocalCache.instance.write('feed_latest', data);
      final posts = (data as List).map((e) => Post.fromJson(e)).toList();
      await _hydrateIsLiked(posts);
      return posts;
    } catch (e) {
      if (page == 0 && isNetworkError(e)) {
        return _parseCached(await LocalCache.instance.read('feed_latest'));
      }
      rethrow;
    }
  }

  Future<Post> createPost({
    required String content,
    List<String> imageUrls = const [],
    String? videoUrl,
    List<String> topics = const [],
    Map<String, dynamic>? scriptureQuote,
  }) async {
    final userId = requireUid(_client);
    final data = await _client
        .from('posts')
        .insert({
          'user_id': userId,
          'content': content,
          'image_urls': imageUrls,
          'video_url': videoUrl,
          if (topics.isNotEmpty) 'topics': topics,
          'scripture_quote': scriptureQuote,
        })
        .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
        .single();
    return Post.fromJson(data);
  }

  Future<List<Post>> getPostsByTopic(String topic,
      {int page = 0, int limit = 20}) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
        .contains('topics', [topic])
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<List<Post>> getHotPosts({int page = 0, int limit = 20}) async {
    try {
      final data = await _client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
          .order('likes_count', ascending: false)
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      if (page == 0) await LocalCache.instance.write('feed_hot', data);
      final posts = (data as List).map((e) => Post.fromJson(e)).toList();
      await _hydrateIsLiked(posts);
      return posts;
    } catch (e) {
      if (page == 0 && isNetworkError(e)) {
        return _parseCached(await LocalCache.instance.read('feed_hot'));
      }
      rethrow;
    }
  }

  Future<void> _hydrateIsLiked(List<Post> posts) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || posts.isEmpty) return;
    try {
    final postIds = posts.map((p) => p.id).toList();
    final results = await Future.wait<dynamic>([
      _client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds),
      _client
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds),
    ]);
    final likedIds =
        (results[0] as List).map((l) => l['post_id'] as String).toSet();
    final bookmarkedIds =
        (results[1] as List).map((l) => l['post_id'] as String).toSet();
    for (final post in posts) {
      post.isLiked = likedIds.contains(post.id);
      post.isBookmarked = bookmarkedIds.contains(post.id);
    }
    } catch (_) {/* 点赞/收藏状态属增强信息，离线失败不影响帖子展示 */}
  }

  Future<void> bookmarkPost(String postId) async {
    final userId = requireUid(_client);
    await _client
        .from('post_bookmarks')
        .insert({'post_id': postId, 'user_id': userId});
  }

  Future<void> unbookmarkPost(String postId) async {
    final userId = requireUid(_client);
    await _client
        .from('post_bookmarks')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  /// 我的收藏：按收藏时间倒序返回帖子。
  Future<List<Post>> getBookmarkedPosts({int page = 0, int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('post_bookmarks')
        .select('post_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    final ids = (rows as List).map((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
        .inFilter('id', ids);
    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    // 保持收藏时间顺序
    final orderMap = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    posts.sort((a, b) =>
        (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  Future<Post> getPostById(String postId) async {
    final userId = _client.auth.currentUser?.id;
    final results = await Future.wait<dynamic>([
      _client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
          .eq('id', postId)
          .single(),
      if (userId != null)
        _client
            .from('post_likes')
            .select()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle()
      else
        Future<dynamic>.value(null),
      if (userId != null)
        _client
            .from('post_bookmarks')
            .select()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle()
      else
        Future<dynamic>.value(null),
    ]);

    final post = Post.fromJson(results[0] as Map<String, dynamic>);
    post.isLiked = results[1] != null;
    post.isBookmarked = results[2] != null;
    return post;
  }

  Future<void> likePost(String postId) async {
    final userId = requireUid(_client);
    await _client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
  }

  Future<void> unlikePost(String postId) async {
    final userId = requireUid(_client);
    await _client
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  Future<List<PostComment>> getComments(String postId) async {
    final data = await _client
        .from('post_comments')
        .select('*, profiles!post_comments_user_id_fkey(*)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => PostComment.fromJson(e)).toList();
  }

  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) async {
    final userId = requireUid(_client);
    final data = await _client
        .from('post_comments')
        .insert({'post_id': postId, 'user_id': userId, 'content': content})
        .select('*, profiles!post_comments_user_id_fkey(*)')
        .single();
    return PostComment.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('post_comments').delete().eq('id', commentId);
  }

  Future<List<Post>> getFollowingPosts({int page = 0, int limit = 20}) async {
    final userId = currentUserId;
    if (userId == null) return [];
    try {
      final follows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      final ids =
          (follows as List).map((f) => f['following_id'] as String).toList();
      if (ids.isEmpty) return [];
      final data = await _client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
          .inFilter('user_id', ids)
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      if (page == 0) await LocalCache.instance.write('feed_following', data);
      final posts = (data as List).map((e) => Post.fromJson(e)).toList();
      await _hydrateIsLiked(posts);
      return posts;
    } catch (e) {
      if (page == 0 && isNetworkError(e)) {
        return _parseCached(await LocalCache.instance.read('feed_following'));
      }
      rethrow;
    }
  }

  Future<List<Post>> getUserPosts(String userId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*), post_comments(count), post_likes(count)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }
}
