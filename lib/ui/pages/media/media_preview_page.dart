import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class MediaPreviewPage extends StatefulWidget {
  final String mediaUrl;
  final String title;
  final bool isVideo;

  const MediaPreviewPage({
    super.key,
    required this.mediaUrl,
    required this.title,
    this.isVideo = false,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() async {
    try {
      final String fixedUrl = _getFixedMediaUrl(widget.mediaUrl);

      if (_isFilePath(fixedUrl)) {
        _videoController = VideoPlayerController.file(File(fixedUrl));
      } else {
        _videoController = VideoPlayerController.network(fixedUrl);
      }

      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  String _getFixedMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }
    return url;
  }

  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  void _togglePlayPause() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: widget.isVideo ? _buildVideoWidget() : _buildImageWidget(),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (!_isVideoInitialized || _videoController == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          if (!_isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    final String fixedUrl = _getFixedMediaUrl(widget.mediaUrl);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: _isFilePath(fixedUrl)
          ? Image.file(
              File(fixedUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                );
              },
            )
          : Image.network(
              fixedUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
