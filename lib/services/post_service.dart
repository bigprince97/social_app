import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';

class PostService {
  final _client = Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Post>> getFeedPosts({int page = 0, int limit = 20}) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);

    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<Post> createPost({
    required String content,
    List<String> imageUrls = const [],
    String? videoUrl,
    List<String> topics = const [],
    Map<String, dynamic>? scriptureQuote,
  }) async {
    final userId = _client.auth.currentUser!.id;
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
        .select('*, profiles!posts_user_id_fkey(*)')
        .single();
    return Post.fromJson(data);
  }

  Future<List<Post>> getPostsByTopic(String topic,
      {int page = 0, int limit = 20}) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .contains('topics', [topic])
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<List<Post>> getHotPosts({int page = 0, int limit = 20}) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .order('likes_count', ascending: false)
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<void> _hydrateIsLiked(List<Post> posts) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || posts.isEmpty) return;
    final postIds = posts.map((p) => p.id).toList();
    final likes = await _client
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    final likedIds = (likes as List).map((l) => l['post_id'] as String).toSet();
    for (final post in posts) {
      post.isLiked = likedIds.contains(post.id);
    }
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  Future<Post> getPostById(String postId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .eq('id', postId)
        .single();
    final post = Post.fromJson(data);
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final like = await _client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      post.isLiked = like != null;
    }
    return post;
  }

  Future<void> likePost(String postId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
  }

  Future<void> unlikePost(String postId) async {
    final userId = _client.auth.currentUser!.id;
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
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('post_comments')
        .insert({'post_id': postId, 'user_id': userId, 'content': content})
        .select('*, profiles!post_comments_user_id_fkey(*)')
        .single();
    return PostComment.fromJson(data);
  }

  Future<List<Post>> getFollowingPosts({int page = 0, int limit = 20}) async {
    final userId = currentUserId;
    if (userId == null) return [];
    final follows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final ids = (follows as List).map((f) => f['following_id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .inFilter('user_id', ids)
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    final posts = (data as List).map((e) => Post.fromJson(e)).toList();
    await _hydrateIsLiked(posts);
    return posts;
  }

  Future<List<Post>> getUserPosts(String userId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }
}
