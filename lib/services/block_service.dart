import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  final _client = Supabase.instance.client;

  Future<void> blockUser(String userId) async {
    final me = _client.auth.currentUser!.id;
    await _client.from('blocks').upsert({
      'blocker_id': me,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    final me = _client.auth.currentUser!.id;
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', userId);
  }

  Future<bool> isBlocked(String userId) async {
    final me = _client.auth.currentUser!.id;
    final data = await _client
        .from('blocks')
        .select()
        .eq('blocker_id', me)
        .eq('blocked_id', userId)
        .maybeSingle();
    return data != null;
  }

  Future<Set<String>> getBlockedIds() async {
    final me = _client.auth.currentUser!.id;
    final data = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', me);
    return {for (final row in data as List) row['blocked_id'] as String};
  }
}
