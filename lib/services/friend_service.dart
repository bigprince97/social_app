import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import '../models/profile.dart';
import 'block_service.dart';
import 'profile_service.dart' show BlockedUserInteractionException;

/// 好友关系状态（相对当前登录用户）。
enum FriendshipStatus {
  /// 无任何关系
  none,

  /// 我发出的申请，等待对方处理
  outgoingPending,

  /// 对方发给我的申请，等待我处理
  incomingPending,

  /// 已是好友
  accepted,
}

/// 一条好友关系记录 + 对方资料。
class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status; // pending | accepted
  final DateTime createdAt;
  final Profile? other; // 相对当前用户的"对方"资料

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.other,
  });

  FriendshipStatus statusFor(String myId) {
    if (status == 'accepted') return FriendshipStatus.accepted;
    return requesterId == myId
        ? FriendshipStatus.outgoingPending
        : FriendshipStatus.incomingPending;
  }

  static Friendship fromJson(Map<String, dynamic> json, String myId) {
    final requester = json['requester'] as Map<String, dynamic>?;
    final addressee = json['addressee'] as Map<String, dynamic>?;
    final requesterId = json['requester_id'] as String;
    final otherJson = requesterId == myId ? addressee : requester;
    return Friendship(
      id: json['id'] as String,
      requesterId: requesterId,
      addresseeId: json['addressee_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      other: otherJson != null ? Profile.fromJson(otherJson) : null,
    );
  }
}

class FriendService {
  final _client = Supabase.instance.client;
  final _blockService = BlockService();

  static const _select =
      '*, requester:profiles!friendships_requester_id_fkey(*), '
      'addressee:profiles!friendships_addressee_id_fkey(*)';

  /// 我的全部好友（已接受），按最近成为好友排序。
  Future<List<Friendship>> getFriends() async {
    final uid = requireUid(_client);
    final blockedIds = await _blockService.getBlockedIds();
    final data = await _client
        .from('friendships')
        .select(_select)
        .eq('status', 'accepted')
        .or('requester_id.eq.$uid,addressee_id.eq.$uid')
        .order('responded_at', ascending: false);
    return (data as List)
        .map((e) => Friendship.fromJson(e as Map<String, dynamic>, uid))
        .where((f) => f.other != null && !blockedIds.contains(f.other!.id))
        .toList();
  }

  /// 发给我的待处理申请。
  Future<List<Friendship>> getIncomingRequests() async {
    final uid = requireUid(_client);
    final blockedIds = await _blockService.getBlockedIds();
    final data = await _client
        .from('friendships')
        .select(_select)
        .eq('status', 'pending')
        .eq('addressee_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Friendship.fromJson(e as Map<String, dynamic>, uid))
        .where((f) => f.other != null && !blockedIds.contains(f.other!.id))
        .toList();
  }

  /// 我发出的待处理申请。
  Future<List<Friendship>> getOutgoingRequests() async {
    final uid = requireUid(_client);
    final data = await _client
        .from('friendships')
        .select(_select)
        .eq('status', 'pending')
        .eq('requester_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Friendship.fromJson(e as Map<String, dynamic>, uid))
        .toList();
  }

  /// 与某个用户之间的关系（无则 null）。
  Future<Friendship?> getFriendshipWith(String otherId) async {
    final uid = requireUid(_client);
    final data = await _client
        .from('friendships')
        .select(_select)
        .or(
          'and(requester_id.eq.$uid,addressee_id.eq.$otherId),'
          'and(requester_id.eq.$otherId,addressee_id.eq.$uid)',
        )
        .maybeSingle();
    if (data == null) return null;
    return Friendship.fromJson(data, uid);
  }

  /// 我的好友数量。
  Future<int> getFriendCount() async {
    final uid = requireUid(_client);
    final resp = await _client
        .from('friendships')
        .select()
        .eq('status', 'accepted')
        .or('requester_id.eq.$uid,addressee_id.eq.$uid')
        .count(CountOption.exact);
    return resp.count;
  }

  /// 发起好友申请。被拉黑/拉黑对方时抛 [BlockedUserInteractionException]。
  Future<void> sendRequest(String targetId) async {
    if (await _blockService.isEitherBlocked(targetId)) {
      throw const BlockedUserInteractionException();
    }
    await _client.from('friendships').insert({
      'requester_id': requireUid(_client),
      'addressee_id': targetId,
      'status': 'pending',
    });
  }

  /// 接受好友申请（仅被申请方可调，由 RLS 保证）。
  Future<void> acceptRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  /// 拒绝申请 / 取消我发出的申请 / 解除好友——都是删除这条关系。
  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  /// 订阅与我相关的好友关系变化（新申请/被接受/被删除），用于好友页实时刷新。
  RealtimeChannel subscribeToChanges(void Function() onChange) {
    final uid = requireUid(_client);
    return _client
        .channel('friendships:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) {
            final rec = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final requester = rec['requester_id'] as String?;
            final addressee = rec['addressee_id'] as String?;
            if (requester == uid || addressee == uid) onChange();
          },
        )
        .subscribe();
  }
}
