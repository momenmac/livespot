import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:intl/intl.dart';

// Properly import web utilities - this will be ignored on mobile
import 'package:flutter_application_2/services/utils/ImageSaverUtil/simple_share.dart';
import 'package:flutter_application_2/services/utils/ImageSaverUtil/image_path_helper.dart';

class ImageMessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final VoidCallback? onLongPress;
  final Function(Message)? onReply;

  const ImageMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.onLongPress,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final imageUrl = ImagePathHelper.getValidImageUrl(message.mediaUrl);

    // Determine bubble background and text colors
    final bubbleColor = isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;

    final textColor = isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image content with better styling
                ClipRRect(
                  // Rounded corners that match the containing bubble
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, imageUrl),
                    child: Hero(
                      tag: 'image_${message.id}',
                      child: _buildImageContent(context, imageUrl, isDarkMode),
                    ),
                  ),
                ),

                // Caption and timestamp
                if (message.content != 'Image message' &&
                    message.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                      ),
                    ),
                  ),

                // Timestamp and status - better alignment and styling
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor?.withOpacity(0.7),
                        ),
                      ),
                      if (isSent)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _buildStatusIcon(message.status, textColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(
      BuildContext context, String imageUrl, bool isDarkMode) {
    // Handle data URLs specially for better performance
    if (imageUrl.startsWith('data:image/')) {
      return Image.memory(
        base64Decode(imageUrl.split(',')[1]),
        fit: BoxFit.cover,
        height: 220,
        width: 280,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading data URL image: $error');
          return _buildImageErrorWidget(isDarkMode);
        },
      );
    }

    // Handle regular URLs
    return CachedNetworkImage(
      imageUrl: imageUrl,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      cacheKey: imageUrl.contains(' ') ? null : imageUrl,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => _buildImageLoadingWidget(isDarkMode),
      errorWidget: (context, url, error) {
        print('Image error: $error, URL: $url');
        return Image.network(
          'https://picsum.photos/400',
          fit: BoxFit.cover,
          height: 220,
          width: 280,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorWidget(isDarkMode);
          },
        );
      },
      fit: BoxFit.cover,
      height: 220,
      width: 280,
      imageBuilder: (context, imageProvider) => Container(
        height: 220,
        width: 280,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageLoadingWidget(bool isDarkMode) {
    return Container(
      height: 220,
      width: 280,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: ThemeConstants.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildImageErrorWidget(bool isDarkMode) {
    return Container(
      height: 220,
      width: 280,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    // Apply extra URL validation to avoid encoding issues
    final processedUrl = ImagePathHelper.getValidImageUrl(imageUrl);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true, // Make fully opaque (not transparent)
        barrierColor: Colors.black, // Pure black barrier
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black, // Fully black background
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download_outlined,
                          color: Colors.white),
                    ),
                    onPressed: () => _downloadImage(context, processedUrl),
                  ),
                ],
              ),
              body: Container(
                color: Colors.black, // Ensure body is also black
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Hero(
                      tag: 'image_${message.id}',
                      child: CachedNetworkImage(
                        imageUrl: processedUrl,
                        // Add error handling
                        memCacheWidth: 1200,
                        errorWidget: (context, url, error) {
                          print('Fullscreen image error: $error');
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  color: Colors.white70, size: 60),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          );
                        },
                        placeholder: (context, url) => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white70),
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // Updated to use our simpler utility
  void _downloadImage(BuildContext context, String imageUrl) async {
    final processedUrl = ImagePathHelper.getValidImageUrl(imageUrl);
    try {
      ResponsiveSnackBar.showInfo(
        context: context,
        message: TextStrings.imageDownloadInProgress,
      );

      final result = await SimpleShare.saveImage(
        processedUrl,
        'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result['isSuccess'] == true) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: TextStrings.imageDownloaded,
        );
      } else if (result['needsManualSave'] == true) {
        // Special case for web
        ResponsiveSnackBar.showInfo(
          context: context,
          message: TextStrings.imageSaveManually,
        );
      } else {
        throw Exception(result['error'] ?? 'Failed to save image');
      }
    } catch (e) {
      print('Error downloading image: $e');
      ResponsiveSnackBar.showError(
        context: context,
        message: TextStrings.imageDownloadFailed,
      );
    }
  }

  Widget _buildStatusIcon(MessageStatus status, Color? color) {
    final iconColor = color ?? Colors.white70;

    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: 12,
          color: iconColor.withOpacity(0.7),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 12,
          color: iconColor.withOpacity(0.7),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 12,
          color: iconColor.withOpacity(0.7),
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlueAccent,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 12,
          color: ThemeConstants.red,
        );
    }
  }
}
