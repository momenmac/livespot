import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PermissionService {
  // Singleton instance
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Check and request photo permission specifically
  Future<bool> requestPhotoPermission(BuildContext context) async {
    try {
      if (kIsWeb) return true; // Web platform doesn't need permissions

      debugPrint('🔒 Requesting photo permission...');

      if (Platform.isIOS) {
        debugPrint('🔒 iOS platform detected');
        final photoStatus = await Permission.photos.status;

        if (photoStatus.isGranted) {
          debugPrint('🔒 Photo permission already granted');
          return true;
        }

        if (photoStatus.isPermanentlyDenied) {
          debugPrint(
              '🔒 Photo permission permanently denied, showing settings dialog');
          if (context.mounted) {
            await _showOpenSettingsDialog(
              context: context,
              title: 'Photo Access Required',
              message:
                  'Please enable photo access in your device settings to continue.',
            );
          }
          return false;
        }

        final requestedStatus = await Permission.photos.request();
        debugPrint(
            '🔒 Photo permission request result: ${requestedStatus.name}');
        return requestedStatus.isGranted;
      }

      if (Platform.isAndroid) {
        debugPrint('🔒 Android platform detected');

        // For Android 13+ (API 33+), try photos permission first
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted) {
          debugPrint('🔒 Photos permission granted on Android 13+');
          return true;
        }

        // For Android 12 and below, or if photos permission failed
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          debugPrint('🔒 Storage permission granted on Android');
          return true;
        }

        // If both permissions are permanently denied
        if (storageStatus.isPermanentlyDenied ||
            photosStatus.isPermanentlyDenied) {
          debugPrint(
              '🔒 Permissions permanently denied, showing settings dialog');
          if (context.mounted) {
            await _showOpenSettingsDialog(
              context: context,
              title: 'Storage Access Required',
              message:
                  'Please enable storage access in your device settings to continue.',
            );
          }
          return false;
        }

        debugPrint('🔒 All permission requests failed');
        return false;
      }

      // Other platforms
      return true;
    } catch (e) {
      debugPrint('🔒 Error requesting photo permission: $e');
      return false;
    }
  }

  // Check and request camera permission
  Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      if (kIsWeb) return true;

      debugPrint('🔒 Requesting camera permission...');

      final status = await Permission.camera.status;

      if (status.isGranted) {
        debugPrint('🔒 Camera permission already granted');
        return true;
      }

      if (status.isPermanentlyDenied) {
        debugPrint(
            '🔒 Camera permission permanently denied, showing settings dialog');
        if (context.mounted) {
          await _showOpenSettingsDialog(
            context: context,
            title: 'Camera Access Required',
            message:
                'Please enable camera access in your device settings to continue.',
          );
        }
        return false;
      }

      final result = await Permission.camera.request();
      debugPrint('🔒 Camera permission request result: ${result.name}');
      return result.isGranted;
    } catch (e) {
      debugPrint('🔒 Error requesting camera permission: $e');
      return false;
    }
  }

  // Method specifically for saving to gallery
  Future<bool> requestSaveToGalleryPermission(BuildContext context) async {
    try {
      if (kIsWeb) return true;

      debugPrint('🔒 Requesting save to gallery permission...');

      if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted && context.mounted) {
          await _showOpenSettingsDialog(
            context: context,
            title: 'Gallery Access Required',
            message: 'Please enable gallery access to save photos.',
          );
        }
        return status.isGranted;
      }

      if (Platform.isAndroid) {
        // Try photos permission first (Android 13+)
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted) return true;

        // Fall back to storage permission
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted && context.mounted) {
          await _showOpenSettingsDialog(
            context: context,
            title: 'Storage Access Required',
            message: 'Please enable storage access to save photos.',
          );
        }
        return storageStatus.isGranted;
      }

      return true;
    } catch (e) {
      debugPrint('🔒 Error requesting save to gallery permission: $e');
      return false;
    }
  }

  // Helper method to select photo with proper permission handling
  Future<XFile?> pickImage({
    required BuildContext context,
    required ImageSource source,
  }) async {
    try {
      debugPrint('🔒 Attempting to pick image from ${source.name}');
      bool permissionGranted = false;

      if (source == ImageSource.gallery) {
        permissionGranted = await requestPhotoPermission(context);
      } else if (source == ImageSource.camera) {
        permissionGranted = await requestCameraPermission(context);
      }

      if (!permissionGranted) {
        debugPrint('🔒 Permission not granted for ${source.name}');
        return null;
      }

      // Permission granted, proceed with image selection
      final picker = ImagePicker();
      debugPrint('🔒 Picking image from ${source.name}');
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) {
        debugPrint('🔒 No image was picked');
      } else {
        debugPrint('🔒 Image picked successfully: ${pickedFile.path}');
      }

      return pickedFile;
    } catch (e) {
      debugPrint('🔒 Error picking image: $e');
      return null;
    }
  }

  Future<void> _showOpenSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}
