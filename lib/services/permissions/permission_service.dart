import 'package:flutter/material.dart';
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
      // On Android 13+ we need READ_MEDIA_IMAGES, on older Android we need storage permissions
      // On iOS we need photos permission
      Permission requiredPermission;

      if (Platform.isAndroid) {
        // Simply check the Android version directly instead of using the plugin's detection
        final androidVersion =
            int.tryParse(Platform.operatingSystemVersion.split(' ').first) ?? 0;
        debugPrint('🔒 Android version detected: $androidVersion');

        if (androidVersion >= 33) {
          // Android 13 is API 33
          debugPrint('🔒 Using READ_MEDIA_IMAGES permission for Android 13+');
          // For Android 13+, directly request the permission without checking
          final status = await Permission.photos.request();
          return status.isGranted;
        } else {
          debugPrint('🔒 Using storage permission for Android 12 or below');
          // For Android 12 and below, use storage permission
          requiredPermission = Permission.storage;
        }
      } else if (Platform.isIOS) {
        requiredPermission = Permission.photos;
      } else {
        // Other platforms - assume permission is granted
        return true;
      }

      // Check permission status
      final status = await requiredPermission.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(
          context: context,
          title: 'Photo Access Required',
          message:
              'This app needs access to your photos to share images. Please enable it in settings.',
        );
        return false;
      }

      // Request permission
      final result = await requiredPermission.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('🔒 Error requesting photo permission: $e');
      // Fallback to using image_picker directly which has its own permission handling
      return true;
    }
  }

  // New method specifically for saving to gallery
  Future<bool> requestSaveToGalleryPermission(BuildContext context) async {
    try {
      Permission requiredPermission;

      if (Platform.isAndroid) {
        final androidVersion =
            int.tryParse(Platform.operatingSystemVersion.split(' ').first) ?? 0;

        if (androidVersion >= 33) {
          // For Android 13+, directly request the permission
          final status = await Permission.photos.request();
          return status.isGranted;
        } else {
          requiredPermission = Permission.storage;
        }
      } else if (Platform.isIOS) {
        requiredPermission = Permission.photos;
      } else {
        return true;
      }

      final status = await requiredPermission.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          _showOpenSettingsDialog(
            context: context,
            title: 'Gallery Access Required',
            message:
                'Permission to access your gallery is required to save images. Please enable it in settings.',
          );
        }
        return false;
      }

      // Request permission
      final result = await requiredPermission.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('🔒 Error requesting save to gallery permission: $e');
      return true;
    }
  }

  // Check and request camera permission
  Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      final permissionStatus = await Permission.camera.status;

      if (permissionStatus.isGranted) {
        return true;
      }

      if (permissionStatus.isPermanentlyDenied) {
        _showOpenSettingsDialog(
            context: context,
            title: 'Camera Access Required',
            message:
                'This app needs access to your camera to take photos. Please enable it in settings.');
        return false;
      }

      final result = await Permission.camera.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('🔒 Error requesting camera permission: $e');
      return true;
    }
  }

  // Helper method to select photo with proper permission handling
  Future<XFile?> pickImage({
    required BuildContext context,
    required ImageSource source,
  }) async {
    try {
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
      return await picker.pickImage(source: source);
    } catch (e) {
      debugPrint('🔒 Error picking image: $e');

      // If there was a permission error but we have the manifest permissions,
      // try again with image_picker's built-in permission handling as fallback
      try {
        final picker = ImagePicker();
        return await picker.pickImage(source: source);
      } catch (innerError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error selecting image: ${e.toString()}')),
          );
        }
        return null;
      }
    }
  }

  // Show dialog to open settings
  void _showOpenSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
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
