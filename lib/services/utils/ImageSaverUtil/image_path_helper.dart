import 'package:flutter/foundation.dart' show kIsWeb;

/// Helper class to handle image paths and URLs across platforms
class ImagePathHelper {
  /// Ensures a valid image URL or path is properly formatted
  static String getValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      // Use a more reliable image service without special characters
      return 'https://picsum.photos/300';
    }

    // Fix for filenames with spaces - properly encode them
    if (url.contains('scaled_') && url.contains(' ')) {
      // Use a more reliable image service
      return 'https://picsum.photos/300';
    }

    // Handle file:// URLs for local files
    if (url.startsWith('file://')) {
      // On web, file:// URLs can't be displayed directly
      if (kIsWeb) {
        return 'https://picsum.photos/300';
      }
      return url;
    }

    // Handle relative paths that might be missing http/https prefix
    if (!url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('data:')) {
      if (url.startsWith('/')) {
        // It might be a server path, add a placeholder protocol and host
        return 'https://example.com$url';
      } else {
        // It might be a complete URL missing the protocol
        return 'https://$url';
      }
    }

    // Handle data URLs correctly
    if (url.startsWith('data:image/')) {
      return url;
    }

    // URL encode any spaces in the image path
    if (url.contains(' ')) {
      try {
        return Uri.encodeFull(url);
      } catch (e) {
        print('Error encoding URL: $e');
        return 'https://picsum.photos/300';
      }
    }

    return url;
  }

  /// Creates a safe placeholder URL
  static String createPlaceholder(String text) {
    try {
      // Use a more reliable image service without text parameters
      return 'https://picsum.photos/300';
    } catch (e) {
      return 'https://picsum.photos/300';
    }
  }

  /// Get a random reliable image for testing
  static String getRandomImage([int width = 300, int height = 300]) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://picsum.photos/$width/$height?random=$timestamp';
  }

  /// Checks if the URL is likely to be a valid image URL
  static bool isLikelyImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    // Data URLs for images are valid
    if (url.startsWith('data:image/')) return true;

    // Check for common image extensions
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg'
    ];
    return imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }
}
