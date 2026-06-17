import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final _client = Supabase.instance.client;

  Future<void> reportContent({
    required String targetType, // 'post', 'comment', 'message', 'user'
    required String targetId,
    required String reason,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Exception('Not authenticated');

    await _client.from('reports').insert({
      'reporter_id': me,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
  }
}
