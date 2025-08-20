// ✅ File: lib/linker/http_api.dart
import 'dart:convert';
import 'package:fball/constants/linkapi.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class HttpApi {
  static Future<Map<String, dynamic>> downloadVideo(String url) async {
    print('=== Download Video Request ===');
    print('URL: $url');
    final uri = Uri.parse('$downloadBaseUrl/download');
    print('Request URI: $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'url': url}),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to download video: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    print('=== Upload File Request ===');
    print('File path: $filePath');
    final uri = Uri.parse('$downloadBaseUrl/upload');
    print('Request URI: $uri');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to upload file: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSummaries() async {
    print('=== Fetch Summaries Request ===');
    final uri = Uri.parse('$fastApiBaseUrl/summaries');
    print('Request URI: $uri');

    final response = await http.get(uri);
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      print('Decoded data: $data');
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('فشل في تحميل الملخصات: ${response.body}');
    }
  }
}

class VideoPlayerScreen extends StatelessWidget {
  final String videoUrl;
  const VideoPlayerScreen({required this.videoUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title:
            const Text('تشغيل الفيديو', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: CrossPlatformVideoPlayer(videoUrl: videoUrl),
      ),
    );
  }
}

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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.videoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image,
                      color: Colors.white, size: 64),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
  }
}
