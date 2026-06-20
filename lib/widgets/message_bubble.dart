import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/auth_error.dart' show avatarInitial;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../widgets/premium_toast.dart';
import '../models/message.dart';
import '../services/report_service.dart';
import 'image_viewer.dart';
import 'premium_action_sheet.dart';
import 'video_player_widget.dart';

// ─── Telegram-style palette ───────────────────────────────────────────────────
const _kSentBg = Color(0xFF9575CD);
const _kRecvBg = Colors.white;
const _kChatBg = Color(0xFFEBEDF0);
const _kTimeOwn = Color(0xCCFFFFFF);
const _kTimeOther = Color(0xFF8E8E93);
const _kReadBlue = Color(0xFFBBDEFB);

const _kSenderPalette = [
  Color(0xFFE53935),
  Color(0xFF8E24AA),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFE91E63),
  Color(0xFF039BE5),
  Color(0xFF795548),
];

Color _colorForSender(String id) =>
    _kSenderPalette[id.hashCode.abs() % _kSenderPalette.length];

BorderRadius _radius(bool isMe) => BorderRadius.only(
  topLeft: const Radius.circular(18),
  topRight: const Radius.circular(18),
  bottomLeft: Radius.circular(isMe ? 18 : 4),
  bottomRight: Radius.circular(isMe ? 4 : 18),
);

// 2-minute recall window
const _kRecallWindow = Duration(minutes: 2);
// ─────────────────────────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;

  /// 是否显示发送者昵称（仅连发第一条显示，避免重复）
  final bool showSenderName;
  final bool showDateSeparator;
  final bool isRead;
  final VoidCallback? onDelete;
  final List<String> groupMemberNames; // username list for @mention highlight
  /// True for group chats — reserves avatar slot space so bubbles align
  final bool isGroupChat;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.showSenderName = true,
    this.showDateSeparator = false,
    this.isRead = false,
    this.onDelete,
    this.groupMemberNames = const [],
    this.isGroupChat = false,
  });

  bool get _canRecall {
    if (!isMe) return false;
    if (message.isDeleted) return false;
    return DateTime.now().difference(message.createdAt) <= _kRecallWindow;
  }

  void _openSenderProfile(BuildContext context) {
    final userId = message.sender?.id ?? message.senderId;
    if (userId.isEmpty) return;
    context.push('/profile/$userId');
  }

  void _showMenu(BuildContext context) {
    final isText = message.messageType == 'text' && !message.isDeleted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final previewBg = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF5F5F8);
    final divColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),

                  // ── Message preview ──────────────────────────────────
                  if (isText && (message.content?.isNotEmpty ?? false))
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: previewBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9575CD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message.content!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Action buttons ───────────────────────────────────
                  if (isText || _canRecall || !isMe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isText)
                            _MenuActionBtn(
                              icon: Icons.copy_all_rounded,
                              label: AppLocalizations.of(context).copy,
                              color: const Color(0xFF1E88E5),
                              isDark: isDark,
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: message.content ?? ''),
                                );
                                Navigator.pop(context);
                                showPremiumToast(
                                  context,
                                  AppLocalizations.of(
                                    context,
                                  ).copiedToClipboard,
                                  kind: ToastKind.success,
                                );
                              },
                            ),
                          if (isText && (_canRecall || !isMe))
                            Container(width: 1, height: 40, color: divColor),
                          if (_canRecall && onDelete != null)
                            _MenuActionBtn(
                              icon: Icons.undo_rounded,
                              label: AppLocalizations.of(context).recall,
                              color: const Color(0xFFE53935),
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                onDelete?.call();
                              },
                            ),
                          if (_canRecall && !isMe)
                            Container(width: 1, height: 40, color: divColor),
                          if (!isMe)
                            _MenuActionBtn(
                              icon: Icons.report_problem_outlined,
                              label: AppLocalizations.of(context).report,
                              color: const Color(0xFFFF9500),
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                _showReportMenu(context);
                              },
                            ),
                        ],
                      ),
                    ),

                  // ── Expired recall notice ────────────────────────────
                  if (isMe && !message.isDeleted && !_canRecall)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).recallTimeLimit,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── Cancel button ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: previewBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).cancel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReportMenu(BuildContext context) {
    final t = AppLocalizations.of(context);
    showPremiumActionSheet(
      context,
      title: t.reportReason,
      actions: [
        PremiumAction(
          icon: Icons.announcement_outlined,
          label: t.reportReasonSpam,
          onTap: () {
            Navigator.pop(context);
            _reportMessage(context, t.reportReasonSpam);
          },
        ),
        PremiumAction(
          icon: Icons.sentiment_very_dissatisfied_outlined,
          label: t.reportReasonHarassment,
          onTap: () {
            Navigator.pop(context);
            _reportMessage(context, t.reportReasonHarassment);
          },
        ),
        PremiumAction(
          icon: Icons.gavel_outlined,
          label: t.reportReasonObjectionable,
          onTap: () {
            Navigator.pop(context);
            _reportMessage(context, t.reportReasonObjectionable);
          },
        ),
        PremiumAction(
          icon: Icons.report_problem_outlined,
          label: t.reportReasonViolence,
          onTap: () {
            Navigator.pop(context);
            _reportMessage(context, t.reportReasonViolence);
          },
        ),
        PremiumAction(
          icon: Icons.help_outline_rounded,
          label: t.reportReasonOther,
          onTap: () {
            Navigator.pop(context);
            _reportMessage(context, t.reportReasonOther);
          },
        ),
      ],
    );
  }

  Future<void> _reportMessage(BuildContext context, String reason) async {
    try {
      await ReportService().reportContent(
        targetType: 'message',
        targetId: message.id,
        reason: reason,
      );
      if (context.mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).reportSuccess,
          kind: ToastKind.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).reportFailed(''),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDateSeparator) _DateSeparator(date: message.createdAt),
        GestureDetector(
          onLongPress: message.isDeleted ? null : () => _showMenu(context),
          child: Padding(
            padding: EdgeInsets.only(
              left: isMe ? 56 : 8,
              right: isMe ? 8 : 56,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              // 群聊收到的消息：头像与气泡顶部对齐，挨着发送者昵称；
              // 其余（自己发的/私聊）底部对齐即可
              crossAxisAlignment: (!isMe && isGroupChat)
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                // Only show avatar slot in group chats (reserves alignment space)
                if (!isMe && isGroupChat)
                  _AvatarSlot(
                    message: message,
                    showAvatar: showAvatar,
                    onTap: () => _openSenderProfile(context),
                  ),
                if (!isMe && isGroupChat) const SizedBox(width: 6),
                Flexible(child: _buildBubble(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context) {
    if (message.isDeleted) return _DeletedBubble(isMe: isMe);
    if (message.messageType == 'image' && message.mediaUrl != null) {
      return _ImageBubble(message: message, isMe: isMe, isRead: isRead);
    }
    if (message.messageType == 'audio' && message.mediaUrl != null) {
      return _AudioBubble(message: message, isMe: isMe, isRead: isRead);
    }
    if (message.messageType == 'video' && message.mediaUrl != null) {
      return _VideoBubble(message: message, isMe: isMe, isRead: isRead);
    }
    if (message.messageType == 'file' && message.mediaUrl != null) {
      return _FileBubble(message: message, isMe: isMe, isRead: isRead);
    }
    if (message.messageType == 'call') {
      return _CallBubble(message: message, isMe: isMe);
    }
    return _TextBubble(
      message: message,
      isMe: isMe,
      showSenderName: !isMe && showSenderName,
      isRead: isRead,
      groupMemberNames: groupMemberNames,
      onSenderTap: () => _openSenderProfile(context),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _AvatarSlot extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final VoidCallback? onTap;
  const _AvatarSlot({
    required this.message,
    required this.showAvatar,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showAvatar) return const SizedBox(width: 32);
    final s = message.sender;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CircleAvatar(
          radius: 16,
          backgroundColor: _colorForSender(message.senderId),
          backgroundImage: s?.avatarUrl != null
              ? CachedNetworkImageProvider(s!.avatarUrl!)
              : null,
          child: s?.avatarUrl == null
              ? Text(
                  avatarInitial(s?.displayName),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ─── Deleted ──────────────────────────────────────────────────────────────────

// ─── 通话记录气泡 ─────────────────────────────────────────────────────────────
class _CallBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _CallBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final p = message.payload ?? const {};
    final callType = (p['call_type'] as String?) ?? 'voice';
    final status = (p['status'] as String?) ?? 'ended';
    final dur = (p['duration'] as num?)?.toInt() ?? 0;
    final isVideo = callType == 'video';

    final bool missed = status != 'ended';
    String label;
    switch (status) {
      case 'ended':
        final m = (dur ~/ 60).toString().padLeft(2, '0');
        final s = (dur % 60).toString().padLeft(2, '0');
        label = '${isVideo ? '视频通话' : '语音通话'} $m:$s';
        break;
      case 'canceled':
        label = isMe ? '已取消' : '对方已取消';
        break;
      case 'declined':
        label = isMe ? '对方已拒绝' : '已拒绝';
        break;
      default: // missed
        label = isMe ? '对方无人接听' : '未接听';
    }

    final color = missed ? const Color(0xFFE53935) : _kTimeOther;
    final icon = missed
        ? Icons.phone_missed_rounded
        : (isVideo ? Icons.videocam_rounded : Icons.call_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? _kSentBg : _kRecvBg,
        borderRadius: _radius(isMe),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isMe ? Colors.white : color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  const _DeletedBubble({required this.isMe});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: isMe ? _kSentBg.withAlpha(100) : Colors.grey.shade200,
      borderRadius: _radius(isMe),
      border: Border.all(
        color: isMe ? Colors.white.withAlpha(40) : Colors.grey.shade300,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.not_interested,
          size: 14,
          color: isMe ? _kTimeOwn : _kTimeOther,
        ),
        const SizedBox(width: 4),
        Text(
          AppLocalizations.of(context).messageDeleted,
          style: TextStyle(
            color: isMe ? _kTimeOwn : _kTimeOther,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

// ─── Text / Scripture bubble ──────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showSenderName;
  final bool isRead;
  final List<String> groupMemberNames;
  final VoidCallback? onSenderTap;

  const _TextBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
    required this.isRead,
    required this.groupMemberNames,
    this.onSenderTap,
  });

  // Highlight @mentions in the text
  Widget _buildText(String text, Color textColor) {
    if (groupMemberNames.isEmpty || !text.contains('@')) {
      return Text(
        text,
        style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
      );
    }
    // Split on @Name patterns
    final spans = <InlineSpan>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      var foundAt = -1;
      String? foundName;
      for (final name in groupMemberNames) {
        final idx = remaining.indexOf('@$name');
        if (idx != -1 && (foundAt == -1 || idx < foundAt)) {
          foundAt = idx;
          foundName = name;
        }
      }
      if (foundAt == -1 || foundName == null) {
        spans.add(
          TextSpan(
            text: remaining,
            style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
          ),
        );
        break;
      }
      if (foundAt > 0) {
        spans.add(
          TextSpan(
            text: remaining.substring(0, foundAt),
            style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '@$foundName',
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.white : const Color(0xFF9575CD),
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      );
      remaining = remaining.substring(foundAt + foundName.length + 1);
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : Colors.black87;

    final isScripture = message.messageType == 'scripture';
    Map<String, dynamic>? quote;
    if (isScripture) {
      final parts = (message.content ?? '').split('|||');
      if (parts.length >= 3) {
        quote = {'text': parts[0], 'scripture': parts[1], 'chapter': parts[2]};
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        gradient: isMe
            ? const LinearGradient(
                colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMe ? null : _kRecvBg,
        borderRadius: _radius(isMe),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isMe ? 35 : 20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSenderName && message.sender != null) ...[
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSenderTap,
                child: Text(
                  message.sender!.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _colorForSender(message.senderId),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (isScripture && quote != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withAlpha(25) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: isMe
                        ? Colors.white.withAlpha(100)
                        : Colors.brown.shade300,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).scriptureQuote(
                      '${quote['scripture']}',
                      '${quote['chapter']}',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? _kTimeOwn : Colors.brown.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quote['text'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildText(message.content ?? '', textColor),
          ],
          const SizedBox(height: 3),
          _TimeStamp(
            time: DateFormat('HH:mm').format(message.createdAt.toLocal()),
            isMe: isMe,
            isRead: isRead,
          ),
        ],
      ),
    );
  }
}

// ─── Audio bubble ─────────────────────────────────────────────────────────────

class _AudioBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool isRead;
  const _AudioBubble({
    required this.message,
    required this.isMe,
    required this.isRead,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble>
    with AutomaticKeepAliveClientMixin {
  late final AudioPlayer _player;

  // 播放/加载中时保活：避免新消息插入或自动滚动把正在播放的语音气泡
  // 滚出可视区被 ListView 回收，导致 _player.dispose() 中断播放。
  @override
  bool get wantKeepAlive => _playing || _loading;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  int? _payloadSecs; // 录制时记录的时长（秒），作为稳定显示值，两端一致
  bool _loading = false;

  // 时长标签的显示值：未播放时用录制时存的固定秒数（两端一致、不随解码变动）
  String get _durationLabel {
    if (_playing || _position.inSeconds > 0) return _fmt(_position);
    final secs = _payloadSecs ?? _total.inSeconds;
    final m = (secs ~/ 60).toString();
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('[AUDIODBG] init ${widget.message.id}');
    // handleInterruptions:false —— 关闭 just_audio 的自动焦点处理。
    // 否则对方发来消息时系统的瞬时音频焦点变化会让播放自动暂停。
    _player = AudioPlayer(handleInterruptions: false);
    _player.playerStateStream.listen((s) async {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        // 播放结束：先 pause 清除 playWhenReady，否则 seek 回开头会自动续播 → 死循环
        await _player.pause();
        await _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
          updateKeepAlive();
        }
      } else {
        setState(() => _playing = s.playing);
        updateKeepAlive();
      }
      // ignore: avoid_print
      print(
        '[AUDIODBG] state ${widget.message.id} playing=${s.playing} proc=${s.processingState}',
      );
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _total = d);
    });
    // Use duration from payload if available
    _payloadSecs = widget.message.payload?['duration'] as int?;
    if (_payloadSecs != null) _total = Duration(seconds: _payloadSecs!);
  }

  @override
  void didUpdateWidget(_AudioBubble old) {
    super.didUpdateWidget(old);
    // ignore: avoid_print
    print(
      '[AUDIODBG] didUpdate ${old.message.id}->${widget.message.id} urlChanged=${old.message.mediaUrl != widget.message.mediaUrl}',
    );
    // 若本 State 被复用到另一条语音（音频 URL 变了），重置播放器与时长，
    // 否则会显示上一条消息的时长/进度
    if (old.message.mediaUrl != widget.message.mediaUrl) {
      _player.stop();
      _position = Duration.zero;
      _playing = false;
      _payloadSecs = widget.message.payload?['duration'] as int?;
      _total = _payloadSecs != null
          ? Duration(seconds: _payloadSecs!)
          : Duration.zero;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    // ignore: avoid_print
    print('[AUDIODBG] dispose ${widget.message.id} playing=$_playing');
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.idle) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(widget.message.mediaUrl!);
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          showPremiumToast(
            context,
            AppLocalizations.of(context).audioPlayFailed(e),
            kind: ToastKind.error,
          );
        }
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    await _player.play();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    final bg = widget.isMe ? _kSentBg : _kRecvBg;
    final fg = widget.isMe ? Colors.white : Colors.black87;
    final iconColor = widget.isMe ? Colors.white : const Color(0xFF9575CD);
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
      decoration: BoxDecoration(
        gradient: widget.isMe
            ? const LinearGradient(
                colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: widget.isMe ? null : bg,
        borderRadius: _radius(widget.isMe),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(widget.isMe ? 35 : 20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withAlpha(40)
                        : const Color(0xFF9575CD).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        )
                      : Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          color: iconColor,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform-style progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: widget.isMe
                            ? Colors.white.withAlpha(60)
                            : Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isMe ? Colors.white : const Color(0xFF9575CD),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _durationLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isMe ? _kTimeOwn : _kTimeOther,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.mic, size: 14, color: fg.withAlpha(100)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _TimeStamp(
              time: DateFormat(
                'HH:mm',
              ).format(widget.message.createdAt.toLocal()),
              isMe: widget.isMe,
              isRead: widget.isRead,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image bubble ─────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isRead;
  const _ImageBubble({
    required this.message,
    required this.isMe,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final r = _radius(isMe);
    return ClipRRect(
      borderRadius: r,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () =>
                ImageViewer.show(context, imageUrls: [message.mediaUrl!]),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl!,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: 220,
                height: 165,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(110),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _TimeStamp(
                time: DateFormat('HH:mm').format(message.createdAt.toLocal()),
                isMe: isMe,
                isRead: isRead,
                forceWhite: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Video bubble ─────────────────────────────────────────────────────────────

class _VideoBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isRead;
  const _VideoBubble({
    required this.message,
    required this.isMe,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = message.payload?['thumbnail'] as String?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullScreenVideoPage(url: message.mediaUrl!),
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius(isMe),
        child: Stack(
          children: [
            thumb != null
                ? CachedNetworkImage(
                    imageUrl: thumb,
                    width: 220,
                    height: 165,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 220,
                      height: 165,
                      color: Colors.grey.shade800,
                    ),
                  )
                : Container(
                    width: 220,
                    height: 165,
                    color: Colors.grey.shade800,
                  ),
            // Play icon overlay
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(110),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _TimeStamp(
                  time: DateFormat('HH:mm').format(message.createdAt.toLocal()),
                  isMe: isMe,
                  isRead: isRead,
                  forceWhite: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── File bubble ──────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isRead;
  const _FileBubble({
    required this.message,
    required this.isMe,
    required this.isRead,
  });

  IconData _icon() {
    final mime = message.fileMime ?? '';
    final name = message.fileName ?? '';
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('word') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx')) {
      return Icons.description;
    }
    if (mime.contains('sheet') ||
        name.endsWith('.xls') ||
        name.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (mime.contains('image')) return Icons.image;
    if (mime.contains('audio')) return Icons.audio_file;
    if (mime.contains('video')) return Icons.video_file;
    if (mime.contains('zip') || mime.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final name =
        message.fileName ??
        message.content ??
        AppLocalizations.of(context).files;
    final size = message.fileSize;
    final sizeLabel = size != null
        ? size < 1024 * 1024
              ? '${(size / 1024).toStringAsFixed(1)} KB'
              : '${(size / 1024 / 1024).toStringAsFixed(1)} MB'
        : '';
    final bg = isMe ? _kSentBg : _kRecvBg;
    final textColor = isMe ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _downloadAndOpen(context, message.mediaUrl!, name),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF7B5EA7), Color(0xFF9575CD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : bg,
          borderRadius: _radius(isMe),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isMe ? 35 : 20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withAlpha(40)
                        : _kSentBg.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _icon(),
                    size: 22,
                    color: isMe ? Colors.white : _kSentBg,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (sizeLabel.isNotEmpty)
                        Text(
                          sizeLabel,
                          style: TextStyle(
                            color: isMe ? _kTimeOwn : _kTimeOther,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: _TimeStamp(
                time: DateFormat('HH:mm').format(message.createdAt.toLocal()),
                isMe: isMe,
                isRead: isRead,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 在 app 内下载文件到本地缓存（带进度对话框），再用系统查看器打开。
/// 失败时回退到外部浏览器。
Future<void> _downloadAndOpen(
  BuildContext context,
  String url,
  String fileName,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  // 进度对话框
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).downloading),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final dir = await getTemporaryDirectory();
    // 文件名去掉非法字符，保留扩展名，便于系统按类型打开
    final safe = fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
    final path = '${dir.path}/$safe';
    final file = File(path);

    if (!await file.exists() || await file.length() == 0) {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
      }
      await resp.pipe(file.openWrite());
      client.close();
    }

    navigator.pop(); // 关闭进度对话框
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      // 没有可打开该类型的应用等情况 → 回退浏览器
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).cannotOpen(result.message),
            kind: ToastKind.error,
          );
        }
      }
    }
  } catch (e) {
    navigator.pop();
    // 下载失败 → 回退浏览器
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).openFailed(e),
          kind: ToastKind.error,
        );
      }
    }
  }
}

/// app 内全屏视频播放页（黑底 + Chewie 播放器 + 关闭按钮）。
class _FullScreenVideoPage extends StatelessWidget {
  final String url;
  const _FullScreenVideoPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: VideoPlayerWidget(url: url, autoPlay: true)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timestamp + read receipt ─────────────────────────────────────────────────

class _TimeStamp extends StatelessWidget {
  final String time;
  final bool isMe;
  final bool isRead;
  final bool forceWhite;
  const _TimeStamp({
    required this.time,
    required this.isMe,
    required this.isRead,
    this.forceWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = forceWhite
        ? Colors.white.withAlpha(200)
        : isMe
        ? _kTimeOwn
        : _kTimeOther;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: isRead ? (forceWhite ? Colors.white : _kReadBlue) : color,
          ),
        ],
      ],
    );
  }
}

// ─── Date separator ───────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(local.year, local.month, local.day);
    if (d == today) return '今天';
    if (d == today.subtract(const Duration(days: 1))) return '昨天';
    if (now.year == local.year) return DateFormat('M月d日').format(local);
    return DateFormat('yyyy年M月d日').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─── Menu icon button (long-press context menu) ───────────────────────────────

class _MenuActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 45 : 20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Expose background color for chat screen to use
const kChatBackgroundColor = _kChatBg;
