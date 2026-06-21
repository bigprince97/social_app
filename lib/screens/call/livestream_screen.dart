import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
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
  // 初值在 initState 按是否主播确定：主播进来即开麦开摄像头，观众默认不推流
  bool _micEnabled = false;
  bool _cameraEnabled = false;
  bool _ended = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  RealtimeChannel? _statusChannel;

  // Track remote host video for viewers
  final List<RemoteParticipant> _remoteParticipants = [];

  // 成员面板实时刷新信号（参与者进出/麦克风/摄像头变化时 +1）
  final ValueNotifier<int> _roomTick = ValueNotifier(0);

  Timer? _emptyRoomTimer;

  /// 主播：房间空了，延迟 30 秒确认仍无人 → 自动结束直播
  void _scheduleEmptyRoomClose() {
    _emptyRoomTimer?.cancel();
    _emptyRoomTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_ended && _remoteParticipants.isEmpty) {
        _leave();
      }
    });
  }

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
    // 会议模式：取消主播概念，所有人（含开启者）进来默认关麦关摄像头，
    // 各自可随时开启自己的麦克风/摄像头
    _micEnabled = false;
    _cameraEnabled = false;
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
        _emptyRoomTimer?.cancel(); // 有人进来了，取消空房关闭
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
        // 主播：房间里没有其他人了 → 无人观看，自动关闭直播
        if (widget.isHost && _remoteParticipants.isEmpty) {
          _scheduleEmptyRoomClose();
        }
        // 观众：主播(发布者)走了，房间没有视频源 → 直播已结束，自动退出
        if (!widget.isHost && _remoteParticipants.isEmpty) {
          if (mounted && !_ended) _leave(remote: true);
        }
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
      // 会议模式：不自动开启任何人的麦克风/摄像头
      if (mounted) setState(() => _connected = true);
    } catch (e) {
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).connectionFailed('$e'),
          kind: ToastKind.error,
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
    _emptyRoomTimer?.cancel();
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
        builder: (ctx, _, _) {
          final t = AppLocalizations.of(ctx);
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
            // Main video area（会议网格：所有开摄像头的人自适应排列）
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

  /// 取某参与者未静音的视频轨
  VideoTrack? _videoOf(Participant p) {
    final pub = p.videoTrackPublications.where((t) => !t.muted).firstOrNull;
    return pub?.track as VideoTrack?;
  }

  /// 会议网格：所有「开了摄像头」的参与者（含自己）按人数自适应行列排列。
  /// 没有任何人开摄像头时，显示等待/纯音频占位。
  Widget _buildMainVideo() {
    final tiles = <Widget>[];
    for (final p in _allParticipants) {
      final track = _videoOf(p);
      if (track != null) {
        tiles.add(_videoTile(track, _participantLabel(p), _micOn(p)));
      }
    }

    if (tiles.isEmpty) {
      // 会议模式：还没有人开摄像头
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).noOneSharingCamera,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (tiles.length == 1) return tiles.first;

    final n = tiles.length;
    // 智能分屏：列数随人数变化
    //  2人 → 1列(上下分屏)  3~4人 → 2列  5~9人 → 3列  10+ → 4列
    final int cols = n == 2
        ? 1
        : n <= 4
        ? 2
        : n <= 9
        ? 3
        : 4;
    final int rows = (n / cols).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 64, 6, 100),
      child: LayoutBuilder(
        builder: (ctx, c) {
          const spacing = 6.0;
          // 行数不多时让每格刚好铺满可用空间，不滚动；
          // 人很多(>4行)时改为固定竖向比例并允许滚动。
          final scroll = rows > 4;
          final tileW = (c.maxWidth - (cols - 1) * spacing) / cols;
          final tileH = (c.maxHeight - (rows - 1) * spacing) / rows;
          final ratio = (scroll || tileH <= 0) ? 3 / 4 : tileW / tileH;
          return GridView.count(
            physics: scroll ? null : const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
            children: tiles,
          );
        },
      ),
    );
  }

  Widget _videoTile(VideoTrack track, String label, bool micOn) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF222232)),
          VideoTrackRenderer(track),
          // 名牌 + 麦克风状态
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    micOn ? Icons.mic : Icons.mic_off,
                    size: 12,
                    color: micOn ? Colors.greenAccent : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    // 观众也可连麦：开/关自己的麦克风、摄像头；摄像头开启时可翻转；退出仅离开自己
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
        if (_cameraEnabled)
          _LiveButton(
            icon: Icons.flip_camera_ios_outlined,
            label: AppLocalizations.of(context).flipCamera,
            onTap: _flipCamera,
          ),
        _LiveButton(
          icon: Icons.exit_to_app,
          label: AppLocalizations.of(context).confirmButton,
          onTap: _leave,
          color: Colors.red,
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
