import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/utils/url_utils.dart';
import 'package:flutter_application_2/ui/pages/messages/image_preview_page.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageMessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final VoidCallback? onTap;
  final Function(Message)? onLongPress;
  final Function(Message)? onSwipeReply;

  const ImageMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.onTap,
    this.onLongPress,
    this.onSwipeReply,
  });

  // Helper method to process image URL
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
  Widget build(BuildContext context) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      // Fallback if no media URL is available
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSent
              ? ThemeConstants.primaryColor
              : ThemeConstants.lightCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Image unavailable',
            style: TextStyle(color: Colors.white)),
      );
    }

    // Process the image URL before using it
    final processedImageUrl = _getProcessedImageUrl(message.mediaUrl);

    return GestureDetector(
      onTap: () {
        // Enhanced debug information
        debugPrint('🖼️ IMAGE TAPPED - ID: ${message.id}');
        debugPrint('🖼️ Original URL: ${message.mediaUrl}');
        debugPrint('🖼️ Processed URL: $processedImageUrl');

        // Show visual feedback that tap was registered
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening image preview...'),
            duration: Duration(seconds: 1),
          ),
        );

        // Direct navigation to ImagePreviewPage with short delay for visual feedback
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ImagePreviewPage(
                imageUrl: processedImageUrl,
                caption: message.content != 'Image' ? message.content : null,
                imageId: message.id,
              ),
            ),
          );
        });
      },
      onLongPress: () => onLongPress != null ? onLongPress!(message) : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          color: isSent
              ? ThemeConstants.primaryColor.withOpacity(0.5)
              : ThemeConstants.lightCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image
              Hero(
                tag:
                    'image-preview-${message.id}-${message.mediaUrl?.hashCode}',
                child: CachedNetworkImage(
                  imageUrl: processedImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error),
                        const SizedBox(height: 8),
                        Text('Error: ${error.toString().split(':')[0]}',
                            textAlign: TextAlign.center)
                      ],
                    ),
                  ),
                ),
              ),

              // Caption overlay at bottom if present
              if (message.content.isNotEmpty && message.content != 'Image')
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
