import 'profile.dart';

class Post {
  final String id;
  final String userId;
  final String content;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? audioUrl;
  final List<String> topics;
  final Map<String, dynamic>? scriptureQuote;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final Profile? author;
  bool isLiked;
  bool isBookmarked;

  Post({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrls = const [],
    this.videoUrl,
    this.audioUrl,
    this.topics = const [],
    this.scriptureQuote,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.author,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  static int _parseLikesCount(Map<String, dynamic> json) {
    if (json['post_likes'] != null) {
      final list = json['post_likes'] as List;
      if (list.isNotEmpty && list.first is Map && (list.first as Map).containsKey('count')) {
        return (list.first['count'] as int?) ?? 0;
      }
    }
    return (json['likes_count'] as int?) ?? 0;
  }

  static int _parseCommentsCount(Map<String, dynamic> json) {
    if (json['post_comments'] != null) {
      final list = json['post_comments'] as List;
      if (list.isNotEmpty && list.first is Map && (list.first as Map).containsKey('count')) {
        return (list.first['count'] as int?) ?? 0;
      }
    }
    return (json['comments_count'] as int?) ?? 0;
  }

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        imageUrls: (json['image_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        videoUrl: json['video_url'] as String?,
        audioUrl: json['audio_url'] as String?,
        topics: (json['topics'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        scriptureQuote: json['scripture_quote'] as Map<String, dynamic>?,
        likesCount: _parseLikesCount(json),
        commentsCount: _parseCommentsCount(json),
        createdAt: DateTime.parse(json['created_at'] as String),
        author: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );

  Post copyWith({int? likesCount, int? commentsCount, bool? isLiked, bool? isBookmarked}) => Post(
    id: id, userId: userId, content: content,
    imageUrls: imageUrls, videoUrl: videoUrl, audioUrl: audioUrl,
    topics: topics, scriptureQuote: scriptureQuote,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    createdAt: createdAt, author: author,
    isLiked: isLiked ?? this.isLiked,
    isBookmarked: isBookmarked ?? this.isBookmarked,
  );
}

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Profile? author;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        author: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}
