import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/utils/web_utils.dart';
import 'package:flutter_application_2/utils/image_saver.dart';

/// Platform-agnostic utilities that work across web and mobile
class PlatformUtils {
  /// Download or share an image based on the current platform
  static Future<Map<String, dynamic>> saveImage({
    required String url,
    required String filename,
  }) async {
    try {
      if (kIsWeb) {
        // Web implementation
        final success = await WebUtils.downloadFile(
          url: url,
          filename: filename,
        );

        return {
          'isSuccess': success,
          'message': success
              ? 'Image opened for download'
              : 'Unable to download image',
        };
      } else {
        // Mobile implementation
        return await ImageSaver.saveImageFromUrl(
          url,
          name: filename,
        );
      }
    } catch (e) {
      print('Error in PlatformUtils.saveImage: $e');
      return {
        'isSuccess': false,
        'error': e.toString(),
      };
    }
  }
}
