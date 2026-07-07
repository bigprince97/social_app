import 'profile.dart';

class AppNotification {
  final String id;
  final String userId;
  final String actorId;
  final String type; // like | comment | follow | mention | new_post
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;
  final Profile? actor;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.postId,
    this.commentId,
    this.isRead = false,
    required this.createdAt,
    this.actor,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        actorId: json['actor_id'] as String,
        type: json['type'] as String,
        postId: json['post_id'] as String?,
        commentId: json['comment_id'] as String?,
        isRead: (json['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        actor: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );

  String get body {
    switch (type) {
      case 'like':
        return '${actor?.displayName ?? '有人'} 点赞了你的帖子';
      case 'comment':
        return '${actor?.displayName ?? '有人'} 评论了你的帖子';
      case 'follow':
        return '${actor?.displayName ?? '有人'} 关注了你';
      case 'new_post':
        return '${actor?.displayName ?? '有人'} 发布了新帖子';
      default:
        return '你有一条新通知';
    }
  }
}
