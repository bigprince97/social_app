import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'call_service.dart';
import 'push_notification_service.dart';

enum ActiveMediaKind { call, livestream }

class ActiveMediaSessionController extends ChangeNotifier {
  ActiveMediaSessionController._();

  static final instance = ActiveMediaSessionController._();

  ActiveMediaSession? _session;

  ActiveMediaSession? get session => _session;

  ActiveMediaSession startCall({
    required CallInfo call,
    required String livekitUrl,
    required String livekitToken,
    required String displayName,
  }) {
    final existing = _session;
    if (existing != null && existing.call.id == call.id && !existing.ended) {
      return existing;
    }
    unawaited(existing?.end());
    final next = ActiveMediaSession._call(
      call: call,
      livekitUrl: livekitUrl,
      livekitToken: livekitToken,
      displayName: displayName,
    );
    _session = next;
    notifyListeners();
    return next;
  }

  ActiveMediaSession startLivestream({
    required CallInfo call,
    required String livekitUrl,
    required String livekitToken,
    required bool isHost,
    required bool canManageLivestream,
    required String groupName,
  }) {
    final existing = _session;
    if (existing != null && existing.call.id == call.id && !existing.ended) {
      return existing;
    }
    unawaited(existing?.end());
    final next = ActiveMediaSession._livestream(
      call: call,
      livekitUrl: livekitUrl,
      livekitToken: livekitToken,
      isHost: isHost,
      canManageLivestream: canManageLivestream,
      groupName: groupName,
    );
    _session = next;
    notifyListeners();
    return next;
  }

  void _clear(ActiveMediaSession session) {
    if (identical(_session, session)) {
      _session = null;
      notifyListeners();
    }
  }

  void _notifySessionChanged() => notifyListeners();
}

class ActiveMediaSession extends ChangeNotifier {
  final kind = ValueNotifier<int>(0);
  final CallService _callService = CallService();

  final ActiveMediaKind mediaKind;
  final CallInfo call;
  final String livekitUrl;
  final String livekitToken;
  final String displayName;
  final String groupName;
  final bool isHost;
  final bool canManageLivestream;

  late final Room room;
  EventsListener<RoomEvent>? _listener;
  RealtimeChannel? _statusChannel;
  Timer? _ringTimeout;
  Timer? _livestreamHeartbeatTimer;

  final List<RemoteParticipant> remoteParticipants = [];

  bool connected = false;
  bool micEnabled = false;
  bool cameraEnabled = false;
  bool speakerOn = true;
  bool minimized = false;
  bool pageVisible = false;
  bool ended = false;
  bool _connecting = false;
  bool _callLogged = false;
  String status;
  DateTime? connectedAt;

  ActiveMediaSession._call({
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.displayName,
  }) : mediaKind = ActiveMediaKind.call,
       groupName = '',
       isHost = false,
       canManageLivestream = false,
       status = call.status {
    micEnabled = true;
    cameraEnabled = call.callType == 'video';
    _createRoom();
  }

  ActiveMediaSession._livestream({
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.isHost,
    required this.canManageLivestream,
    required this.groupName,
  }) : mediaKind = ActiveMediaKind.livestream,
       displayName = '',
       status = call.status {
    micEnabled = false;
    cameraEnabled = false;
    _createRoom();
  }

  bool get isCall => mediaKind == ActiveMediaKind.call;
  bool get isLivestream => mediaKind == ActiveMediaKind.livestream;
  bool get isVideoCall => call.callType == 'video';
  int get viewerCount => remoteParticipants.length + (connected ? 1 : 0);

  List<Participant> get participants => [
    if (room.localParticipant != null) room.localParticipant!,
    ...remoteParticipants,
  ];

  void _createRoom() {
    room = Room(
      roomOptions: RoomOptions(
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          noiseSuppression: true,
        ),
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
        ),
      ),
    );
  }

  Future<void> connect() async {
    if (_connecting || connected || ended) return;
    _connecting = true;
    if (isCall) {
      await _connectCall();
    } else {
      await _connectLivestream();
    }
  }

  Future<void> _connectCall() async {
    _listener = room.createListener()
      ..on<ParticipantConnectedEvent>((e) {
        connectedAt ??= DateTime.now();
        _addRemoteParticipant(e.participant);
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        _removeRemoteParticipant(e.participant.sid);
        if (!ended && connectedAt != null && remoteParticipants.isEmpty) {
          unawaited(end(remote: true));
        }
      })
      ..on<TrackSubscribedEvent>((_) => _changed())
      ..on<TrackUnsubscribedEvent>((_) => _changed())
      ..on<RoomDisconnectedEvent>((_) {
        if (!ended) unawaited(end());
      });

    _statusChannel = _callService.subscribeToCallStatus(
      call.id,
      _handleRemoteStatus,
    );

    await room.connect(livekitUrl, livekitToken);
    await room.localParticipant?.setMicrophoneEnabled(true);
    if (cameraEnabled) {
      await room.localParticipant?.setCameraEnabled(true);
    }
    _syncRemoteSnapshot();
    connected = true;
    if (remoteParticipants.isNotEmpty) connectedAt ??= DateTime.now();
    _scheduleRingTimeout();
    _changed();
  }

  Future<void> _connectLivestream() async {
    _listener = room.createListener()
      ..on<ParticipantConnectedEvent>((e) {
        _addRemoteParticipant(e.participant);
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        _removeRemoteParticipant(e.participant.sid);
      })
      ..on<TrackSubscribedEvent>((_) => _changed())
      ..on<TrackUnsubscribedEvent>((_) => _changed())
      ..on<TrackMutedEvent>((_) => _changed())
      ..on<TrackUnmutedEvent>((_) => _changed())
      ..on<LocalTrackPublishedEvent>((_) => _changed())
      ..on<TrackPublishedEvent>((_) => _changed())
      ..on<TrackUnpublishedEvent>((_) => _changed())
      ..on<RoomDisconnectedEvent>((_) {
        if (!ended) unawaited(leaveLivestream());
      });

    _statusChannel = _callService.subscribeToCallStatus(
      call.id,
      _handleRemoteStatus,
    );

    await room.connect(livekitUrl, livekitToken);
    _syncRemoteSnapshot();
    if (isHost) {
      unawaited(_callService.acceptCall(call.id));
    }
    connected = true;
    _startLivestreamHeartbeat();
    _changed();
  }

  void _scheduleRingTimeout() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != call.callerId) return;
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 60), () {
      if (!ended && status == 'ringing') unawaited(end());
    });
  }

  void _handleRemoteStatus(String nextStatus) {
    if (ended) return;
    status = nextStatus;
    _changed();
    if (nextStatus == 'declined' ||
        nextStatus == 'ended' ||
        nextStatus == 'missed') {
      unawaited(end(remote: true));
    }
  }

  void _syncRemoteSnapshot() {
    for (final p in room.remoteParticipants.values) {
      if (!remoteParticipants.any((x) => x.sid == p.sid)) {
        remoteParticipants.add(p);
      }
    }
  }

  void _addRemoteParticipant(RemoteParticipant participant) {
    if (!remoteParticipants.any((p) => p.sid == participant.sid)) {
      remoteParticipants.add(participant);
    }
    _changed();
  }

  void _removeRemoteParticipant(String sid) {
    remoteParticipants.removeWhere((p) => p.sid == sid);
    _changed();
  }

  void minimize() {
    if (ended) return;
    minimized = true;
    pageVisible = false;
    unawaited(showSystemNotification());
    ActiveMediaSessionController.instance._notifySessionChanged();
    _changed();
  }

  void restore() {
    if (ended) return;
    minimized = false;
    pageVisible = true;
    unawaited(PushNotificationService.cancelActiveMediaNotification());
    ActiveMediaSessionController.instance._notifySessionChanged();
    _changed();
  }

  void markPageHidden() {
    if (ended || minimized) return;
    pageVisible = false;
    ActiveMediaSessionController.instance._notifySessionChanged();
    _changed();
  }

  Future<void> showSystemNotification() {
    if (ended) return Future<void>.value();
    final title = switch (mediaKind) {
      ActiveMediaKind.call => isVideoCall ? '视频通话中' : '语音通话中',
      ActiveMediaKind.livestream => isHost ? '正在直播' : '正在观看直播',
    };
    final body = switch (mediaKind) {
      ActiveMediaKind.call => displayName.isNotEmpty ? displayName : '点击返回通话',
      ActiveMediaKind.livestream => groupName.isNotEmpty ? groupName : '点击返回直播',
    };
    return PushNotificationService.showActiveMediaNotification(
      title: title,
      body: '$body · 点击返回',
      isCall: isCall,
    );
  }

  Future<void> toggleMic() async {
    await room.localParticipant?.setMicrophoneEnabled(!micEnabled);
    micEnabled = !micEnabled;
    _changed();
  }

  Future<void> toggleCamera() async {
    await room.localParticipant?.setCameraEnabled(!cameraEnabled);
    cameraEnabled = !cameraEnabled;
    _changed();
  }

  Future<void> setSpeaker(bool enabled) async {
    speakerOn = enabled;
    _changed();
  }

  Future<void> flipCamera(CameraPosition cameraPosition) async {
    final pub = room.localParticipant?.videoTrackPublications.firstOrNull;
    final track = pub?.track;
    if (track != null) {
      await track.restartTrack(
        CameraCaptureOptions(cameraPosition: cameraPosition),
      );
      _changed();
    }
  }

  Future<void> leaveLivestream() {
    if (!isLivestream) return end(remote: true);
    return end(remote: true);
  }

  Future<void> closeLivestream() {
    if (!isLivestream) return end();
    return end(closeRemoteCall: true);
  }

  void _startLivestreamHeartbeat() {
    if (!isLivestream || ended) return;
    unawaited(_callService.markLivestreamHeartbeat(call.id));
    _livestreamHeartbeatTimer?.cancel();
    _livestreamHeartbeatTimer = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) {
      if (!ended) unawaited(_callService.markLivestreamHeartbeat(call.id));
    });
  }

  Future<void> end({bool remote = false, bool closeRemoteCall = false}) async {
    if (ended) return;
    ended = true;
    minimized = false;
    _ringTimeout?.cancel();
    _livestreamHeartbeatTimer?.cancel();
    _statusChannel?.unsubscribe();
    if (isCall) {
      _logCallIfCaller();
      unawaited(_callService.endCall(call.id));
    } else if (closeRemoteCall) {
      try {
        await _callService
            .closeLivestreamCall(call.id)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    unawaited(PushNotificationService.cancelActiveMediaNotification());
    _listener?.dispose();
    try {
      await room.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {}
    ActiveMediaSessionController.instance._clear(this);
    _changed();
  }

  void _logCallIfCaller() {
    if (_callLogged) return;
    _callLogged = true;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != call.callerId) return;
    String logStatus;
    int duration = 0;
    if (connectedAt != null) {
      logStatus = 'ended';
      duration = DateTime.now().difference(connectedAt!).inSeconds;
    } else if (status == 'declined') {
      logStatus = 'declined';
    } else if (status == 'ringing') {
      logStatus = 'canceled';
    } else {
      logStatus = 'missed';
    }
    unawaited(
      _callService.logCall(
        conversationId: call.conversationId,
        callType: call.callType,
        status: logStatus,
        durationSecs: duration,
      ),
    );
  }

  void _changed() {
    kind.value++;
    notifyListeners();
  }

  @override
  void dispose() {
    _ringTimeout?.cancel();
    _livestreamHeartbeatTimer?.cancel();
    _statusChannel?.unsubscribe();
    _listener?.dispose();
    unawaited(room.disconnect());
    kind.dispose();
    super.dispose();
  }
}
