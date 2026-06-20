import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid, UserNotFoundException;
import '../models/profile.dart';
import 'local_cache.dart';

class ProfileService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
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
    final data = await _client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', requireUid(_client))
        .limit(20);
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  Future<void> followUser(String targetId) async {
    await _client.from('follows').insert({
      'follower_id': _userId,
      'following_id': targetId,
    });
  }

  Future<void> unfollowUser(String targetId) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', requireUid(_client))
        .eq('following_id', targetId);
  }

  Future<bool> isFollowing(String targetId) async {
    final data = await _client
        .from('follows')
        .select()
        .eq('follower_id', requireUid(_client))
        .eq('following_id', targetId)
        .maybeSingle();
    return data != null;
  }

  Future<List<Profile>> getFollowers(String userId) async {
    final data = await _client
        .from('follows')
        .select('profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId);
    return (data as List)
        .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<Profile>> getFollowing(String userId) async {
    final data = await _client
        .from('follows')
        .select('profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return (data as List)
        .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
        .toList();
  }
}
