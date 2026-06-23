import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../l10n/app_localizations.dart';
import '../../services/active_media_session.dart';
import '../../services/call_service.dart';
import '../../widgets/premium_toast.dart';

class LivestreamScreen extends StatefulWidget {
  final CallInfo call;
  final String livekitUrl;
  final String livekitToken;
  final bool isHost;
  final bool canManageLivestream;
  final String groupName;
  final ActiveMediaSession? session;

  const LivestreamScreen({
    super.key,
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.isHost,
    required this.canManageLivestream,
    required this.groupName,
    this.session,
  });

  @override
  State<LivestreamScreen> createState() => _LivestreamScreenState();
}

class _LivestreamScreenState extends State<LivestreamScreen> {
  late final ActiveMediaSession _session;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _session =
        widget.session ??
        ActiveMediaSessionController.instance.startLivestream(
          call: widget.call,
          livekitUrl: widget.livekitUrl,
          livekitToken: widget.livekitToken,
          isHost: widget.isHost,
          canManageLivestream: widget.canManageLivestream,
          groupName: widget.groupName,
        );
    _session.restore();
    _session.addListener(_onSessionChanged);
    _session.connect().catchError((e) {
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).connectionFailed('$e'),
          kind: ToastKind.error,
        );
        _popPage();
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    if (!_session.minimized && !_session.ended) {
      _session.markPageHidden();
    }
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
    if (_session.ended && mounted && !_closing) {
      _popPage();
    }
  }

  void _minimize() {
    if (_session.ended || _closing) return;
    _session.minimize();
    _popPage();
  }

  void _popPage() {
    if (!mounted) return;
    if (!_closing) setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _leave() => _session.leaveLivestream();

  Future<void> _closeLivestream() => _session.closeLivestream();

  Future<void> _toggleMic() => _session.toggleMic();

  Future<void> _toggleCamera() => _session.toggleCamera();

  Future<void> _flipCamera() async {
    final newPos = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    await _session.flipCamera(newPos);
    setState(() => _cameraPosition = newPos);
  }

  List<Participant> get _allParticipants => _session.participants;

  static bool _micOn(Participant p) =>
      p.audioTrackPublications.any((t) => !t.muted);

  static bool _camOn(Participant p) =>
      p.videoTrackPublications.any((t) => !t.muted);

  String _participantLabel(Participant p) {
    if (p.name.isNotEmpty) return p.name;
    return p.identity.length > 8 ? p.identity.substring(0, 8) : p.identity;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_closing) _minimize();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildMainVideo(),
              Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VideoTrack? _videoOf(Participant p) {
    final pub = p.videoTrackPublications.where((t) => !t.muted).firstOrNull;
    return pub?.track as VideoTrack?;
  }

  Widget _buildMainVideo() {
    final tiles = <Widget>[];
    for (final p in _allParticipants) {
      final track = _videoOf(p);
      if (track != null) {
        tiles.add(_videoTile(track, _participantLabel(p), _micOn(p)));
      }
    }

    if (tiles.isEmpty) {
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
          GestureDetector(
            onTap: _minimize,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
          Expanded(
            child: Text(
              _session.groupName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
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
                    '${_session.viewerCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
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
      child: _session.canManageLivestream
          ? _buildManagerControls()
          : _buildMemberControls(),
    );
  }

  Widget _buildManagerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LiveButton(
          icon: _session.micEnabled ? Icons.mic : Icons.mic_off,
          label: _session.micEnabled
              ? AppLocalizations.of(context).mute
              : AppLocalizations.of(context).micOn,
          onTap: _toggleMic,
        ),
        _LiveButton(
          icon: _session.cameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: _session.cameraEnabled
              ? AppLocalizations.of(context).cameraOff
              : AppLocalizations.of(context).cameraOn,
          onTap: _toggleCamera,
        ),
        if (_session.cameraEnabled)
          _LiveButton(
            icon: Icons.flip_camera_ios_outlined,
            label: AppLocalizations.of(context).flipCamera,
            onTap: _flipCamera,
          ),
        _LiveButton(
          icon: Icons.exit_to_app,
          label: AppLocalizations.of(context).confirmButton,
          onTap: _leave,
          color: const Color(0xFF5A5A66),
        ),
        _LiveButton(
          icon: Icons.stop_circle_outlined,
          label: AppLocalizations.of(context).endLivestream,
          onTap: _closeLivestream,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildMemberControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LiveButton(
          icon: _session.micEnabled ? Icons.mic : Icons.mic_off,
          label: _session.micEnabled
              ? AppLocalizations.of(context).mute
              : AppLocalizations.of(context).micOn,
          onTap: _toggleMic,
        ),
        _LiveButton(
          icon: _session.cameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: _session.cameraEnabled
              ? AppLocalizations.of(context).cameraOff
              : AppLocalizations.of(context).cameraOn,
          onTap: _toggleCamera,
        ),
        if (_session.cameraEnabled)
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

  void _showParticipantsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AnimatedBuilder(
        animation: _session,
        builder: (ctx, _) {
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
