import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool autoPlay;

  const VideoPlayerWidget({super.key, required this.url, this.autoPlay = false});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _vpc;
  ChewieController? _chewieCtrl;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _vpc.initialize();
      _chewieCtrl = ChewieController(
        videoPlayerController: _vpc,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: true,
        allowedScreenSleep: false,
        aspectRatio: _vpc.value.aspectRatio,
        placeholder: Container(color: Colors.black),
      );
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white, size: 40),
        ),
      );
    }
    if (!_initialized) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return AspectRatio(
      aspectRatio: _vpc.value.aspectRatio,
      child: Chewie(controller: _chewieCtrl!),
    );
  }
}

/// 视频缩略图（列表用，点击后展开播放）
class VideoThumbnailWidget extends StatefulWidget {
  final String url;

  const VideoThumbnailWidget({super.key, required this.url});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    if (_playing) {
      return VideoPlayerWidget(url: widget.url, autoPlay: true);
    }
    return GestureDetector(
      onTap: () => setState(() => _playing = true),
      child: Container(
        height: 220,
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}
