import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/call_service.dart';

/// 来电界面（被叫方）：显示主叫信息 + 接听/拒绝。
class IncomingCallScreen extends StatefulWidget {
  final CallInfo call;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String _callerName = '来电';
  String? _callerAvatar;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCaller();
  }

  Future<void> _loadCaller() async {
    try {
      final p = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', widget.call.callerId)
          .maybeSingle();
      if (p != null && mounted) {
        setState(() {
          _callerName = (p['display_name'] as String?) ?? '来电';
          _callerAvatar = p['avatar_url'] as String?;
        });
      }
    } catch (_) {}
  }

  String get _typeLabel {
    final l10n = AppLocalizations.of(context);
    switch (widget.call.callType) {
      case 'video':
        return l10n.videoCall;
      case 'livestream':
        return l10n.livestreamInvite;
      default:
        return l10n.voiceCall;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1430),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1F4A), Color(0xFF1A1430)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withAlpha(40), width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFF9575CD),
                  backgroundImage: _callerAvatar != null
                      ? NetworkImage(_callerAvatar!)
                      : null,
                  child: _callerAvatar == null
                      ? Text(
                          _callerName.isNotEmpty
                              ? _callerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 44,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.call.callType == 'video'
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: Colors.white.withAlpha(180),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).callInvitation(_typeLabel),
                    style: TextStyle(
                        color: Colors.white.withAlpha(180), fontSize: 15),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              // Accept / Decline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallActionButton(
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFFF453A),
                      label: AppLocalizations.of(context).decline,
                      onTap: _busy
                          ? null
                          : () {
                              setState(() => _busy = true);
                              widget.onDecline();
                            },
                    ),
                    _CallActionButton(
                      icon: widget.call.callType == 'video'
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: const Color(0xFF34C759),
                      label: AppLocalizations.of(context).accept,
                      onTap: _busy
                          ? null
                          : () {
                              setState(() => _busy = true);
                              widget.onAccept();
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
      ],
    );
  }
}
