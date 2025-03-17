import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ImageSaver {
  /// Save network image to local storage or share it
  static Future<Map<String, dynamic>> saveImage(
    dynamic imageData, {
    int quality = 80,
    String? name,
    bool share = true,
  }) async {
    try {
      final fileName =
          name ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Get temporary directory to store the image
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/$fileName';

      // Handle different input types
      if (imageData is String) {
        // It's a URL, download it first
        final response = await Dio().get(
          imageData,
          options: Options(responseType: ResponseType.bytes),
        );
        imageData = response.data;
      }

      // Save file locally
      final file = File(path);
      if (imageData is Uint8List) {
        await file.writeAsBytes(imageData);
      } else {
        throw Exception('Unsupported image data format');
      }

      if (share) {
        // Share using share_plus (works on Android, iOS)
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Save or share this image',
        );
        return {'isSuccess': true, 'filePath': path};
      } else {
        // Just return the path for other operations
        return {'isSuccess': true, 'filePath': path};
      }
    } catch (e) {
      print('Error in ImageSaver: $e');
      return {'isSuccess': false, 'error': e.toString()};
    }
  }

  /// Download image from URL and save/share it
  static Future<Map<String, dynamic>> saveImageFromUrl(
    String imageUrl, {
    String? name,
    bool share = true,
  }) async {
    try {
      // Request storage permission
      if (!kIsWeb && !Platform.isIOS) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          return {'isSuccess': false, 'error': 'Permission denied'};
        }
      }

      // Download and save
      return await saveImage(
        imageUrl,
        name: name,
        share: share,
      );
    } catch (e) {
      print('Error saving image from URL: $e');
      return {'isSuccess': false, 'error': e.toString()};
    }
  }
}
