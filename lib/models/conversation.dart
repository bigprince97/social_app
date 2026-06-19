import 'profile.dart';

class Conversation {
  final String id;
  final String type; // 'direct' | 'group'
  String? name; // 群名可被群主/管理员修改
  String? avatarUrl; // 群头像可被群主/管理员修改
  final String? createdBy;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final DateTime createdAt;
  final List<ConversationMember> members;
  int unreadCount;
  String? announcement;
  DateTime? announcementUpdatedAt;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.createdBy,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
    this.members = const [],
    this.unreadCount = 0,
    this.announcement,
    this.announcementUpdatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        type: json['type'] as String,
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdBy: json['created_by'] as String?,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        lastMessagePreview: json['last_message_preview'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        members: (json['conversation_members'] as List<dynamic>?)
                ?.map((m) =>
                    ConversationMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        announcement: json['announcement'] as String?,
        announcementUpdatedAt: json['announcement_updated_at'] != null
            ? DateTime.parse(json['announcement_updated_at'] as String)
            : null,
      );

  String displayName(String currentUserId) {
    if (type == 'group') return name ?? '群聊';
    if (members.isEmpty) return '未知用户';
    final other = members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => members.first,
    );
    return other.profile?.displayName ?? '未知用户';
  }

  String? displayAvatar(String currentUserId) {
    if (type == 'group') return avatarUrl;
    if (members.isEmpty) return null;
    final other = members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => members.first,
    );
    return other.profile?.avatarUrl;
  }
}

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final String role;
  final DateTime? lastReadAt;
  final bool hidden;
  final Profile? profile;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    this.lastReadAt,
    this.hidden = false,
    this.profile,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) =>
      ConversationMember(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        userId: json['user_id'] as String,
        role: (json['role'] as String?) ?? 'member',
        lastReadAt: json['last_read_at'] != null
            ? DateTime.parse(json['last_read_at'] as String)
            : null,
        hidden: (json['hidden'] as bool?) ?? false,
        profile: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}
