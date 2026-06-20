import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import '../models/profile.dart';

class BlockService {
  final _client = Supabase.instance.client;

  /// 我拉黑的用户（含资料），用于「已拉黑用户」管理页。
  Future<List<Profile>> getBlockedProfiles() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return [];
    final rows = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', me)
        .order('created_at', ascending: false);
    final ids =
        (rows as List).map((r) => r['blocked_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles =
        await _client.from('profiles').select().inFilter('id', ids);
    return (profiles as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> blockUser(String userId) async {
    final me = requireUid(_client);
    await _client.from('blocks').upsert({
      'blocker_id': me,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    final me = requireUid(_client);
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', userId);
  }

  Future<bool> isBlocked(String userId) async {
    final me = requireUid(_client);
    final data = await _client
        .from('blocks')
        .select()
        .eq('blocker_id', me)
        .eq('blocked_id', userId)
        .maybeSingle();
    return data != null;
  }

  Future<Set<String>> getBlockedIds() async {
    final me = requireUid(_client);
    final data = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', me);
    return {for (final row in data as List) row['blocked_id'] as String};
  }
}
