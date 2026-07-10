import 'profile.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  // 'text' | 'image' | 'video' | 'file' | 'audio' | 'scripture'
  final String messageType;
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
  String? get videoThumbnail => payload?['thumbnail'] as String?;
  bool get isEdited => payload?['edited_at'] != null;

  // ── 本地乐观发送态（仅本地，不入库）：payload 里带 pending/进度/本地路径 ──
  bool get isUploading => payload?['pending'] == true;
  bool get isSendFailed => payload?['failed'] == true;
  double? get uploadProgress =>
      (payload?['upload_progress'] as num?)?.toDouble();
  String? get localPath => payload?['local_path'] as String?;

  // 引用回复（长按消息→回复）：信息存 payload['reply_to']，无需数据库改动
  Map<String, dynamic>? get _replyTo => payload?['reply_to'] is Map
      ? Map.from(payload!['reply_to'] as Map)
      : null;
  String? get replyToId => _replyTo?['id'] as String?;
  String? get replyToSender => _replyTo?['sender'] as String?;
  String? get replyToPreview => _replyTo?['preview'] as String?;
  // 被引用消息的可辨识信息。新消息写完整元数据，旧消息仍兼容 preview/type/thumb。
  String? get replyToThumb => _replyTo?['thumb'] as String?;
  String? get replyToType => _replyTo?['type'] as String?;
  String? get replyToFileName => _replyTo?['file_name'] as String?;
  int? get replyToSize => (_replyTo?['size'] as num?)?.toInt();
  String? get replyToMime => _replyTo?['mime'] as String?;
  DateTime? get replyToSentAt {
    final raw = _replyTo?['sent_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// 当前消息被别人引用时使用的明确摘要。
  /// 媒体消息附带原发送时间/大小；文件保留文件名，避免多个视频或文件无法区分。
  String get replyTargetPreview {
    final time = _formatReplyTime(createdAt);
    final size = _formatBytes(fileSize);
    switch (messageType) {
      case 'image':
        return '图片 · $time';
      case 'video':
        return size == null ? '视频 · $time' : '视频 · $size · $time';
      case 'file':
        final name = fileName ?? content ?? '文件';
        return size == null ? name : '$name · $size';
      case 'audio':
        final seconds = (payload?['duration'] as num?)?.toInt();
        return seconds == null
            ? '语音 · $time'
            : '语音 ${_formatDuration(seconds)} · $time';
      case 'scripture':
        final text = (content ?? '').split('|||').first.trim();
        return text.isEmpty ? '经文引用' : '经文 · $text';
      case 'call':
        return '$displayContent · $time';
      default:
        return content?.trim().isNotEmpty == true ? content!.trim() : '消息';
    }
  }

  /// 图片使用原图；视频必须使用已生成的预览图，不能把视频 URL 交给图片组件。
  String? get replyTargetThumb {
    if (messageType == 'image') return mediaUrl;
    if (messageType == 'video') return videoThumbnail;
    return null;
  }

  Map<String, dynamic> toReplyMetadata() => {
    'id': id,
    'sender': sender?.displayName ?? '',
    'preview': replyTargetPreview,
    'type': messageType,
    'sent_at': createdAt.toIso8601String(),
    if (replyTargetThumb != null) 'thumb': replyTargetThumb,
    if (fileName != null) 'file_name': fileName,
    if (fileSize != null) 'size': fileSize,
    if (fileMime != null) 'mime': fileMime,
  };

  static String _formatReplyTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDuration(int seconds) {
    final minute = (seconds ~/ 60).toString();
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minute:$remainder';
  }

  static String? _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

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
    payload: json['payload'] == null
        ? null
        : Map<String, dynamic>.from(json['payload'] as Map),
  );

  Message copyWith({
    String? content,
    String? messageType,
    String? mediaUrl,
    bool? isDeleted,
    DateTime? createdAt,
    Profile? sender,
    Map<String, dynamic>? payload,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'content': content,
    'message_type': messageType,
    'media_url': mediaUrl,
    'is_deleted': isDeleted,
    'created_at': createdAt.toIso8601String(),
    'payload': payload,
    if (sender != null) 'profiles': sender!.toJson(),
  };

  String get displayContent {
    if (isDeleted) return '消息已撤回';
    if (messageType == 'image') return '[图片]';
    if (messageType == 'video') return '[视频]';
    if (messageType == 'file') {
      final name = fileName ?? content;
      return name?.isNotEmpty == true ? '[文件] $name' : '[文件]';
    }
    if (messageType == 'audio') return '[语音]';
    if (messageType == 'scripture') return '[经文引用]';
    if (messageType == 'call') {
      final video = payload?['call_type'] == 'video';
      return video ? '[视频通话]' : '[语音通话]';
    }
    return content ?? '';
  }
}
