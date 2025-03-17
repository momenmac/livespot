import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/services/utils/ImageSaverUtil/image_saver.dart';

/// A simple platform-agnostic sharing utility that works on all platforms
class SimpleShare {
  /// Download or share image - platform-aware implementation
  static Future<Map<String, dynamic>> saveImage(String url,
      [String? fileName]) async {
    final name =
        fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      if (kIsWeb) {
        // On web, we can't really save directly
        return {
          'isSuccess': false,
          'message': 'Right-click to save image on web',
          'needsManualSave': true,
        };
      } else {
        // On mobile, use our ImageSaver utility
        return await ImageSaver.saveImageFromUrl(
          url,
          name: name,
        );
      }
    } catch (e) {
      print('SimpleShare error: $e');
      return {
        'isSuccess': false,
        'error': e.toString(),
      };
    }
  }
}
