import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/utils/image_picker_service.dart';
import 'package:flutter_application_2/ui/pages/camera/media_preview_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminCreatePostPage extends StatefulWidget {
  const AdminCreatePostPage({super.key});

  @override
  State<AdminCreatePostPage> createState() => _AdminCreatePostPageState();
}

class _AdminCreatePostPageState extends State<AdminCreatePostPage> {
  final ImagePickerService _imagePickerService = ImagePickerService();
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
              'Location permissions are denied. Please allow location access in your device settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied. Please enable location access in your device settings.');
      }

      // Get current position with timeout
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        _currentAddress = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Location Error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      // Check and request proper gallery permissions first
      bool hasPermission = await _requestGalleryPermission();
      
      if (!hasPermission) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Gallery access is required to select media. Please enable media access in Settings.',
        );
        return;
      }

      // Show options for photo or video
      final String? mediaType = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Media Type'),
            content: const Text('Choose what type of media to select from your gallery'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('photo'),
                child: const Text('Photos'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('video'),
                child: const Text('Videos'),
              ),
            ],
          );
        },
      );

      if (mediaType == null) return;

      XFile? selectedMedia;
      
      if (mediaType == 'photo') {
        selectedMedia = await _imagePickerService.pickImageFromGallery(
          context: context,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
      } else {
        final ImagePicker picker = ImagePicker();
        selectedMedia = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 10),
        );
      }

      if (selectedMedia != null) {
        // Ensure we have location before proceeding
        if (_currentPosition == null) {
          ResponsiveSnackBar.showInfo(
            context: context,
            message: 'Getting location...',
          );
          await _getCurrentLocation();
          
          if (_currentPosition == null) {
            ResponsiveSnackBar.showError(
              context: context,
              message: 'Location is required to create posts. Please enable location services.',
            );
            return;
          }
        }

        // Navigate to MediaPreviewPage with the selected media
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MediaPreviewPage(
              mediaPath: selectedMedia!.path,
              mediaType: mediaType,
              position: _currentPosition,
              address: _currentAddress,
            ),
          ),
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Failed to pick media: ${e.toString()}',
      );
    }
  }

  Future<bool> _requestGalleryPermission() async {
    try {
      if (Platform.isIOS) {
        final status = await Permission.photos.status;
        if (status.isGranted) return true;
        
        if (status.isPermanentlyDenied) {
          await _showPermissionDialog(
            title: 'Photo Access Required',
            message: 'Please enable photo access in Settings to select images from your gallery.',
          );
          return false;
        }
        
        final result = await Permission.photos.request();
        return result.isGranted;
      } else if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use READ_MEDIA_IMAGES
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted) return true;
        
        if (photosStatus.isPermanentlyDenied) {
          await _showPermissionDialog(
            title: 'Media Access Required',
            message: 'Please enable media access in Settings to select images from your gallery.',
          );
          return false;
        }
        
        final photosResult = await Permission.photos.request();
        if (photosResult.isGranted) return true;
        
        // Fallback to storage permission for older Android versions
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;
        
        if (storageStatus.isPermanentlyDenied) {
          await _showPermissionDialog(
            title: 'Storage Access Required',
            message: 'Please enable storage access in Settings to select images from your gallery.',
          );
          return false;
        }
        
        final storageResult = await Permission.storage.request();
        return storageResult.isGranted;
      }
      
      return true; // For other platforms
    } catch (e) {
      print('Error requesting gallery permission: $e');
      return false;
    }
  }

  Future<void> _showPermissionDialog({required String title, required String message}) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    final bool isEnabled = onTap != null;

    return GestureDetector(
      onTap: isEnabled
          ? onTap
          : () {
              ResponsiveSnackBar.showError(
                context: context,
                message: 'Location is required before selecting media',
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isEnabled
              ? Theme.of(context).cardColor
              : Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled ? subtitle : '$subtitle (Location required)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isEnabled ? Colors.grey[400] : Colors.grey[300],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Choose Media Source',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select photos or videos from your gallery to create a post with our enhanced editor.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Location status
            if (_isLoadingLocation)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(child: Text('Getting your location...')),
                  ],
                ),
              )
            else if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _currentAddress ?? 'Location available',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Location required for posts',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Media options
            _buildMediaOption(
              icon: Icons.photo_library,
              title: 'Select Media',
              subtitle: 'Choose photos or videos from your gallery',
              onTap: _currentPosition != null ? _pickMediaFromGallery : null,
              color: ThemeConstants.primaryColor,
            ),

            const Spacer(),

            // Settings help section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'After selecting media, you\'ll access our enhanced post editor with rich formatting options.',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Having permission issues?',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Open Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
