import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<AppNotification>> getNotifications({int limit = 30}) async {
    final data = await _client
        .from('notifications')
        .select('*, profiles!actor_id(*)')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final resp = await _client
        .from('notifications')
        .select()
        .eq('user_id', _userId!)
        .eq('is_read', false)
        .count(CountOption.exact);
    return resp.count;
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId!)
        .eq('is_read', false);
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  RealtimeChannel subscribeToNotifications(
    void Function(AppNotification) onNew,
  ) {
    return _client
        .channel('notifications:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final full = await _client
                .from('notifications')
                .select('*, profiles!actor_id(*)')
                .eq('id', row['id'] as String)
                .single();
            onNew(AppNotification.fromJson(full));
          },
        )
        .subscribe();
  }
}
