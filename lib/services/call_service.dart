import 'package:supabase_flutter/supabase_flutter.dart';

class CallInfo {
  final String id;
  final String conversationId;
  final String callerId;
  final String? calleeId;
  final String callType; // 'voice' | 'video' | 'livestream'
  final String status;   // 'ringing' | 'accepted' | 'declined' | 'ended' | 'missed'
  final String? livekitRoom;
  final DateTime createdAt;

  CallInfo({
    required this.id,
    required this.conversationId,
    required this.callerId,
    this.calleeId,
    required this.callType,
    required this.status,
    this.livekitRoom,
    required this.createdAt,
  });

  factory CallInfo.fromJson(Map<String, dynamic> j) => CallInfo(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        callerId: j['caller_id'] as String,
        calleeId: j['callee_id'] as String?,
        callType: (j['call_type'] as String?) ?? 'voice',
        status: (j['status'] as String?) ?? 'ringing',
        livekitRoom: j['livekit_room'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class CallService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // Get LiveKit token from Edge Function
  Future<({String token, String url})> getLiveKitToken({
    required String room,
    required bool canPublish,
    String? identity,
  }) async {
    // 带上昵称，直播间成员面板按 participant.name 显示
    String? displayName;
    try {
      final p = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', identity ?? _userId!)
          .maybeSingle();
      displayName = p?['display_name'] as String?;
    } catch (_) {}
    final res = await _client.functions.invoke(
      'livekit-token',
      body: {
        'room': room,
        'identity': identity ?? _userId,
        'name': displayName,
        'can_publish': canPublish,
        'can_subscribe': true,
      },
    );
    if (res.status != 200) {
      throw Exception('Failed to get LiveKit token: ${res.data}');
    }
    final data = res.data as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      url: data['url'] as String,
    );
  }

  // Create a call (caller side)
  Future<CallInfo> createCall({
    required String conversationId,
    required String callType,
    String? calleeId,
  }) async {
    final roomName = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final data = await _client
        .from('calls')
        .insert({
          'conversation_id': conversationId,
          'caller_id': _userId,
          'callee_id': calleeId,
          'call_type': callType,
          'status': 'ringing',
          'livekit_room': roomName,
        })
        .select()
        .single();
    return CallInfo.fromJson(data);
  }

  Future<void> acceptCall(String callId) async {
    await _client.from('calls').update({
      'status': 'accepted',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
  }

  Future<void> declineCall(String callId) async {
    await _client.from('calls').update({
      'status': 'declined',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
  }

  Future<void> endCall(String callId) async {
    await _client.from('calls').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
  }

  /// 通话结束后在会话里留一条「通话记录」消息（仅主叫方调用，避免重复）。
  /// status: 'ended'(已接通,含时长) | 'canceled'(主叫取消) |
  ///         'declined'(被拒) | 'missed'(未接听)
  Future<void> logCall({
    required String conversationId,
    required String callType, // 'voice' | 'video'
    required String status,
    int durationSecs = 0,
  }) async {
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _userId,
        'content': '[通话]',
        'message_type': 'call',
        'payload': {
          'call_type': callType,
          'status': status,
          'duration': durationSecs,
        },
      });
    } catch (_) {
      // 记录失败不影响挂断流程
    }
  }

  Future<CallInfo?> getActiveCall(String conversationId) async {
    final data = await _client
        .from('calls')
        .select()
        .eq('conversation_id', conversationId)
        .inFilter('status', ['ringing', 'accepted'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return CallInfo.fromJson(data);
  }

  // Subscribe to incoming calls for current user
  RealtimeChannel subscribeToIncomingCalls(
    void Function(CallInfo call) onIncomingCall,
  ) {
    final uid = _userId;
    return _client
        .channel('incoming_calls:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            final row = payload.newRecord;
            // Only notify if we are the callee
            if (row['callee_id'] == uid) {
              onIncomingCall(CallInfo.fromJson(row));
            }
          },
        )
        .subscribe();
  }

  // Subscribe to call status changes (e.g., callee accepted/declined)
  RealtimeChannel subscribeToCallStatus(
    String callId,
    void Function(String status) onStatusChange,
  ) {
    return _client
        .channel('call_status:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null) onStatusChange(status);
          },
        )
        .subscribe();
  }

  // 订阅某会话内通话/直播的任意变化（开始/结束）——用于群直播横幅刷新
  RealtimeChannel subscribeToConversationCalls(
    String conversationId,
    void Function() onChange,
  ) {
    return _client
        .channel('conv_calls:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  // 取会话内进行中的直播（群成员加入用）
  Future<CallInfo?> getActiveLivestream(String conversationId) async {
    final data = await _client
        .from('calls')
        .select()
        .eq('conversation_id', conversationId)
        .eq('call_type', 'livestream')
        .inFilter('status', ['ringing', 'accepted'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return CallInfo.fromJson(data);
  }
}
