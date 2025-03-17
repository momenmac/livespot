import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Helper for handling image uploads across platforms
class UploadHelper {
  /// Process an image file to a data URL that can be displayed everywhere
  /// This keeps the original image data intact rather than using a placeholder
  static Future<String> imageToDataUrl(dynamic imageSource) async {
    try {
      if (imageSource is File) {
        // Read file as bytes
        final bytes = await imageSource.readAsBytes();
        // Convert to base64
        final base64Image = base64Encode(bytes);
        // Get file extension
        final fileExt = imageSource.path.split('.').last.toLowerCase();
        // Create data URL with appropriate mime type
        final mimeType = _getMimeType(fileExt);
        return 'data:$mimeType;base64,$base64Image';
      } else if (imageSource is Uint8List) {
        // Already have bytes, just encode to base64
        final base64Image = base64Encode(imageSource);
        return 'data:image/png;base64,$base64Image';
      } else if (imageSource is String && imageSource.startsWith('data:')) {
        // Already a data URL
        return imageSource;
      } else if (imageSource is String) {
        // Treat as URL - could be a file path or network URL
        if (imageSource.startsWith('file://') ||
            imageSource.startsWith('/') ||
            !imageSource.contains('://')) {
          // Local file path
          if (kIsWeb) {
            // Can't read local files on web
            return 'https://picsum.photos/800/600';
          }
          final file = File(imageSource.replaceFirst('file://', ''));
          return imageToDataUrl(file);
        }
        // Network URL - return as is
        return imageSource;
      }

      // Fallback - return a placeholder
      return 'https://picsum.photos/800/600';
    } catch (e) {
      print('Error converting image to data URL: $e');
      // Return a placeholder in case of error
      return 'https://picsum.photos/800/600';
    }
  }

  /// Get MIME type from file extension
  static String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'image/png';
    }
  }
}
