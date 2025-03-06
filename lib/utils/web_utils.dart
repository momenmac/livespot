import 'package:flutter/foundation.dart' show kIsWeb;

// Only import the implementation - no conditionals
import 'web_utils_impl.dart';

/// Platform-agnostic wrapper for web utilities
class WebUtils {
  /// Download a file from a URL
  /// Only works on web platforms
  static Future<bool> downloadFile({
    required String url,
    required String filename,
  }) async {
    if (!kIsWeb) {
      print('Warning: Web download attempted on non-web platform');
      return false; // Not supported on mobile
    }

    try {
      return WebUtilsImpl.downloadFileImpl(url: url, filename: filename);
    } catch (e) {
      print('Error in WebUtils.downloadFile: $e');
      return false;
    }
  }
}
