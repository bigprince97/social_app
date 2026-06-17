import 'profile.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String messageType; // 'text' | 'image' | 'video' | 'file' | 'audio' | 'scripture'
  final String? mediaUrl;
  final bool isDeleted;
  final DateTime createdAt;
  final Profile? sender;
  final Map<String, dynamic>? payload;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.isDeleted = false,
    required this.createdAt,
    this.sender,
    this.payload,
  });

  String? get fileName => payload?['name'] as String?;
  int? get fileSize => payload?['size'] as int?;
  String? get fileMime => payload?['mime'] as String?;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String?,
        messageType: (json['message_type'] as String?) ?? 'text',
        mediaUrl: json['media_url'] as String?,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        sender: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
        payload: json['payload'] as Map<String, dynamic>?,
      );

  String get displayContent {
    if (isDeleted) return '消息已撤回';
    if (messageType == 'image') return '[图片]';
    if (messageType == 'video') return '[视频]';
    if (messageType == 'file') return '[文件]';
    if (messageType == 'audio') return '[语音]';
    if (messageType == 'scripture') return '[经文引用]';
    if (messageType == 'call') {
      final video = payload?['call_type'] == 'video';
      return video ? '[视频通话]' : '[语音通话]';
    }
    return content ?? '';
  }
}
