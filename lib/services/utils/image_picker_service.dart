import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery
  Future<XFile?> pickImageFromGallery({
    BuildContext? context,
    int imageQuality = 80,
    double? maxWidth = 1200,
    double? maxHeight = 1200,
  }) async {
    // Check for gallery permission on Android and iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (context != null && context.mounted) {
          ResponsiveSnackBar.showError(
            context: context,
            message: 'Gallery permission is required to select images',
          );
        }
        return null;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      return image;
    } catch (e) {
      if (context != null && context.mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error selecting image: $e',
        );
      }
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Take a picture using the camera
  Future<XFile?> takePhotoWithCamera({
    BuildContext? context,
    int imageQuality = 80,
    double? maxWidth = 1200,
    double? maxHeight = 1200,
  }) async {
    // Check for camera permission on Android and iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (context != null && context.mounted) {
          ResponsiveSnackBar.showError(
            context: context,
            message: 'Camera permission is required to take photos',
          );
        }
        return null;
      }
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        preferredCameraDevice: CameraDevice.rear,
      );

      return photo;
    } catch (e) {
      if (context != null && context.mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error taking photo: $e',
        );
      }
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  /// Pick media (image or video) from gallery with unified interface
  Future<XFile?> pickMediaFromGallery({
    required String mediaType, // 'image' or 'video'
    BuildContext? context,
    int imageQuality = 80,
    double? maxWidth = 1200,
    double? maxHeight = 1200,
    Duration? maxVideoDuration = const Duration(minutes: 10),
  }) async {
    // Check for gallery permission on Android and iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (context != null && context.mounted) {
          ResponsiveSnackBar.showError(
            context: context,
            message: 'Gallery permission is required to select media',
          );
        }
        return null;
      }
    }

    try {
      XFile? selectedFile;

      if (mediaType.toLowerCase() == 'image') {
        selectedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      } else if (mediaType.toLowerCase() == 'video') {
        selectedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: maxVideoDuration,
        );
      } else {
        throw ArgumentError('Invalid media type. Use "image" or "video".');
      }

      return selectedFile;
    } catch (e) {
      if (context != null && context.mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error selecting $mediaType: $e',
        );
      }
      debugPrint('Error picking $mediaType: $e');
      return null;
    }
  }

  /// Show a modal bottom sheet to choose between camera and gallery
  Future<XFile?> showImageSourceOptions(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return null;

    XFile? imageFile;
    switch (source) {
      case ImageSource.camera:
        imageFile = await takePhotoWithCamera(context: context);
        break;
      case ImageSource.gallery:
        imageFile = await pickImageFromGallery(context: context);
        break;
    }

    return imageFile;
  }

  /// Show unified media picker with options for images and videos
  Future<XFile?> showUnifiedMediaPicker(BuildContext context) async {
    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Media Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Photos'),
                subtitle: const Text('Select images from gallery'),
                onTap: () => Navigator.pop(context, {'type': 'image'}),
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: const Text('Videos'),
                subtitle: const Text('Select videos from gallery'),
                onTap: () => Navigator.pop(context, {'type': 'video'}),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result == null || result['type'] == null) return null;

    return await pickMediaFromGallery(
      mediaType: result['type'],
      context: context,
    );
  }
}
