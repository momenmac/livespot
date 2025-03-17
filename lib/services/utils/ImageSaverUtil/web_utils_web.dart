// This file is only imported on web platforms
import 'dart:html' as html;

/// Web-specific implementation
class WebUtilsImpl {
  /// Implementation for web platform using dart:html
  static Future<bool> downloadFileImpl({
    required String url,
    required String filename,
  }) async {
    try {
      // Create anchor element with download attribute
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..setAttribute('target', '_blank');

      // Append to body, click and remove
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      return true;
    } catch (e) {
      print('Error downloading file on web: $e');
      return false;
    }
  }
}
