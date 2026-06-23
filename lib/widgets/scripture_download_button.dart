import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/local_cache.dart';
import '../services/scripture_download_service.dart';
import 'premium_toast.dart';

/// 经书下载按钮：未下载→下载图标；下载中→进度圈；已下载→对勾。
class ScriptureDownloadButton extends StatefulWidget {
  final String scriptureId;
  final Color? color;

  const ScriptureDownloadButton({
    super.key,
    required this.scriptureId,
    this.color,
  });

  @override
  State<ScriptureDownloadButton> createState() =>
      _ScriptureDownloadButtonState();
}

class _ScriptureDownloadButtonState extends State<ScriptureDownloadButton> {
  final _svc = ScriptureDownloadService.instance;
  bool _downloaded = false;
  bool _downloading = false;
  double _progress = 0;

  Color get _color =>
      widget.color ?? IconTheme.of(context).color ?? Colors.white;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant ScriptureDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptureId != widget.scriptureId) {
      _downloaded = false;
      _downloading = false;
      _progress = 0;
      _check();
    }
  }

  Future<void> _check() async {
    final d = await _svc.isDownloaded(widget.scriptureId);
    if (mounted) setState(() => _downloaded = d);
  }

  Future<void> _start() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final t = AppLocalizations.of(context);
    try {
      await _svc.download(
        widget.scriptureId,
        onProgress: (done, total) {
          if (mounted && total > 0) {
            setState(() => _progress = done / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _downloaded = true;
          _downloading = false;
        });
        showPremiumToast(context, t.downloadComplete, kind: ToastKind.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        showErrorIfNotNetwork(context, e, t.downloadFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: _progress == 0 ? null : _progress,
              color: _color,
              backgroundColor: _color.withAlpha(60),
            ),
          ),
        ),
      );
    }
    if (_downloaded) {
      return IconButton(
        icon: Icon(Icons.download_done_rounded, color: _color),
        tooltip: AppLocalizations.of(context).downloadedOffline,
        onPressed: () => showPremiumToast(
          context,
          AppLocalizations.of(context).downloadedOffline,
          kind: ToastKind.info,
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.download_rounded, color: _color),
      tooltip: AppLocalizations.of(context).downloadForOffline,
      onPressed: _start,
    );
  }
}
