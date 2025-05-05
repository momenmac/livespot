import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/utils/url_utils.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
// Added for repaintBoundary
import 'package:flutter_application_2/services/permissions/permission_service.dart'; // Fixed import path

class ImagePreviewPage extends StatefulWidget {
  final String imageUrl;
  final String? caption;
  final String imageId; // Used for hero animations

  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    this.caption,
    required this.imageId,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showControls = true;
  final TransformationController _transformController =
      TransformationController();
  bool _isDownloading = false;
  bool _zoomedIn = false;
  String? _errorMessage;

  // For image size info
  Size? _imageSize;

  // Add a key for repaintBoundary
  final GlobalKey _imageKey = GlobalKey();

  // Process image URL using client-side API URLs
  String _getProcessedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Always keep Firebase Storage URLs as they are
    if (url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com')) {
      return url;
    }

    // Handle any localhost or IP-based URLs
    if (url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('192.168.')) {
      // Extract path from URL
      Uri uri = Uri.parse(url);
      String path = uri.path;
      // Ensure no leading slash for concatenation
      path = path.startsWith('/') ? path.substring(1) : path;

      return '${ApiUrls.baseUrl}/$path';
    }

    // For relative paths or already fixed URLs
    return UrlUtils.fixUrl(url);
  }

  @override
  void initState() {
    super.initState();

    // Setup animations for controls fade in/out
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Schedule a task to get image dimensions
    _loadImageInfo();
  }

  Future<void> _loadImageInfo() async {
    try {
      final processedUrl = _getProcessedImageUrl(widget.imageUrl);
      if (kIsWeb) {
        // On web, we don't have a good way to get image dimensions before loading
        // So we'll leave it without dimensions for now
        return;
      }

      // For mobile/desktop, attempt to get the image dimensions
      final response = await http.get(Uri.parse(processedUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final image = await decodeImageFromList(bytes);
        if (mounted) {
          setState(() {
            _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load image information';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controller.reverse(); // Show controls (animate to fully visible)
      } else {
        _controller.forward(); // Hide controls (animate to fully hidden)
      }
    });
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    // Check if user is zoomed in or not
    final scale = _transformController.value.getMaxScaleOnAxis();
    final wasZoomed = _zoomedIn;
    _zoomedIn = scale > 1.1;

    // If zoom state changed, update the UI
    if (wasZoomed != _zoomedIn && mounted) {
      setState(() {});
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final wasZoomed = _zoomedIn;

    // If the scale is close to 1, snap back to default position and consider it zoomed out
    if (scale < 1.1) {
      _transformController.value = Matrix4.identity();
      _zoomedIn = false;
    } else {
      _zoomedIn = true;
    }

    // If zoom state changed, update the UI
    if (wasZoomed != _zoomedIn && mounted) {
      setState(() {});
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _zoomedIn = false;
    });
  }

  // More robust cross-platform downloading implementation with better iOS support
  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final processedUrl = _getProcessedImageUrl(widget.imageUrl);

      // Web implementation using URL launcher
      if (kIsWeb) {
        await _downloadOnWeb(processedUrl);
        return;
      }

      // Mobile/Desktop implementation
      final response = await http.get(Uri.parse(processedUrl));
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download image: HTTP ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      final fileName = _sanitizedFileName(widget.imageUrl);

      // Platform-specific saving
      if (Platform.isAndroid || Platform.isIOS) {
        // Save to gallery on mobile using in-code solution
        await _saveToGalleryInCode(bytes, fileName);
      } else {
        // Save to downloads folder on desktop
        await _saveToDownloads(bytes, fileName);
      }

      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: 'Image saved successfully',
        );
      }
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to download image. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  // Web-specific download using URL launcher
  Future<void> _downloadOnWeb(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (mounted) {
          ResponsiveSnackBar.showInfo(
            context: context,
            message: 'Opening image in new tab for download',
          );
        }
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to open download link: $e',
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  // New in-code implementation for saving to gallery
  Future<void> _saveToGalleryInCode(Uint8List bytes, String fileName) async {
    try {
      // Use our improved PermissionService to handle photo permissions
      final permissionService = PermissionService();
      bool granted = await permissionService.requestPhotoPermission(context);

      if (!granted) {
        throw Exception(
            "Permission to access photos is required to save images.");
      }

      // Try to save the image - first create a temporary file
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Use Share.shareXFiles to give the user control over where to save the file
      // This is more reliable across platforms than direct saving
      final xFile = XFile(filePath);

      if (mounted) {
        ResponsiveSnackBar.showInfo(
          context: context,
          message:
              "Please select 'Save to Photos' or similar option in the share menu",
        );
      }

      await Share.shareXFiles(
        [xFile],
        text: 'Save this image to your photos',
      );
    } catch (e) {
      print('❌ Error saving image to gallery: $e');
      rethrow;
    }
  }

  // Desktop-specific saving to downloads folder
  Future<void> _saveToDownloads(Uint8List bytes, String fileName) async {
    late Directory directory;

    if (Platform.isMacOS || Platform.isLinux) {
      directory = Directory('${Platform.environment['HOME']}/Downloads');
    } else if (Platform.isWindows) {
      directory =
          Directory('${Platform.environment['USERPROFILE']}\\Downloads');
    } else {
      // Fallback to temp directory
      directory = await getTemporaryDirectory();
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
  }

  String _sanitizedFileName(String url) {
    // Get the file name from the URL
    final uri = Uri.parse(url);
    String fileName = path.basename(uri.path);

    // Remove query parameters if present in the filename
    if (fileName.contains('?')) {
      fileName = fileName.split('?')[0];
    }

    // If the filename looks problematic, generate a timestamp-based filename
    if (fileName.isEmpty || !fileName.contains('.')) {
      // Try to determine the file extension from content-type or default to jpg
      final extension = uri.path.toLowerCase().endsWith('.png')
          ? 'png'
          : uri.path.toLowerCase().endsWith('.gif')
              ? 'gif'
              : uri.path.toLowerCase().endsWith('.webp')
                  ? 'webp'
                  : 'jpg';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'image_$timestamp.$extension';
    }

    return fileName;
  }

  Future<void> _shareImage() async {
    if (kIsWeb) {
      ResponsiveSnackBar.showInfo(
        context: context,
        message: 'Sharing not fully supported on web',
      );
      return;
    }

    try {
      setState(() {
        _isDownloading = true;
      });

      ResponsiveSnackBar.showInfo(
        context: context,
        message: 'Preparing to share...',
      );

      final processedUrl = _getProcessedImageUrl(widget.imageUrl);
      final response = await http.get(Uri.parse(processedUrl));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download for sharing: HTTP ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = _sanitizedFileName(widget.imageUrl);
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: widget.caption ?? '',
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to share image: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final processedUrl = _getProcessedImageUrl(widget.imageUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with hero animation
            Center(
              child: Hero(
                tag:
                    'image-preview-${widget.imageId}-${widget.imageUrl.hashCode}',
                child: RepaintBoundary(
                  key: _imageKey,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.5,
                    maxScale: 5.0,
                    onInteractionUpdate: _handleInteractionUpdate,
                    onInteractionEnd: _handleInteractionEnd,
                    // Don't add GestureDetector here - it interferes with InteractiveViewer zoom
                    child: CachedNetworkImage(
                      imageUrl: processedUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: ThemeConstants.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image\n$error',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            // Show the URL that failed
                            Text(
                              'URL: ${url.length > 50 ? '${url.substring(0, 50)}...' : url}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Caption at the bottom
            if (widget.caption != null && widget.caption!.isNotEmpty)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 1 - _animation.value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          widget.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Top controls (app bar)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 1 - _animation.value,
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                        left: 8,
                        right: 8,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),

                          // Title and image info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Image Preview',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_imageSize != null)
                                  Text(
                                    '${_imageSize!.width.toInt()} × ${_imageSize!.height.toInt()} px',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Reset zoom button (only visible when zoomed in)
                          if (_zoomedIn)
                            IconButton(
                              icon: const Icon(Icons.zoom_out_map,
                                  color: Colors.white),
                              onPressed: _resetZoom,
                              tooltip: 'Reset Zoom',
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bottom controls
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  bottom: MediaQuery.of(context).padding.bottom,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 1 - _animation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Close button with label
                          _ActionButton(
                            icon: Icons.close,
                            label: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                          ),

                          // Download button with label
                          _ActionButton(
                            icon: _isDownloading ? null : Icons.file_download,
                            label:
                                _isDownloading ? 'Downloading...' : 'Download',
                            onPressed: _isDownloading ? null : _downloadImage,
                            isLoading: _isDownloading,
                          ),

                          // Share button with label
                          _ActionButton(
                            icon: Icons.share,
                            label: 'Share',
                            onPressed: _shareImage,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for action buttons
class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
