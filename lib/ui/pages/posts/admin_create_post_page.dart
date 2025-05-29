import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/permissions/permission_service.dart';
import 'package:flutter_application_2/ui/pages/camera/media_preview_page.dart';
import 'package:flutter_application_2/ui/pages/camera/unified_camera_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminCreatePostPage extends StatefulWidget {
  const AdminCreatePostPage({super.key});

  @override
  State<AdminCreatePostPage> createState() => _AdminCreatePostPageState();
}

class _AdminCreatePostPageState extends State<AdminCreatePostPage> {
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    print('DEBUG: AdminCreatePostPage - initState called');
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    print('DEBUG: _getCurrentLocation - Starting location fetch');
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print(
          'DEBUG: _getCurrentLocation - Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('DEBUG: _getCurrentLocation - Initial permission: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print(
            'DEBUG: _getCurrentLocation - Permission after request: $permission');
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
      print('DEBUG: _getCurrentLocation - Getting current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print(
          'DEBUG: _getCurrentLocation - Position received: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');

      // Get address from coordinates with fallback
      await _getAddressFromLatLng(_currentPosition!);
    } catch (e) {
      print('DEBUG: _getCurrentLocation - Error: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Location Error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        print(
            'DEBUG: _getCurrentLocation - Finishing, setting loading to false');
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  /// Show attachment options similar to chat interface
  void _showAttachmentOptions() {
    print('DEBUG: _showAttachmentOptions - Showing bottom sheet');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Choose Media Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),

            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                ),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a new photo or video'),
              onTap: () {
                Navigator.pop(context);
                _openCamera();
              },
            ),

            // Gallery Photos option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.green,
                ),
              ),
              title: const Text('Gallery Photos'),
              subtitle: const Text('Choose from your photo library'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),

            // Gallery Videos option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.video_library,
                  color: Colors.purple,
                ),
              ),
              title: const Text('Gallery Videos'),
              subtitle: const Text('Choose from your video library'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromGallery();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Open camera for taking photos or videos
  Future<void> _openCamera() async {
    try {
      // Check camera permissions
      final PermissionService permissionService = PermissionService();
      bool hasCameraPermission =
          await permissionService.requestCameraPermission(context);

      if (!hasCameraPermission) {
        ResponsiveSnackBar.showError(
          context: context,
          message:
              'Camera access is required to take photos or videos. Please enable camera access in your device settings.',
        );
        return;
      }

      // Navigate to unified camera page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnifiedCameraPage(),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        _handleCameraResult(result);
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Failed to open camera: ${e.toString()}',
      );
    }
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    print('DEBUG: _pickImageFromGallery - Starting image selection');
    try {
      // Use PermissionService to pick image from gallery
      final PermissionService permissionService = PermissionService();
      print(
          'DEBUG: _pickImageFromGallery - Calling PermissionService.pickImage');
      final XFile? selectedFile = await permissionService.pickImage(
        context: context,
        source: ImageSource.gallery,
      );

      print(
          'DEBUG: _pickImageFromGallery - Selected file: ${selectedFile?.path}');
      if (selectedFile != null) {
        _handleMediaSelection(selectedFile, 'photo');
      }
    } catch (e) {
      print('DEBUG: _pickImageFromGallery - Error: $e');
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Failed to pick image: ${e.toString()}',
      );
    }
  }

  /// Pick video from gallery
  Future<void> _pickVideoFromGallery() async {
    print('DEBUG: _pickVideoFromGallery - Starting video selection');
    try {
      // Use PermissionService to pick video from gallery
      final PermissionService permissionService = PermissionService();
      print(
          'DEBUG: _pickVideoFromGallery - Calling PermissionService.pickVideo');
      final XFile? selectedFile = await permissionService.pickVideo(
        context: context,
        source: ImageSource.gallery,
      );

      print(
          'DEBUG: _pickVideoFromGallery - Selected file: ${selectedFile?.path}');
      if (selectedFile != null) {
        _handleMediaSelection(selectedFile, 'video');
      }
    } catch (e) {
      print('DEBUG: _pickVideoFromGallery - Error: $e');
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Failed to pick video: ${e.toString()}',
      );
    }
  }

  /// Handle camera result
  void _handleCameraResult(Map<String, dynamic> result) {
    final String? mediaPath = result['path'];
    final String? mediaType = result['type'];

    if (mediaPath != null && mediaType != null) {
      // Ensure we have location before proceeding
      if (_currentPosition == null) {
        ResponsiveSnackBar.showError(
          context: context,
          message:
              'Location is required to create posts. Please enable location services.',
        );
        return;
      }

      // Navigate to MediaPreviewPage with the captured media
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPreviewPage(
            mediaPath: mediaPath,
            mediaType: mediaType,
            position: _currentPosition,
            address: _currentAddress,
          ),
        ),
      );
    }
  }

  /// Handle media selection from gallery
  void _handleMediaSelection(XFile selectedFile, String mediaType) {
    // Ensure we have location before proceeding
    if (_currentPosition == null) {
      ResponsiveSnackBar.showError(
        context: context,
        message:
            'Location is required to create posts. Please enable location services.',
      );
      return;
    }

    // Navigate to MediaPreviewPage with the selected media
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(
          mediaPath: selectedFile.path,
          mediaType: mediaType,
          position: _currentPosition,
          address: _currentAddress,
        ),
      ),
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

  Future<String?> _fallbackGeocoding(Position position) async {
    // First try: LocationIQ
    try {
      print('DEBUG: Trying fallback geocoding with LocationIQ');

      final url = Uri.parse('https://us1.locationiq.com/v1/reverse.php?'
          'key=pk.0123456789abcdef&lat=${position.latitude}&lon=${position.longitude}&format=json');

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Limit to first 2 parts for consistency
          final parts = displayName.split(', ');
          final limitedAddress = parts.take(2).join(', ');
          print('DEBUG: LocationIQ geocoding successful: $limitedAddress');
          return limitedAddress;
        }
      }
    } catch (e) {
      print('DEBUG: LocationIQ geocoding error: $e');
    }

    // Second try: BigDataCloud
    try {
      print('DEBUG: Trying BigDataCloud as second fallback');

      final url = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?'
          'latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en');

      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final city = data['city'] as String?;
        final countryName = data['countryName'] as String?;

        if (city != null && countryName != null) {
          // Clean up country name - sometimes it has extra text like "State of"
          String cleanCountry = countryName;
          if (cleanCountry.contains(',')) {
            cleanCountry = cleanCountry.split(',').first.trim();
          }

          // Limit to just city and cleaned country (2 parts)
          final address = '$city, $cleanCountry';
          print('DEBUG: BigDataCloud geocoding successful: $address');
          return address;
        }
      }
    } catch (e) {
      print('DEBUG: BigDataCloud geocoding error: $e');
    }

    // Third try: OpenStreetMap Nominatim (free, no API key needed)
    try {
      print('DEBUG: Trying OpenStreetMap Nominatim as third fallback');

      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?'
          'format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=14&addressdetails=1');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Limit to first 2 parts to keep it concise
          final parts = displayName.split(', ');
          final shortened = parts.take(2).join(', ');
          print(
              'DEBUG: OpenStreetMap geocoding successful (limited to 2 parts): $shortened');
          return shortened;
        }
      }
    } catch (e) {
      print('DEBUG: OpenStreetMap geocoding error: $e');
    }

    return null;
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      print('DEBUG: _getAddressFromLatLng - Trying primary geocoding service');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;

        // Build address components similar to camera page but limit to first 2 parts
        final addressComponents = <String>[];

        // Add street/thoroughfare
        if (place.street != null && place.street!.isNotEmpty) {
          addressComponents.add(place.street!);
        } else if (place.thoroughfare != null &&
            place.thoroughfare!.isNotEmpty) {
          addressComponents.add(place.thoroughfare!);
        }

        // Add locality
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressComponents.add(place.locality!);
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressComponents.add(place.subLocality!);
        }

        // Take only first 2 components to keep it short
        final limitedComponents = addressComponents.take(2).toList();
        _currentAddress = limitedComponents.isNotEmpty
            ? limitedComponents.join(', ')
            : 'Unknown location';

        print(
            'DEBUG: _getAddressFromLatLng - Primary geocoding successful: $_currentAddress');

        if (mounted) {
          setState(() {});
        }
        return;
      }
    } catch (e) {
      print('DEBUG: _getAddressFromLatLng - Primary geocoding failed: $e');
    }

    // Try fallback geocoding services
    print(
        'DEBUG: _getAddressFromLatLng - Trying fallback geocoding services...');
    final fallbackAddress = await _fallbackGeocoding(position);

    if (fallbackAddress != null && fallbackAddress.isNotEmpty) {
      print(
          'DEBUG: _getAddressFromLatLng - Using fallback address: $fallbackAddress');
      _currentAddress = fallbackAddress;
      if (mounted) {
        setState(() {});
      }
    } else {
      print(
          'DEBUG: _getAddressFromLatLng - All geocoding methods failed, using coordinates');
      _currentAddress =
          'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isLoadingLocation
                        ? Colors.orange.withOpacity(0.3)
                        : (_currentPosition != null
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoadingLocation
                              ? Icons.location_searching
                              : (_currentPosition != null
                                  ? Icons.location_on
                                  : Icons.location_off),
                          color: _isLoadingLocation
                              ? Colors.orange
                              : (_currentPosition != null
                                  ? Colors.green
                                  : Colors.red),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isLoadingLocation
                                ? 'Getting your location...'
                                : (_currentPosition != null
                                    ? 'Location detected'
                                    : 'Location required'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _isLoadingLocation
                                  ? Colors.orange
                                  : (_currentPosition != null
                                      ? Colors.green
                                      : Colors.red),
                            ),
                          ),
                        ),
                        if (_isLoadingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          ),
                      ],
                    ),
                    if (_currentAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _currentAddress!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (!_isLoadingLocation && _currentPosition == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Location is required to create posts. Please enable location services and try again.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Media Selection Section
              Text(
                'Add Media',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Choose how you want to add media to your post',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 24),

              // Media Options
              Expanded(
                child: Column(
                  children: [
                    _buildMediaOption(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      subtitle: 'Take a new photo or video',
                      onTap: _currentPosition != null ? _openCamera : null,
                      color: Colors.blue,
                    ),
                    _buildMediaOption(
                      icon: Icons.photo_library,
                      title: 'Gallery Photos',
                      subtitle: 'Choose from your photo library',
                      onTap: _currentPosition != null
                          ? _pickImageFromGallery
                          : null,
                      color: Colors.green,
                    ),
                    _buildMediaOption(
                      icon: Icons.video_library,
                      title: 'Gallery Videos',
                      subtitle: 'Choose from your video library',
                      onTap: _currentPosition != null
                          ? _pickVideoFromGallery
                          : null,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),

              // Alternative: Quick Attachment Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed:
                      _currentPosition != null ? _showAttachmentOptions : null,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Quick Attach'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPosition != null
                        ? ThemeConstants.primaryColor
                        : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ...existing code...
}
