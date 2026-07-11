import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

import 'package:social_app/config/supabase_config.dart';

class _TokenIdentity {
  final String userId;
  final String accessToken;

  const _TokenIdentity({required this.userId, required this.accessToken});
}

class _ViewerClient {
  final int number;
  final SupabaseClient client;
  int receivedUpdates = 0;

  _ViewerClient({required this.number, required this.client});
}

Future<void> main(List<String> args) async {
  final viewersCount = _intArg(args, '--viewers', fallback: 100);
  final updatesCount = _intArg(args, '--updates', fallback: 4);
  final updateIntervalMs = _intArg(
    args,
    '--update-interval-ms',
    fallback: 10000,
  );
  final connectBatch = _intArg(args, '--connect-batch', fallback: 20);
  final connectDelayMs = _intArg(args, '--connect-delay-ms', fallback: 500);
  final callId = Platform.environment['OMEGA_LOAD_CALL_ID'];
  final rawSessions = Platform.environment['OMEGA_LOAD_ACCESS_SESSIONS'];
  if (callId == null || rawSessions == null || rawSessions.isEmpty) {
    stderr.writeln('缺少 OMEGA_LOAD_CALL_ID 或 OMEGA_LOAD_ACCESS_SESSIONS');
    exitCode = 64;
    return;
  }

  final identities = (jsonDecode(rawSessions) as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .map(
        (item) => _TokenIdentity(
          userId: item['user_id'] as String,
          accessToken: item['access_token'] as String,
        ),
      )
      .toList();
  final sharedHttp = http.Client();
  final sharedJson = YAJsonIsolate(debugName: 'omega-live-status-load-json');
  await sharedJson.initialize();
  final viewers = <_ViewerClient>[];
  var subscriptionFailures = 0;
  var updateFailures = 0;
  var successfulUpdates = 0;

  try {
    for (var number = 1; number <= viewersCount; number++) {
      final identity = identities[(number - 1) % identities.length];
      final client = SupabaseClient(
        supabaseUrl,
        supabasePublishableKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        accessToken: () async => identity.accessToken,
        httpClient: sharedHttp,
        isolate: sharedJson,
      );
      await client.realtime.setAuth(identity.accessToken);
      viewers.add(_ViewerClient(number: number, client: client));
    }

    for (var start = 0; start < viewers.length; start += connectBatch) {
      final end = (start + connectBatch).clamp(0, viewers.length).toInt();
      await Future.wait([
        for (final viewer in viewers.sublist(start, end))
          _subscribeWithRetry(viewer, callId).catchError((Object error) {
            subscriptionFailures++;
            stderr.writeln('直播观众 ${viewer.number} 订阅失败：$error');
          }),
      ]);
      stdout.writeln('直播状态已订阅 $end/$viewersCount');
      if (end < viewers.length && connectDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: connectDelayMs));
      }
    }

    if (subscriptionFailures > 0) {
      throw StateError('$subscriptionFailures 个直播状态订阅失败');
    }

    for (var index = 0; index < updatesCount; index++) {
      try {
        await viewers.first.client
            .from('calls')
            .update({'last_heartbeat_at': DateTime.now().toIso8601String()})
            .eq('id', callId)
            .select('id')
            .single();
        successfulUpdates++;
      } catch (error) {
        updateFailures++;
        stderr.writeln('直播心跳 ${index + 1} 更新失败：$error');
      }
      if (index + 1 < updatesCount) {
        await Future<void>.delayed(Duration(milliseconds: updateIntervalMs));
      }
    }

    await Future<void>.delayed(const Duration(seconds: 10));
    final expected = viewersCount * successfulUpdates;
    final received = viewers.fold<int>(
      0,
      (sum, viewer) => sum + viewer.receivedUpdates,
    );
    final minimumPerViewer = viewers
        .map((viewer) => viewer.receivedUpdates)
        .fold<int>(successfulUpdates, (a, b) => a < b ? a : b);
    final deliveryRate = expected == 0 ? 0.0 : received / expected;
    final summary = <String, Object>{
      'viewers': viewersCount,
      'heartbeat_updates_requested': updatesCount,
      'heartbeat_updates_succeeded': successfulUpdates,
      'expected_status_deliveries': expected,
      'status_deliveries': received,
      'delivery_rate': double.parse(deliveryRate.toStringAsFixed(6)),
      'minimum_updates_per_viewer': minimumPerViewer,
      'subscription_failures': subscriptionFailures,
      'update_failures': updateFailures,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
    if (updateFailures > 0 ||
        deliveryRate < 0.999 ||
        minimumPerViewer < successfulUpdates) {
      exitCode = 2;
    }
  } finally {
    for (final viewer in viewers) {
      await viewer.client.dispose();
    }
    sharedHttp.close();
    await sharedJson.dispose();
  }
}

Future<void> _subscribeWithRetry(_ViewerClient viewer, String callId) async {
  const retryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  for (var attempt = 0; ; attempt++) {
    final ready = Completer<void>();
    final channel = viewer.client.channel('call_status:$callId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (_) => viewer.receivedUpdates++,
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed &&
              !ready.isCompleted) {
            ready.complete();
          } else if ((status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut ||
                  status == RealtimeSubscribeStatus.closed) &&
              !ready.isCompleted) {
            ready.completeError(StateError('$status $error'));
          }
        });
    try {
      await ready.future.timeout(const Duration(seconds: 30));
      return;
    } catch (_) {
      await channel.unsubscribe();
      if (attempt >= retryDelays.length) rethrow;
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }
}

int _intArg(List<String> args, String name, {required int fallback}) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return fallback;
  return int.tryParse(args[index + 1]) ?? fallback;
}
