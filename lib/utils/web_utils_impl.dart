// This file is only used on web
import 'dart:html' as html;

/// Web implementation of downloadFile
Future<bool> downloadFileImpl({
  required String url,
  required String filename,
}) async {
  try {
    // Create a download anchor
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = filename;

    // Add to DOM and trigger click
    html.document.body?.append(anchor);
    anchor.click();

    // Clean up - remove the element after a short delay
    await Future.delayed(const Duration(milliseconds: 100));
    anchor.remove();

    return true;
  } catch (e) {
    print('Error in web download implementation: $e');

    // Try simple open in new tab as fallback
    try {
      html.window.open(url, '_blank');
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Web implementation of openUrl
Future<bool> openUrlImpl(String url) async {
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (e) {
    print('Error opening URL in web: $e');
    return false;
  }
}
