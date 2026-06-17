import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
import '../../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final CallInfo call;
  final String livekitUrl;
  final String livekitToken;
  final String displayName;

  const CallScreen({
    super.key,
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.displayName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _callService = CallService();
  late final Room _room;
  EventsListener<RoomEvent>? _listener;
  bool _connected = false;
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool _speakerOn = true;
  RealtimeChannel? _statusChannel;
  String _status = 'ringing';
  bool _ended = false;
  DateTime? _connectedAt; // 首次接通(对方进房)时刻，用于算时长
  bool _callLogged = false;

  final List<RemoteParticipant> _remoteParticipants = [];

  @override
  void initState() {
    super.initState();
    _cameraEnabled = widget.call.callType == 'video';
    _status = widget.call.status;
    _room = Room(
      roomOptions: RoomOptions(
        defaultAudioCaptureOptions:
            const AudioCaptureOptions(noiseSuppression: true),
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
        ),
      ),
    );
    _connect();
    _listenForStatus();
    // 呼叫 60 秒无人接听自动挂断(仅主叫方,status 仍是 ringing 时)
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && !_ended && _status == 'ringing') _hangUp();
    });
  }

  Future<void> _connect() async {
    _listener = _room.createListener()
      ..on<ParticipantConnectedEvent>((e) {
        _connectedAt ??= DateTime.now();
        if (mounted) setState(() => _remoteParticipants.add(e.participant));
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        if (mounted) {
          setState(() => _remoteParticipants
              .removeWhere((p) => p.sid == e.participant.sid));
        }
        // 1对1通话：曾接通后对方离开房间 → 本端立即挂断退出，保持状态一致
        if (!_ended && _connectedAt != null && _remoteParticipants.isEmpty) {
          _hangUp(remote: true);
        }
      })
      // 视频轨道订阅后刷新，确保对方画面到达即渲染
      ..on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted && !_ended) _hangUp();
      });

    try {
      await _room.connect(widget.livekitUrl, widget.livekitToken);
      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (_cameraEnabled) {
        await _room.localParticipant?.setCameraEnabled(true);
      }
      // 进房前已在房间里的对方（被叫接听时主叫已在房）不会触发
      // ParticipantConnectedEvent，必须从快照补齐，否则状态卡在"呼叫中"
      if (mounted) {
        setState(() {
          _connected = true;
          for (final p in _room.remoteParticipants.values) {
            if (!_remoteParticipants.any((x) => x.sid == p.sid)) {
              _remoteParticipants.add(p);
            }
          }
          if (_remoteParticipants.isNotEmpty) _connectedAt ??= DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        showPremiumToast(context, AppLocalizations.of(context).connectionFailed('$e'), kind: ToastKind.error);
        Navigator.pop(context);
      }
    }
  }

  void _listenForStatus() {
    _statusChannel = _callService.subscribeToCallStatus(
      widget.call.id,
      (status) {
        if (mounted) {
          setState(() => _status = status);
          if (status == 'declined' || status == 'ended' || status == 'missed') {
            _hangUp(remote: true);
          }
        }
      },
    );
  }

  /// 仅主叫方在通话结束时写一条通话记录消息，避免双方各插一条。
  void _logCallIfCaller() {
    if (_callLogged) return;
    _callLogged = true;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != widget.call.callerId) return;
    String status;
    int duration = 0;
    if (_connectedAt != null) {
      status = 'ended';
      duration = DateTime.now().difference(_connectedAt!).inSeconds;
    } else if (_status == 'declined') {
      status = 'declined';
    } else if (_status == 'ringing') {
      status = 'canceled'; // 主叫在接通前挂断
    } else {
      status = 'missed';
    }
    _callService.logCall(
      conversationId: widget.call.conversationId,
      callType: widget.call.callType,
      status: status,
      durationSecs: duration,
    );
  }

  Future<void> _hangUp({bool remote = false}) async {
    if (_ended) return;
    _ended = true;
    _logCallIfCaller();
    _statusChannel?.unsubscribe();
    // 先退页面再收尾，web 端 disconnect 可能挂起导致按钮卡死
    if (mounted) Navigator.pop(context);
    _callService.endCall(widget.call.id).catchError((_) {});
    // ignore: unawaited_futures
    _room.disconnect().timeout(const Duration(seconds: 5)).catchError((_) {});
  }

  Future<void> _toggleMic() async {
    await _room.localParticipant?.setMicrophoneEnabled(!_micEnabled);
    setState(() => _micEnabled = !_micEnabled);
  }

  Future<void> _toggleCamera() async {
    await _room.localParticipant?.setCameraEnabled(!_cameraEnabled);
    setState(() => _cameraEnabled = !_cameraEnabled);
  }

  @override
  void dispose() {
    // 兜底：页面以任何方式销毁都确保 call 收尾，防僵尸状态
    if (!_ended) {
      _logCallIfCaller();
      _callService.endCall(widget.call.id).catchError((_) {});
    }
    _listener?.dispose();
    _room.disconnect();
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.callType == 'video';
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video or avatar background
            if (isVideo && _remoteParticipants.isNotEmpty)
              _RemoteVideoView(participant: _remoteParticipants.first)
            else
              _buildCallerInfo(),
            // Local camera PiP (top-right)
            if (isVideo && _cameraEnabled && _connected)
              Positioned(
                top: 16,
                right: 16,
                child: _LocalVideoPip(localParticipant: _room.localParticipant),
              ),
            // Controls at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(isVideo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF9575CD),
            child: Text(
              widget.displayName.isNotEmpty
                  ? widget.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(widget.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _displayStatus(),
            style: TextStyle(
                color: Colors.white.withAlpha(180), fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 统一的通话状态文案，单一数据源：
  /// 房间里已有对方 → 通话中；对方已接受但媒体未连上 → 连接中；
  /// 否则按 DB 状态（呼叫中/已拒绝/已结束）。
  String _displayStatus() {
    final l10n = AppLocalizations.of(context);
    if (_status == 'declined') return l10n.callDeclined;
    if (_status == 'ended' || _status == 'missed') return l10n.callEnded;
    if (_remoteParticipants.isNotEmpty) return l10n.inCall;
    if (_status == 'accepted') return l10n.connecting;
    return l10n.ringing;
  }

  Widget _buildControls(bool isVideo) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withAlpha(180)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: _micEnabled ? Icons.mic : Icons.mic_off,
            label: _micEnabled
                ? AppLocalizations.of(context).mute
                : AppLocalizations.of(context).unmute,
            onTap: _toggleMic,
            active: !_micEnabled,
          ),
          GestureDetector(
            onTap: _hangUp,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
          if (isVideo)
            _ControlButton(
              icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: _cameraEnabled
                  ? AppLocalizations.of(context).cameraOff
                  : AppLocalizations.of(context).cameraOn,
              onTap: _toggleCamera,
              active: !_cameraEnabled,
            )
          else
            _ControlButton(
              icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
              label: _speakerOn
                  ? AppLocalizations.of(context).earpiece
                  : AppLocalizations.of(context).speaker,
              onTap: () => setState(() => _speakerOn = !_speakerOn),
            ),
        ],
      ),
    );
  }
}

// ─── Remote video ────────────────────────────────────────────────────────────

class _RemoteVideoView extends StatelessWidget {
  final RemoteParticipant participant;
  const _RemoteVideoView({required this.participant});

  @override
  Widget build(BuildContext context) {
    final pub = participant.videoTrackPublications
        .where((p) => !p.muted)
        .firstOrNull;
    final track = pub?.track;
    if (track == null) {
      return Container(
        color: const Color(0xFF2D2D44),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
        ),
      );
    }
    return VideoTrackRenderer(track);
  }
}

// ─── Local video PiP ─────────────────────────────────────────────────────────

class _LocalVideoPip extends StatelessWidget {
  final LocalParticipant? localParticipant;
  const _LocalVideoPip({required this.localParticipant});

  @override
  Widget build(BuildContext context) {
    final pub = localParticipant?.videoTrackPublications.firstOrNull;
    final track = pub?.track;
    if (track == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        height: 140,
        child: VideoTrackRenderer(track),
      ),
    );
  }
}

// ─── Control button ───────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withAlpha(40)
                    : Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
}
