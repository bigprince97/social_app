import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 后台消息处理（必须是顶层函数）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 后台收到消息时静默处理，系统会自动显示通知
}

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _badgeChannel = MethodChannel('omega/app_badge');

  static const _androidChannel = AndroidNotificationChannel(
    'default',
    '默认通知',
    description: '社交通知',
    importance: Importance.high,
  );

  static const _callChannel = AndroidNotificationChannel(
    'calls',
    '来电',
    description: '语音/视频来电',
    importance: Importance.max,
  );

  static const _activeMediaChannel = AndroidNotificationChannel(
    'active_media',
    '通话和直播',
    description: '正在进行的通话或直播',
    importance: Importance.high,
    playSound: false,
  );

  static const _activeMediaNotificationId = 9001;

  // 前台聊天横幅：静音频道。带声音的通知会抢占音频焦点，打断正在
  // 播放的语音消息，因此聊天横幅不出声（playSound:false）。
  static const _chatChannel = AndroidNotificationChannel(
    'chat_silent',
    '聊天消息',
    description: '前台聊天横幅（静音）',
    importance: Importance.high,
    playSound: false,
  );

  /// 收到来电类推送时回调（前台/后台点开都会触发），由 HomeScreen 注册，
  /// 用 call_id 拉取通话并弹来电界面。
  static void Function(Map<String, dynamic> data)? _onCallPush;
  static Map<String, dynamic>? _pendingCallPush;

  static set onCallPush(void Function(Map<String, dynamic> data)? callback) {
    _onCallPush = callback;
    if (callback == null) {
      _pendingCallPush = null;
      return;
    }
    final pending = _pendingCallPush;
    if (pending != null) {
      _pendingCallPush = null;
      scheduleMicrotask(() => callback(pending));
    }
  }

  static void _dispatchCallPush(Map<String, dynamic> data) {
    final callback = _onCallPush;
    if (callback == null) {
      // 冷启动时推送可能早于 HomeScreen 完成注册，先暂存，注册后立即补弹。
      _pendingCallPush = Map<String, dynamic>.from(data);
      return;
    }
    callback(Map<String, dynamic>.from(data));
  }

  static VoidCallback? onActiveMediaTap;
  static void Function(
    String? postId,
    String? actorId,
    String type,
    String? conversationId,
  )?
  _onNotificationTap;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  static StreamSubscription<RemoteMessage>? _messageOpenedSub;
  static Timer? _tokenRetryTimer;

  static Future<void> initialize({
    required void Function(
      String? postId,
      String? actorId,
      String type,
      String? conversationId,
    )
    onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;

    // 注册后台处理器
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 请求权限
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 初始化本地通知
    await _initLocalNotifications(onNotificationTap);

    // iOS 前台不由系统直接弹 FCM 横幅：聊天类前台横幅统一走 realtime
    // (showChatBanner)，其余类型由 onMessage 弹本地通知，避免重复。
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // 保存 FCM token
    await _saveToken();
    _tokenRefreshSub ??= _messaging.onTokenRefresh.listen(_upsertToken);

    // 前台收到消息 → 本地通知。
    // 聊天消息跳过：前台聊天横幅由 home_screen 的 realtime 订阅负责
    // (更快、且能按"是否正在该会话页"精确抑制)，FCM 只负责后台。
    _foregroundMessageSub ??= FirebaseMessaging.onMessage.listen((msg) {
      // 来电：前台直接弹来电界面（兜底 realtime），不走系统通知
      if (msg.data['type'] == 'call') {
        _dispatchCallPush(msg.data);
        return;
      }
      final notif = msg.notification;
      if (notif == null) return;
      if (msg.data['type'] == 'chat') return;
      _localNotifications.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        payload: _buildPayload(msg.data),
      );
    });

    // 点击通知打开 app（后台 → 前台）
    _messageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data['type'] == 'call') {
        _dispatchCallPush(msg.data);
        return;
      }
      _handleTapWithCurrentCallback(msg.data);
    });

    // app 从终止状态被通知打开
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      if (initial.data['type'] == 'call') {
        _dispatchCallPush(initial.data);
      } else {
        _handleTapWithCurrentCallback(initial.data);
      }
    }
  }

  /// 前台聊天横幅(由 home_screen 的 realtime 订阅调用)
  static Future<void> showChatBanner({
    required String title,
    required String body,
    required String conversationId,
  }) async {
    await _localNotifications.show(
      conversationId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          tag: '$conversationId:foreground',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
          threadIdentifier: conversationId,
        ),
      ),
      payload: 'chat|||$conversationId',
    );
  }

  static Future<void> _initLocalNotifications(
    void Function(String?, String?, String, String?) onTap,
  ) async {
    // Android 创建通知频道
    if (Platform.isAndroid) {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_androidChannel);
      await android?.createNotificationChannel(_callChannel);
      await android?.createNotificationChannel(_activeMediaChannel);
      await android?.createNotificationChannel(_chatChannel);
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        final parts = response.payload!.split('|');
        final type = parts.isNotEmpty ? parts[0] : '';
        if (type == 'active_media') {
          onActiveMediaTap?.call();
          return;
        }
        String? part(int i) =>
            parts.length > i && parts[i].isNotEmpty ? parts[i] : null;
        (_onNotificationTap ?? onTap)(part(1), part(2), type, part(3));
      },
    );
  }

  static Future<void> showActiveMediaNotification({
    required String title,
    required String body,
    required bool isCall,
  }) async {
    await _localNotifications.show(
      _activeMediaNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _activeMediaChannel.id,
          _activeMediaChannel.name,
          channelDescription: _activeMediaChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: isCall,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'active_media',
    );
  }

  static Future<void> cancelActiveMediaNotification() =>
      _localNotifications.cancel(_activeMediaNotificationId);

  static Future<void> syncAppIconBadge(int count) async {
    if (!Platform.isIOS) return;
    try {
      await _badgeChannel.invokeMethod('setBadgeCount', {
        'count': count < 0 ? 0 : count,
      });
    } catch (e) {
      debugPrint('Failed to sync app icon badge: $e');
    }
  }

  static const _notifChannel = MethodChannel('omega/notifications');

  /// 清除通知栏里属于该会话的所有已达通知(进入会话页时调用)。
  /// iOS 按推送的 thread-id 匹配;Android 按通知 tag 的会话前缀匹配。
  static Future<void> clearConversationNotifications(
    String conversationId,
  ) async {
    if (kIsWeb) return;
    final localNotificationId = conversationId.hashCode;

    try {
      // 前台 realtime 横幅使用固定 id；无论平台，进入会话先直接清掉它。
      await _localNotifications.cancel(localNotificationId);
    } catch (e) {
      debugPrint('Failed to clear local conversation banner: $e');
    }

    try {
      // 原生层负责清理系统直接展示的 FCM 通知：iOS 按 thread-id，
      // Android 按「会话 id:消息 id」tag。这样不会误删其他会话通知。
      await _notifChannel.invokeMethod('clearThread', {
        'threadId': conversationId,
        'localNotificationId': localNotificationId,
      });
    } catch (e) {
      debugPrint('Failed to clear native conversation notifications: $e');
    }

    if (Platform.isAndroid) {
      try {
        // 插件层再做一次兜底，兼容升级前已到达通知和部分系统实现。
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final actives = await android?.getActiveNotifications() ?? const [];
        for (final n in actives) {
          final tag = n.tag;
          final id = n.id;
          if (id != null && tag != null && tag.startsWith('$conversationId:')) {
            await _localNotifications.cancel(id, tag: tag);
          }
        }
      } catch (e) {
        debugPrint('Failed to clear fallback conversation notifications: $e');
      }
    }
  }

  static String _buildPayload(Map<String, dynamic> data) =>
      '${data['type'] ?? ''}|${data['post_id'] ?? ''}|${data['actor_id'] ?? ''}|${data['conversation_id'] ?? ''}';

  static void _handleTap(
    Map<String, dynamic> data,
    void Function(String?, String?, String, String?) onTap,
  ) {
    final type = data['type'] as String? ?? '';
    final postId = data['post_id'] as String?;
    final actorId = data['actor_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    onTap(
      postId?.isNotEmpty == true ? postId : null,
      actorId?.isNotEmpty == true ? actorId : null,
      type,
      conversationId?.isNotEmpty == true ? conversationId : null,
    );
  }

  static void _handleTapWithCurrentCallback(Map<String, dynamic> data) {
    final onTap = _onNotificationTap;
    if (onTap == null) return;
    _handleTap(data, onTap);
  }

  static Future<void> _saveToken({int attempt = 0}) async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await _waitForApnsToken();
        if (apnsToken == null) {
          throw StateError('APNs token is not ready.');
        }
      }
      final token = await _messaging.getToken();
      if (token != null) await _upsertToken(token);
    } catch (e) {
      debugPrint('Push token registration failed: $e');
      if (attempt >= 5) return;
      _tokenRetryTimer?.cancel();
      _tokenRetryTimer = Timer(Duration(seconds: 2 + attempt * 2), () {
        _saveToken(attempt: attempt + 1);
      });
    }
  }

  static Future<String?> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  static Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('push_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, onConflict: 'user_id, token');
  }

  static Future<void> deleteToken({String? userId}) async {
    try {
      final token = await _messaging.getToken();
      final ownerId = userId ?? Supabase.instance.client.auth.currentUser?.id;
      if (token != null && ownerId != null) {
        await Supabase.instance.client
            .from('push_tokens')
            .delete()
            .eq('user_id', ownerId)
            .eq('token', token);
      }
      await _messaging.deleteToken();
    } catch (e) {
      // iOS: APNS token 未就绪 / 未配置 APNs，getToken 会抛 apns-token-not-set；忽略
    }
  }
}
