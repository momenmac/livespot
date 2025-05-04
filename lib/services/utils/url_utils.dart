import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

/// Utility class for handling URLs in the app
class UrlUtils {
  /// Fixes URLs that might be using localhost or relative paths
  /// to use the correct base URL for the current platform
  static String fixUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    // Always keep Firebase Storage URLs as they are
    if (url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com')) {
      return url;
    }

    // Handle absolute URLs that aren't Firebase
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Replace localhost URLs with the platform-specific base URL
      if (url.contains('localhost') ||
          url.contains('127.0.0.1') ||
          url.contains('192.168.')) {
        // Extract path: Remove protocol and domain parts
        Uri uri = Uri.parse(url);
        String path = uri.path;
        // Ensure no leading slash for concatenation
        path = path.startsWith('/') ? path.substring(1) : path;

        return '${ApiUrls.baseUrl}/$path';
      }
      return url; // Keep other external URLs as they are
    }

    // For relative paths (without http:// or https://)
    String path = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiUrls.baseUrl}/$path';
  }
}
