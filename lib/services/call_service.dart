import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import 'block_service.dart';

class CallInfo {
  final String id;
  final String conversationId;
  final String callerId;
  final String? calleeId;
  final String callType; // 'voice' | 'video' | 'livestream'
  final String
  status; // 'ringing' | 'accepted' | 'declined' | 'ended' | 'missed'
  final String? livekitRoom;
  final DateTime createdAt;
  final DateTime? lastHeartbeatAt;

  CallInfo({
    required this.id,
    required this.conversationId,
    required this.callerId,
    this.calleeId,
    required this.callType,
    required this.status,
    this.livekitRoom,
    required this.createdAt,
    this.lastHeartbeatAt,
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
    lastHeartbeatAt: j['last_heartbeat_at'] != null
        ? DateTime.parse(j['last_heartbeat_at'] as String)
        : null,
  );
}

class CallService {
  final _client = Supabase.instance.client;
  final _blockService = BlockService();
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
          .eq('id', identity ?? requireUid(_client))
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
    return (token: data['token'] as String, url: data['url'] as String);
  }

  // Create a call (caller side)
  Future<CallInfo> createCall({
    required String conversationId,
    required String callType,
    String? calleeId,
  }) async {
    if (callType == 'livestream') {
      final data = await _client.rpc<Map<String, dynamic>>(
        'start_livestream_call',
        params: {'p_conversation_id': conversationId},
      );
      return CallInfo.fromJson(data);
    }
    if (calleeId == null) {
      throw ArgumentError('Direct calls require a callee');
    }
    // 客户端先拦截，给用户即时反馈；数据库 RLS 仍会做最终强制校验，
    // 防止旧版本客户端或直接调用 API 绕过拉黑关系。
    if (await _blockService.isEitherBlocked(calleeId)) {
      throw const BlockedCallException();
    }
    final roomName = 'call_${DateTime.now().millisecondsSinceEpoch}';
    try {
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
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.contains('row-level security') ||
          e.message.contains('calls_blocked')) {
        throw const BlockedCallException();
      }
      rethrow;
    }
  }

  Future<void> acceptCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': 'accepted',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> declineCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': 'declined',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> endCall(String callId) async {
    await _client
        .from('calls')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId);
  }

  Future<void> closeLivestreamCall(String callId) async {
    await _client.rpc('close_livestream_call', params: {'p_call_id': callId});
  }

  Future<void> markLivestreamHeartbeat(String callId) async {
    await _client.rpc(
      'mark_livestream_heartbeat',
      params: {'p_call_id': callId},
    );
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

  /// 按 id 取通话（推送收到来电后用 call_id 拉取完整信息）
  Future<CallInfo?> getCallById(String callId) async {
    final data = await _client
        .from('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();
    if (data == null) return null;
    return CallInfo.fromJson(data);
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

  /// 冷启动、回前台或 Realtime 重连后主动补查仍在振铃的私聊来电，
  /// 避免事件发生在监听建立之前而漏掉全屏提醒。
  Future<CallInfo?> getRingingIncomingCall() async {
    final uid = _userId;
    if (uid == null) return null;
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: 90))
        .toIso8601String();
    final data = await _client
        .from('calls')
        .select()
        .eq('callee_id', uid)
        .eq('status', 'ringing')
        .inFilter('call_type', ['voice', 'video'])
        .gte('created_at', cutoff)
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
    var channel = _client
        .channel('incoming_calls:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: uid == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'callee_id',
                  value: uid,
                ),
          callback: (payload) {
            final row = payload.newRecord;
            // Only notify if we are the callee
            if (row['callee_id'] == uid && row['call_type'] != 'livestream') {
              onIncomingCall(CallInfo.fromJson(row));
            }
          },
        );
    return channel.subscribe();
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
    final data = await _client.rpc<List<dynamic>>(
      'get_active_livestream',
      params: {'p_conversation_id': conversationId},
    );
    if (data.isEmpty) return null;
    return CallInfo.fromJson(Map<String, dynamic>.from(data.first as Map));
  }
}

class BlockedCallException implements Exception {
  const BlockedCallException();

  @override
  String toString() => 'BlockedCallException';
}
