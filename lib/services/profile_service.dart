import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<Profile> getProfile(String userId) async {
    final data =
        await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
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
        .eq('id', _userId!)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  Future<List<Profile>> searchUsers(String query) async {
    final data = await _client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', _userId!)
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
        .eq('follower_id', _userId!)
        .eq('following_id', targetId);
  }

  Future<bool> isFollowing(String targetId) async {
    final data = await _client
        .from('follows')
        .select()
        .eq('follower_id', _userId!)
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
