import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

import 'package:social_app/config/supabase_config.dart';

class _LoadClient {
  final int number;
  final String userId;
  final SupabaseClient client;
  final Set<String> received = <String>{};
  final Set<String> fetched = <String>{};
  final Set<String> pendingIds = <String>{};
  final List<Duration> latencies = <Duration>[];
  final List<Future<void>> fetches = <Future<void>>[];
  Timer? fetchTimer;
  int fetchRequests = 0;
  int fetchFailures = 0;

  _LoadClient({
    required this.number,
    required this.userId,
    required this.client,
  });
}

class _TokenIdentity {
  final String userId;
  final String accessToken;

  const _TokenIdentity({required this.userId, required this.accessToken});
}

Future<void> main(List<String> args) async {
  final clientsCount = _intArg(args, '--clients', fallback: 1);
  final messagesCount = _intArg(args, '--messages', fallback: 1);
  final intervalMs = _intArg(args, '--interval-ms', fallback: 1000);
  final connectBatch = _intArg(args, '--connect-batch', fallback: 5);
  final connectDelayMs = _intArg(args, '--connect-delay-ms', fallback: 0);
  final preSendSeconds = _intArg(args, '--pre-send-seconds', fallback: 0);
  final settleSeconds = _intArg(args, '--settle-seconds', fallback: 8);
  final groupId = Platform.environment['OMEGA_LOAD_GROUP_ID'];
  final password = Platform.environment['OMEGA_LOAD_PASSWORD'];
  if (groupId == null || password == null) {
    stderr.writeln('缺少 OMEGA_LOAD_GROUP_ID 或 OMEGA_LOAD_PASSWORD');
    exitCode = 64;
    return;
  }
  if (clientsCount < 1 || clientsCount > 500 || messagesCount < 1) {
    stderr.writeln('clients 必须为 1..500，messages 必须大于 0');
    exitCode = 64;
    return;
  }

  final sharedHttp = http.Client();
  final sharedJson = YAJsonIsolate(debugName: 'omega-load-json');
  await sharedJson.initialize();
  final tokenPool = await _loadTokenPool(sharedHttp);
  final loadClients = <_LoadClient>[];
  final sentAt = <String, DateTime>{};
  final sentIds = <String>[];
  final sendFailures = <String>[];
  var subscriptionFailures = 0;

  try {
    stdout.writeln('登录并连接 $clientsCount 个隔离测试用户…');
    for (var start = 1; start <= clientsCount; start += connectBatch) {
      final end = (start + connectBatch - 1).clamp(1, clientsCount).toInt();
      final batch = await Future.wait([
        for (var number = start; number <= end; number++)
          _createClient(
            number: number,
            password: password,
            tokenIdentity: tokenPool.isEmpty
                ? null
                : tokenPool[(number - 1) % tokenPool.length],
            sharedHttp: sharedHttp,
            sharedJson: sharedJson,
          ),
      ]);
      loadClients.addAll(batch);
      stdout.writeln('已登录 ${loadClients.length}/$clientsCount');
    }

    for (var start = 0; start < loadClients.length; start += connectBatch) {
      final end = (start + connectBatch).clamp(0, loadClients.length).toInt();
      final subscriptions = <Future<void>>[];
      for (final loadClient in loadClients.sublist(start, end)) {
        subscriptions.add(
          _subscribeWithRetry(
            loadClient,
            groupId: groupId,
            sentAt: sentAt,
          ).catchError((Object error) {
            subscriptionFailures++;
            stderr.writeln('测试用户 ${loadClient.number} 订阅失败：$error');
          }),
        );
      }
      await Future.wait(subscriptions);
      stdout.writeln('已订阅 $end/$clientsCount');
      if (end < loadClients.length && connectDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: connectDelayMs));
      }
    }

    if (subscriptionFailures > 0) {
      throw StateError('$subscriptionFailures 个私有频道订阅失败');
    }

    if (preSendSeconds > 0) {
      stdout.writeln('全部订阅就绪，等待 ${preSendSeconds}s 后开始消息阶段…');
      await Future<void>.delayed(Duration(seconds: preSendSeconds));
    }

    stdout.writeln(
      '开始发送 $messagesCount 条消息，间隔 ${intervalMs}ms，'
      '理论事件数 ${clientsCount * messagesCount}…',
    );
    for (var index = 0; index < messagesCount; index++) {
      final sender = loadClients[index % loadClients.length];
      final messageId = const Uuid().v4();
      sentIds.add(messageId);
      sentAt[messageId] = DateTime.now();
      try {
        await sender.client
            .from('messages')
            .insert({
              'id': messageId,
              'conversation_id': groupId,
              'sender_id': sender.userId,
              'content': '__codex_load_${index + 1}__',
              'message_type': 'text',
              'payload': {
                'load_test': true,
                'load_test_run': 'chat_broadcast_20260711',
                'sequence': index + 1,
              },
            })
            .select('id')
            .single();
      } catch (error) {
        sendFailures.add('$messageId: $error');
      }
      if (index + 1 < messagesCount) {
        await Future<void>.delayed(Duration(milliseconds: intervalMs));
      }
    }

    await Future<void>.delayed(Duration(seconds: settleSeconds));
    for (final loadClient in loadClients) {
      loadClient.fetchTimer?.cancel();
      if (loadClient.pendingIds.isNotEmpty) {
        loadClient.fetches.add(_flushFetch(loadClient));
      }
    }
    await Future.wait([
      for (final loadClient in loadClients) ...loadClient.fetches,
    ]);

    final expected = clientsCount * (messagesCount - sendFailures.length);
    final delivered = loadClients.fold<int>(
      0,
      (sum, item) => sum + item.received.intersection(sentIds.toSet()).length,
    );
    final fetched = loadClients.fold<int>(
      0,
      (sum, item) => sum + item.fetched.intersection(sentIds.toSet()).length,
    );
    final allLatencies = <Duration>[
      for (final item in loadClients) ...item.latencies,
    ]..sort();
    final minimumPerClient = loadClients
        .map((item) => item.received.intersection(sentIds.toSet()).length)
        .fold<int>(messagesCount, (a, b) => a < b ? a : b);
    final totalFetchRequests = loadClients.fold<int>(
      0,
      (sum, item) => sum + item.fetchRequests,
    );
    final totalFetchFailures = loadClients.fold<int>(
      0,
      (sum, item) => sum + item.fetchFailures,
    );
    final deliveryRate = expected == 0 ? 0.0 : delivered / expected;
    final fetchRate = expected == 0 ? 0.0 : fetched / expected;

    final summary = <String, Object?>{
      'clients': clientsCount,
      'messages_requested': messagesCount,
      'messages_sent': messagesCount - sendFailures.length,
      'expected_deliveries': expected,
      'broadcast_deliveries': delivered,
      'delivery_rate': double.parse(deliveryRate.toStringAsFixed(6)),
      'rls_fetch_deliveries': fetched,
      'rls_fetch_rate': double.parse(fetchRate.toStringAsFixed(6)),
      'minimum_messages_per_client': minimumPerClient,
      'p50_ms': _percentileMs(allLatencies, 0.50),
      'p95_ms': _percentileMs(allLatencies, 0.95),
      'p99_ms': _percentileMs(allLatencies, 0.99),
      'fetch_requests': totalFetchRequests,
      'fetch_failures': totalFetchFailures,
      'send_failures': sendFailures.length,
      'subscription_failures': subscriptionFailures,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));

    if (sendFailures.isNotEmpty ||
        deliveryRate < 0.999 ||
        fetchRate < 0.999 ||
        minimumPerClient < messagesCount - sendFailures.length) {
      exitCode = 2;
    }
  } finally {
    stdout.writeln('关闭测试连接…');
    for (final loadClient in loadClients) {
      loadClient.fetchTimer?.cancel();
      await loadClient.client.dispose();
    }
    sharedHttp.close();
    await sharedJson.dispose();
  }
}

Future<_LoadClient> _createClient({
  required int number,
  required String password,
  required _TokenIdentity? tokenIdentity,
  required http.Client sharedHttp,
  required YAJsonIsolate sharedJson,
}) async {
  late final String token;
  late final String userId;
  if (tokenIdentity != null) {
    token = tokenIdentity.accessToken;
    userId = tokenIdentity.userId;
  } else {
    final email =
        'omega-load-20260711-${number.toString().padLeft(4, '0')}'
        '@example.invalid';
    final response = await sharedHttp
        .post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': supabasePublishableKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    final user = body['user'] as Map<String, dynamic>?;
    final authenticatedUserId = user?['id'] as String?;
    if (response.statusCode != 200 ||
        accessToken == null ||
        authenticatedUserId == null) {
      throw StateError(
        '测试用户 $number 登录失败：${body['msg'] ?? response.statusCode}',
      );
    }
    token = accessToken;
    userId = authenticatedUserId;
  }

  final client = SupabaseClient(
    supabaseUrl,
    supabasePublishableKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    accessToken: () async => token,
    httpClient: sharedHttp,
    isolate: sharedJson,
  );
  await client.realtime.setAuth(token);
  return _LoadClient(number: number, userId: userId, client: client);
}

Future<List<_TokenIdentity>> _loadTokenPool(http.Client client) async {
  final accessRaw = Platform.environment['OMEGA_LOAD_ACCESS_SESSIONS'];
  if (accessRaw != null && accessRaw.isNotEmpty) {
    final sessions = (jsonDecode(accessRaw) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(
          (item) => _TokenIdentity(
            userId: item['user_id'] as String,
            accessToken: item['access_token'] as String,
          ),
        )
        .toList();
    stdout.writeln('已准备 ${sessions.length} 个短期独立身份，会循环用于压力连接');
    return sessions;
  }
  final raw = Platform.environment['OMEGA_LOAD_REFRESH_SESSIONS'];
  if (raw == null || raw.isEmpty) return const [];
  final sessions = (jsonDecode(raw) as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final result = <_TokenIdentity>[];
  const batchSize = 5;
  for (var start = 0; start < sessions.length; start += batchSize) {
    final end = (start + batchSize).clamp(0, sessions.length).toInt();
    final batch = await Future.wait(
      sessions.sublist(start, end).map((session) async {
        final response = await client
            .post(
              Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
              headers: {
                'apikey': supabasePublishableKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'refresh_token': session['refresh_token']}),
            )
            .timeout(const Duration(seconds: 20));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = body['access_token'] as String?;
        final user = body['user'] as Map<String, dynamic>?;
        final userId = user?['id'] as String?;
        if (response.statusCode != 200 ||
            accessToken == null ||
            userId == null) {
          throw StateError('刷新测试会话失败：${body['msg'] ?? response.statusCode}');
        }
        return _TokenIdentity(userId: userId, accessToken: accessToken);
      }),
    );
    result.addAll(batch);
  }
  stdout.writeln('已准备 ${result.length} 个独立身份，会循环用于压力连接');
  return result;
}

Future<void> _subscribe(
  _LoadClient loadClient, {
  required String groupId,
  required Map<String, DateTime> sentAt,
}) async {
  final ready = Completer<void>();
  final channel = loadClient.client.channel(
    'conversation:$groupId:messages',
    opts: const RealtimeChannelConfig(private: true),
  );
  channel
      .onBroadcast(
        event: 'message_changed',
        callback: (frame) {
          final raw = frame['payload'];
          if (raw is! Map) {
            return;
          }
          final payload = Map<String, dynamic>.from(raw);
          final messageId = payload['message_id'] as String?;
          if (messageId == null || payload['conversation_id'] != groupId) {
            return;
          }
          if (loadClient.received.add(messageId)) {
            final started = sentAt[messageId];
            if (started != null) {
              loadClient.latencies.add(DateTime.now().difference(started));
            }
          }
          loadClient.pendingIds.add(messageId);
          loadClient.fetchTimer ??= Timer(
            const Duration(milliseconds: 100),
            () {
              loadClient.fetchTimer = null;
              loadClient.fetches.add(_flushFetch(loadClient));
            },
          );
        },
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !ready.isCompleted) {
          ready.complete();
        } else if ((status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut ||
                status == RealtimeSubscribeStatus.closed) &&
            !ready.isCompleted) {
          ready.completeError(StateError('订阅失败: $status $error'));
        }
      });
  try {
    await ready.future.timeout(const Duration(seconds: 30));
  } catch (_) {
    await channel.unsubscribe();
    rethrow;
  }
}

Future<void> _subscribeWithRetry(
  _LoadClient loadClient, {
  required String groupId,
  required Map<String, DateTime> sentAt,
}) async {
  const retryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  for (var attempt = 0; ; attempt++) {
    try {
      await _subscribe(loadClient, groupId: groupId, sentAt: sentAt);
      return;
    } catch (_) {
      if (attempt >= retryDelays.length) rethrow;
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }
}

Future<void> _flushFetch(_LoadClient loadClient) async {
  if (loadClient.pendingIds.isEmpty) return;
  final ids = loadClient.pendingIds.toList();
  loadClient.pendingIds.clear();
  loadClient.fetchRequests++;
  try {
    final rows = await loadClient.client
        .from('messages')
        .select('*, profiles(*)')
        .inFilter('id', ids);
    for (final row in rows as List) {
      final id = (row as Map)['id'] as String?;
      if (id != null) loadClient.fetched.add(id);
    }
  } catch (_) {
    loadClient.fetchFailures++;
  }
}

int _intArg(List<String> args, String name, {required int fallback}) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return fallback;
  }
  return int.tryParse(args[index + 1]) ?? fallback;
}

int? _percentileMs(List<Duration> values, double percentile) {
  if (values.isEmpty) return null;
  final index = ((values.length - 1) * percentile).round();
  return values[index].inMilliseconds;
}
