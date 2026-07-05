import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid, UserNotFoundException;
import '../models/profile.dart';
import 'block_service.dart';
import 'local_cache.dart';

class ProfileService {
  final _client = Supabase.instance.client;
  final _blockService = BlockService();
  final _cache = LocalCache.instance;

  Future<Profile> getProfile(String userId) async {
    final cacheKey = 'profile_$userId';
    try {
      // maybeSingle：0 行不抛异常，便于区分"已注销"与"网络错误"。
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) {
        // 查询成功但无此用户 = 账号已注销/不存在：清掉旧缓存，避免显示幽灵资料。
        await _cache.remove(cacheKey);
        throw const UserNotFoundException();
      }
      await _cache.write(cacheKey, data);
      return Profile.fromJson(data);
    } catch (e) {
      if (e is UserNotFoundException) rethrow;
      // 网络错误 → 用上次缓存的资料，避免"用户不存在"误导。
      final cached = await _cache.read(cacheKey);
      if (cached is Map) {
        return Profile.fromJson(Map<String, dynamic>.from(cached));
      }
      rethrow;
    }
  }

  Future<Profile> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', requireUid(_client))
        .select()
        .single();
    return Profile.fromJson(data);
  }

  Future<List<Profile>> searchUsers(String query) async {
    final blockedIds = await _blockService.getBlockedIds();
    final data = await _client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', requireUid(_client))
        .limit(20);
    return (data as List)
        .map((e) => Profile.fromJson(e))
        .where((profile) => !blockedIds.contains(profile.id))
        .toList();
  }

}

class BlockedUserInteractionException implements Exception {
  const BlockedUserInteractionException();

  @override
  String toString() => 'BlockedUserInteractionException';
}
