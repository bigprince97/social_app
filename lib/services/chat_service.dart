import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ─── Conversations ────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    final data = await _client
        .from('conversations')
        .select('*, conversation_members(*, profiles(*))')
        .order('last_message_at', ascending: false);
    var convs = (data as List).map((e) => Conversation.fromJson(e)).toList();
    final uid = _userId;
    if (uid != null) {
      // 过滤掉「我」已隐藏（软删除）的会话
      convs = convs.where((conv) {
        final me = conv.members.where((m) => m.userId == uid).firstOrNull;
        return me == null || !me.hidden;
      }).toList();
      for (final conv in convs) {
        final me = conv.members.where((m) => m.userId == uid).firstOrNull;
        if (me != null && conv.lastMessageAt != null) {
          if (me.lastReadAt == null ||
              conv.lastMessageAt!.isAfter(me.lastReadAt!)) {
            conv.unreadCount = 1;
          }
        }
      }
    }
    return convs;
  }

  Future<Conversation> createDirectConversation(String otherUserId) async {
    final result = await _client.rpc(
      'create_direct_conversation',
      params: {'other_user_id': otherUserId},
    );
    return Conversation.fromJson(result as Map<String, dynamic>);
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
  }) async {
    final conv = await _client
        .from('conversations')
        .insert({'type': 'group', 'name': name, 'created_by': _userId})
        .select()
        .single();

    final allMembers = [_userId!, ...memberIds];
    await _client.from('conversation_members').insert(
          allMembers
              .map((id) => {
                    'conversation_id': conv['id'],
                    'user_id': id,
                    'role': id == _userId ? 'admin' : 'member',
                  })
              .toList(),
        );

    final full = await _client
        .from('conversations')
        .select('*, conversation_members(*, profiles(*))')
        .eq('id', conv['id'] as String)
        .single();
    return Conversation.fromJson(full);
  }

  Future<void> disbandGroup(String conversationId) async {
    await _client.from('conversations').delete().eq('id', conversationId);
  }

  /// 删除对话：仅从「我的」列表隐藏（软删除，标记 hidden=true），
  /// 不删成员行——否则会破坏对方的直聊（对方进来找不到我）。
  /// 重新收到/发送消息时会自动取消隐藏。
  Future<void> deleteConversation(String conversationId) async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('conversation_members')
        .update({'hidden': true})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid);
  }

  /// 向群里添加成员（去重已在群成员；以 member 角色加入）
  Future<void> addMembers(
    String conversationId,
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return;
    final existing = await _client
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId);
    final existingIds = {
      for (final r in existing as List) r['user_id'] as String,
    };
    final toAdd = userIds.where((id) => !existingIds.contains(id)).toList();
    if (toAdd.isEmpty) return;
    await _client.from('conversation_members').insert(
          toAdd
              .map((id) => {
                    'conversation_id': conversationId,
                    'user_id': id,
                    'role': 'member',
                  })
              .toList(),
        );
  }

  Future<void> promoteToAdmin(String memberId) async {
    await _client
        .from('conversation_members')
        .update({'role': 'admin'})
        .eq('id', memberId);
  }

  Future<void> demoteToMember(String memberId) async {
    await _client
        .from('conversation_members')
        .update({'role': 'member'})
        .eq('id', memberId);
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  Future<List<Message>> getMessages(String conversationId,
      {int page = 0, int limit = 50}) async {
    final data = await _client
        .from('messages')
        .select('*, profiles(*)')
        .eq('conversation_id', conversationId)
        // 仅进群文件、不在聊天显示的文件（files_only）排除
        .or('payload->>files_only.is.null,payload->>files_only.neq.true')
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    return (data as List)
        .map((e) => Message.fromJson(e))
        .toList()
        .reversed
        .toList();
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    Map<String, dynamic>? payload,
    List<String>? mentionedUserIds,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': content,
          'message_type': messageType,
          'media_url': ?mediaUrl,
          'payload': ?payload,
          if (mentionedUserIds?.isNotEmpty == true)
            'mentions': mentionedUserIds,
        })
        .select('*, profiles(*)')
        .single();
    return Message.fromJson(data);
  }

  Future<Message> sendImageMessage({
    required String conversationId,
    required XFile imageFile,
  }) async {
    final ext = imageFile.name.contains('.') ? imageFile.name.split('.').last : 'jpg';
    final path = 'chat/$_userId/${const Uuid().v4()}.$ext';
    final bytes = await imageFile.readAsBytes();
    await _client.storage.from('media').uploadBinary(path, bytes);
    final url = _client.storage.from('media').getPublicUrl(path);
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'image',
      mediaUrl: url,
    );
  }

  Future<Message> sendAudioMessage({
    required String conversationId,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'audio',
      mediaUrl: audioUrl,
      payload: {'duration': durationSeconds},
    );
  }

  Future<Message> sendVideoMessage({
    required String conversationId,
    required String videoUrl,
    required int fileSize,
    String? thumbnailUrl,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      content: '',
      messageType: 'video',
      mediaUrl: videoUrl,
      payload: {
        'size': fileSize,
        'thumbnail': thumbnailUrl,
      },
    );
  }

  Future<Message> sendFileMessage({
    required String conversationId,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String? mimeType,
    // true=仅存入群文件、不在聊天中显示（群文件页直接上传）
    bool filesOnly = false,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': fileName,
          'message_type': 'file',
          'media_url': fileUrl,
          'payload': {
            'name': fileName,
            'size': fileSize,
            'mime': mimeType ?? 'application/octet-stream',
            if (filesOnly) 'files_only': true,
          },
        })
        .select('*, profiles(*)')
        .single();
    return Message.fromJson(data);
  }

  Future<Message> sendScriptureMessage({
    required String conversationId,
    required String quoteText,
    required String scriptureTitle,
    required String chapterTitle,
  }) async {
    final content = '$quoteText|||$scriptureTitle|||$chapterTitle';
    return sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: 'scripture',
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'is_deleted': true})
        .eq('id', messageId);
  }

  Future<void> updateLastRead(String conversationId) async {
    await _client
        .from('conversation_members')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', _userId!);
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message) onMessage,
  ) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow['sender_id'] == _userId) return;
            final full = await _client
                .from('messages')
                .select('*, profiles(*)')
                .eq('id', newRow['id'] as String)
                .single();
            onMessage(Message.fromJson(full));
          },
        )
        .subscribe();
  }

  // Subscribe to message updates (recall / edit)
  RealtimeChannel subscribeToMessageUpdates(
    String conversationId,
    void Function(String messageId, bool isDeleted) onUpdate,
  ) {
    return _client
        .channel('messages_update:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            final id = updated['id'] as String?;
            final isDeleted = (updated['is_deleted'] as bool?) ?? false;
            if (id != null) onUpdate(id, isDeleted);
          },
        )
        .subscribe();
  }
}
