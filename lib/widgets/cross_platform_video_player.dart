import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class CrossPlatformVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const CrossPlatformVideoPlayer({required this.videoUrl, Key? key})
      : super(key: key);

  @override
  State<CrossPlatformVideoPlayer> createState() =>
      _CrossPlatformVideoPlayerState();
}

class _CrossPlatformVideoPlayerState extends State<CrossPlatformVideoPlayer> {
  Player? _player;
  VideoController? _controller;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _player = Player();
      _controller = VideoController(_player!);
      _player!.open(Media(widget.videoUrl));
    } else {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      _videoPlayerController!.initialize().then((_) {
        setState(() {});
      });
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
      );
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _controller != null
          ? AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: _controller!),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      if (_chewieController != null &&
          _videoPlayerController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
  }
}
