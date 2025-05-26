import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class GalleryPreviewPage extends StatefulWidget {
  final List<String> mediaUrls;
  final String title;
  final int initialIndex;

  const GalleryPreviewPage({
    super.key,
    required this.mediaUrls,
    required this.title,
    this.initialIndex = 0,
  });

  @override
  State<GalleryPreviewPage> createState() => _GalleryPreviewPageState();
}

class _GalleryPreviewPageState extends State<GalleryPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeCurrentMedia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _isPlaying = false;
  }

  void _initializeCurrentMedia() {
    if (_currentIndex >= 0 && _currentIndex < widget.mediaUrls.length) {
      String mediaUrl = widget.mediaUrls[_currentIndex];
      if (_isVideoFile(mediaUrl)) {
        _initializeVideoPlayer(mediaUrl);
      }
    }
  }

  void _initializeVideoPlayer(String videoUrl) async {
    // First dispose any existing controller
    _disposeVideoController();

    try {
      final String fixedUrl = _getFixedMediaUrl(videoUrl);

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

  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm');
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

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _onPageChanged(int index) {
    // If the media type changed (e.g., from image to video or vice versa),
    // we need to initialize or dispose video controllers
    final bool wasVideo = _currentIndex < widget.mediaUrls.length &&
        _isVideoFile(widget.mediaUrls[_currentIndex]);
    final bool isVideo = index < widget.mediaUrls.length &&
        _isVideoFile(widget.mediaUrls[index]);

    setState(() {
      _currentIndex = index;
    });

    if (wasVideo && !isVideo) {
      // We're moving from a video to an image
      _disposeVideoController();
    } else if (!wasVideo && isVideo) {
      // We're moving from an image to a video
      _initializeVideoPlayer(widget.mediaUrls[index]);
    } else if (wasVideo && isVideo && _currentIndex != index) {
      // We're moving from a video to another video
      _initializeVideoPlayer(widget.mediaUrls[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                if (widget.mediaUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "${_currentIndex + 1}/${widget.mediaUrls.length}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.mediaUrls.length,
              itemBuilder: (context, index) {
                final String mediaUrl = widget.mediaUrls[index];
                final bool isVideo = _isVideoFile(mediaUrl);

                if (isVideo && index == _currentIndex) {
                  return _buildVideoWidget(mediaUrl);
                } else {
                  return _buildImageWidget(mediaUrl);
                }
              },
            ),

            // Media count indicator
            if (_showControls && widget.mediaUrls.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.mediaUrls.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? ThemeConstants.primaryColor
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoWidget(String videoUrl) {
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        _toggleControls();
        _togglePlayPause();
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              if (!_isPlaying && _showControls)
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
        ),
      ),
    );
  }

  Widget _buildImageWidget(String mediaUrl) {
    final String fixedUrl = _getFixedMediaUrl(mediaUrl);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
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
      ),
    );
  }
}
