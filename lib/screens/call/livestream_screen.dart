import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/call_service.dart';

class LivestreamScreen extends StatefulWidget {
  final CallInfo call;
  final String livekitUrl;
  final String livekitToken;
  final bool isHost;
  final String groupName;

  const LivestreamScreen({
    super.key,
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.isHost,
    required this.groupName,
  });

  @override
  State<LivestreamScreen> createState() => _LivestreamScreenState();
}

class _LivestreamScreenState extends State<LivestreamScreen> {
  final _callService = CallService();
  late final Room _room;
  EventsListener<RoomEvent>? _listener;
  bool _connected = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _ended = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  RealtimeChannel? _statusChannel;

  // Track remote host video for viewers
  final List<RemoteParticipant> _remoteParticipants = [];

  // 成员面板实时刷新信号（参与者进出/麦克风/摄像头变化时 +1）
  final ValueNotifier<int> _roomTick = ValueNotifier(0);

  /// 房间内全部参与者（本人在前）
  List<Participant> get _allParticipants => [
    if (_room.localParticipant != null) _room.localParticipant!,
    ..._remoteParticipants,
  ];

  static bool _micOn(Participant p) =>
      p.audioTrackPublications.any((t) => !t.muted);
  static bool _camOn(Participant p) =>
      p.videoTrackPublications.any((t) => !t.muted);

  String _participantLabel(Participant p) {
    if (p.name.isNotEmpty) return p.name;
    // 旧 token 无 name 时退化显示
    return p.identity.length > 8 ? p.identity.substring(0, 8) : p.identity;
  }

  int get _viewerCount => _remoteParticipants.length + (_connected ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _room = Room(
      roomOptions: RoomOptions(
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          noiseSuppression: true,
        ),
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
        ),
      ),
    );
    _connect();
    _listenForStatus();
  }

  Future<void> _connect() async {
    _listener = _room.createListener()
      ..on<ParticipantConnectedEvent>((e) {
        if (mounted) setState(() => _remoteParticipants.add(e.participant));
        _roomTick.value++;
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        if (mounted) {
          setState(
            () => _remoteParticipants.removeWhere(
              (p) => p.sid == e.participant.sid,
            ),
          );
        }
        _roomTick.value++;
      })
      // 远端轨道订阅/取消时刷新，否则主播画面到达后 UI 不更新
      ..on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      // 麦克风/摄像头开关状态变化 → 成员面板实时刷新
      ..on<TrackMutedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<TrackUnmutedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<LocalTrackPublishedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<TrackPublishedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<TrackUnpublishedEvent>((_) {
        if (mounted) setState(() {});
        _roomTick.value++;
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted && !_ended) _leave();
      });

    try {
      await _room.connect(widget.livekitUrl, widget.livekitToken);
      // 进房前已在房间里的参与者（通常正是主播）不会触发
      // ParticipantConnectedEvent，必须从快照补齐
      if (mounted) {
        setState(() {
          for (final p in _room.remoteParticipants.values) {
            if (!_remoteParticipants.any((x) => x.sid == p.sid)) {
              _remoteParticipants.add(p);
            }
          }
        });
      }
      // 观众自愈：主播 App 被杀时 call 状态会卡在 ongoing(僵尸横幅)。
      // 进房 20 秒后房间里仍没有主播 → 把 call 标记 ended 并退出。
      if (!widget.isHost) {
        Future.delayed(const Duration(seconds: 20), () {
          if (mounted && !_ended && _remoteParticipants.isEmpty) {
            _callService.endCall(widget.call.id).catchError((_) {});
            _leave(remote: true);
          }
        });
      }
      if (widget.isHost) {
        await _room.localParticipant?.setMicrophoneEnabled(true);
        await _room.localParticipant?.setCameraEnabled(true);
      }
      if (mounted) setState(() => _connected = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).connectionFailed('$e')),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _listenForStatus() {
    _statusChannel = _callService.subscribeToCallStatus(widget.call.id, (
      status,
    ) {
      if (mounted && (status == 'ended') && !widget.isHost) {
        _leave(remote: true);
      }
    });
  }

  Future<void> _leave({bool remote = false}) async {
    if (_ended) return;
    _ended = true;
    _statusChannel?.unsubscribe();
    // 先退出页面，结束信令/断开房间放到后台执行——
    // web 端 _room.disconnect() 可能长时间不返回，await 会卡死退出按钮
    if (mounted) Navigator.pop(context);
    if (widget.isHost) {
      _callService.endCall(widget.call.id).catchError((_) {});
    }
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

  Future<void> _flipCamera() async {
    final newPos = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    final pub = _room.localParticipant?.videoTrackPublications.firstOrNull;
    final track = pub?.track;
    if (track != null) {
      await track.restartTrack(CameraCaptureOptions(cameraPosition: newPos));
      setState(() => _cameraPosition = newPos);
    }
  }

  @override
  void dispose() {
    // 主播端兜底：页面以任何方式销毁都确保 call 标记 ended，防僵尸横幅
    if (widget.isHost && !_ended) {
      _callService.endCall(widget.call.id).catchError((_) {});
    }
    _roomTick.dispose();
    _listener?.dispose();
    _room.disconnect();
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  /// 在线成员面板：名单 + 每人麦克风/摄像头实时状态
  void _showParticipantsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: _roomTick,
        builder: (ctx, _, __) {
          final t = AppLocalizations.of(ctx);
          final hostIdentity = widget.call.callerId;
          final list = _allParticipants;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    '${t.onlineMembers} (${list.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final p = list[i];
                      final isHost = p.identity == hostIdentity;
                      final isMe = p is LocalParticipant;
                      final label = _participantLabel(p);
                      return ListTile(
                        tileColor: Colors.transparent,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF9575CD),
                          child: Text(
                            label.isNotEmpty ? label[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '(${t.me})',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (isHost)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.hostLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _micOn(p) ? Icons.mic : Icons.mic_off,
                              size: 20,
                              color: _micOn(p)
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 14),
                            Icon(
                              _camOn(p) ? Icons.videocam : Icons.videocam_off,
                              size: 20,
                              color: _camOn(p)
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main video area
            _buildMainVideo(),
            // Top bar
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            // Bottom controls
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildMainVideo() {
    if (widget.isHost) {
      // Host sees their own camera
      final pub = _room.localParticipant?.videoTrackPublications.firstOrNull;
      final track = pub?.track;
      if (track != null && _cameraEnabled) {
        return VideoTrackRenderer(track);
      }
      return Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 64),
        ),
      );
    }
    // Viewer sees the host's video
    final host = _remoteParticipants.firstOrNull;
    if (host == null) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).waitingForHost,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    final pub = host.videoTrackPublications.where((p) => !p.muted).firstOrNull;
    final track = pub?.track;
    if (track == null) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 64),
        ),
      );
    }
    return VideoTrackRenderer(track);
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(160), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.groupName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          // Viewer count — 点击打开在线成员面板
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showParticipantsPanel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_viewerCount',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Close
          GestureDetector(
            onTap: _leave,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withAlpha(160), Colors.transparent],
        ),
      ),
      child: widget.isHost ? _buildHostControls() : _buildViewerControls(),
    );
  }

  Widget _buildHostControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LiveButton(
          icon: _micEnabled ? Icons.mic : Icons.mic_off,
          label: _micEnabled
              ? AppLocalizations.of(context).mute
              : AppLocalizations.of(context).micOn,
          onTap: _toggleMic,
        ),
        _LiveButton(
          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: _cameraEnabled
              ? AppLocalizations.of(context).cameraOff
              : AppLocalizations.of(context).cameraOn,
          onTap: _toggleCamera,
        ),
        _LiveButton(
          icon: Icons.flip_camera_ios_outlined,
          label: AppLocalizations.of(context).flipCamera,
          onTap: _flipCamera,
        ),
        _LiveButton(
          icon: Icons.stop_circle_outlined,
          label: AppLocalizations.of(context).endLivestream,
          onTap: _leave,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildViewerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _LiveButton(
          icon: Icons.exit_to_app,
          label: AppLocalizations.of(context).confirmButton,
          onTap: _leave,
        ),
      ],
    );
  }
}

class _LiveButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _LiveButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
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
            color: (color ?? Colors.white).withAlpha(color != null ? 220 : 40),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color != null ? Colors.white : Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}
