import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../l10n/app_localizations.dart';
import '../../services/active_media_session.dart';
import '../../services/call_service.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import '../../widgets/premium_toast.dart';

class CallScreen extends StatefulWidget {
  final CallInfo call;
  final String livekitUrl;
  final String livekitToken;
  final String displayName;
  final ActiveMediaSession? session;

  const CallScreen({
    super.key,
    required this.call,
    required this.livekitUrl,
    required this.livekitToken,
    required this.displayName,
    this.session,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final ActiveMediaSession _session;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _session =
        widget.session ??
        ActiveMediaSessionController.instance.startCall(
          call: widget.call,
          livekitUrl: widget.livekitUrl,
          livekitToken: widget.livekitToken,
          displayName: widget.displayName,
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

  Future<void> _hangUp() => _session.end();

  Future<void> _toggleMic() => _session.toggleMic();

  Future<void> _toggleCamera() => _session.toggleCamera();

  @override
  Widget build(BuildContext context) {
    final isVideo = _session.isVideoCall;
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_closing) _minimize();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Stack(
            children: [
              if (isVideo && _session.remoteParticipants.isNotEmpty)
                _RemoteVideoView(participant: _session.remoteParticipants.first)
              else
                _buildCallerInfo(),
              if (isVideo && _session.cameraEnabled && _session.connected)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _LocalVideoPip(
                    localParticipant: _session.room.localParticipant,
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: _CircleIconButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: _minimize,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControls(isVideo),
              ),
            ],
          ),
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
              _session.displayName.isNotEmpty
                  ? avatarInitial(_session.displayName)
                  : '?',
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _session.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _displayStatus(),
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _displayStatus() {
    final l10n = AppLocalizations.of(context);
    if (_session.status == 'declined') return l10n.callDeclined;
    if (_session.status == 'ended' || _session.status == 'missed') {
      return l10n.callEnded;
    }
    if (_session.remoteParticipants.isNotEmpty) return l10n.inCall;
    if (_session.status == 'accepted') return l10n.connecting;
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
            icon: _session.micEnabled ? Icons.mic : Icons.mic_off,
            label: _session.micEnabled
                ? AppLocalizations.of(context).mute
                : AppLocalizations.of(context).unmute,
            onTap: _toggleMic,
            active: !_session.micEnabled,
          ),
          GestureDetector(
            onTap: _hangUp,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
          if (isVideo)
            _ControlButton(
              icon: _session.cameraEnabled
                  ? Icons.videocam
                  : Icons.videocam_off,
              label: _session.cameraEnabled
                  ? AppLocalizations.of(context).cameraOff
                  : AppLocalizations.of(context).cameraOn,
              onTap: _toggleCamera,
              active: !_session.cameraEnabled,
            )
          else
            _ControlButton(
              icon: _session.speakerOn ? Icons.volume_up : Icons.volume_off,
              label: _session.speakerOn
                  ? AppLocalizations.of(context).earpiece
                  : AppLocalizations.of(context).speaker,
              onTap: () => _session.setSpeaker(!_session.speakerOn),
            ),
        ],
      ),
    );
  }
}

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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(100),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

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
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}
