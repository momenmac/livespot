import 'package:flutter/foundation.dart' show kIsWeb;

// Only import web-specific libraries when on web
// The stub import is ignored when running on web
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_impl.dart';

/// WebUtils provides safe access to web-specific functionality
/// while maintaining compatibility with mobile platforms
class WebUtils {
  /// Downloads a file from a URL on web platforms
  /// Returns true if download was initiated successfully
  static Future<bool> downloadFile({
    required String url,
    required String filename,
  }) async {
    // If not on web, return false immediately
    if (!kIsWeb) return false;

    // Call the platform-specific implementation
    return downloadFileImpl(url: url, filename: filename);
  }

  /// Opens a URL in a new tab/window on web platforms
  static Future<bool> openUrl(String url) async {
    // If not on web, return false immediately
    if (!kIsWeb) return false;

    // Call the platform-specific implementation
    return openUrlImpl(url);
  }
}
