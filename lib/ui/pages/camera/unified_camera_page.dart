import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/location/location_service.dart';

import 'package:flutter_application_2/ui/pages/camera/media_preview_page.dart';

import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum CameraMode { photo, video }

class UnifiedCameraPage extends StatefulWidget {
  final bool isAddingMedia;

  const UnifiedCameraPage({
    super.key,
    this.isAddingMedia = false,
  });

  @override
  State<UnifiedCameraPage> createState() => _UnifiedCameraPageState();
}

class _UnifiedCameraPageState extends State<UnifiedCameraPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isLocationPermissionGranted = false;
  bool _isRearCamera = true;
  bool _isFlashOn = false;
  bool _isLoading = true;
  Position? _currentPosition;
  String? _currentAddress;
  double _currentZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _minAvailableZoom = 1.0;

  // Camera mode
  CameraMode _currentMode = CameraMode.photo;

  // Video recording states
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Animation controllers
  late AnimationController _recordButtonAnimationController;
  late Animation<double> _recordButtonAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _checkPermissions();
  }

  void _initializeAnimations() {
    _recordButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _recordButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _recordButtonAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _recordButtonAnimationController.dispose();

    if (_controller != null) {
      if (_isRecording) {
        _controller!.stopVideoRecording();
      }
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      if (_isRecording) {
        _stopRecording();
      }
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(controller.description);
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    // Check camera permission
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    setState(() => _isCameraPermissionGranted =
        cameraStatus.isGranted && microphoneStatus.isGranted);

    if (_isCameraPermissionGranted) {
      try {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _initCamera(_cameras.first);
        } else {
          _showErrorMessage('No cameras available on this device');
        }
      } catch (e) {
        _showErrorMessage('Error initializing camera: $e');
      }
    } else if (cameraStatus.isPermanentlyDenied ||
        microphoneStatus.isPermanentlyDenied) {
      await _openAppSettings();
    } else {
      _showErrorMessage('Camera and microphone permissions are required');
    }

    // Check location permission
    final locationStatus = await Permission.location.request();
    setState(() => _isLocationPermissionGranted = locationStatus.isGranted);

    if (locationStatus.isGranted) {
      await _getCurrentLocation();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true, // Always enable audio for video capability
    );

    try {
      await controller.initialize();

      _maxAvailableZoom = await controller.getMaxZoomLevel();
      _minAvailableZoom = await controller.getMinZoomLevel();

      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
      });
    } catch (e) {
      _showErrorMessage('Error initializing camera: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLocationPermissionGranted) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();
      setState(() => _currentPosition = position);
      await _getAddressFromLatLng(position);
    } catch (e) {
      _showErrorMessage('Error getting location: $e');
    }
  }

  Future<String?> _fallbackGeocoding(Position position) async {
    // First try: LocationIQ
    try {
      debugPrint('🌍 Trying fallback geocoding with LocationIQ');

      final url = Uri.parse('https://us1.locationiq.com/v1/reverse.php?'
          'key=pk.7532956e7e0b25b745e6e6d2e6f58c37&'
          'lat=${position.latitude}&'
          'lon=${position.longitude}&'
          'format=json&'
          'addressdetails=1');

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        debugPrint('🌍 LocationIQ response received');

        final addressData = data['address'] as Map<String, dynamic>?;
        if (addressData != null) {
          final components = <String>[];

          if (addressData['house_number'] != null &&
              addressData['road'] != null) {
            components
                .add('${addressData['house_number']} ${addressData['road']}');
          } else if (addressData['road'] != null) {
            components.add(addressData['road']);
          }

          String? locality = addressData['city'] ??
              addressData['town'] ??
              addressData['village'] ??
              addressData['suburb'];
          if (locality != null) {
            components.add(locality);
          }

          // Add country for international clarity
          if (addressData['country'] != null) {
            components.add(addressData['country']);
          }

          if (components.isNotEmpty) {
            final cleanAddress = components.join(', ');
            // Ensure proper UTF-8 encoding
            try {
              final decodedAddress = Uri.decodeComponent(cleanAddress);
              debugPrint('🎯 LocationIQ clean address: $decodedAddress');
              return decodedAddress;
            } catch (e) {
              // If decoding fails, return as-is
              debugPrint(
                  '🎯 LocationIQ clean address (no decode needed): $cleanAddress');
              return cleanAddress;
            }
          }
        }

        // Fallback to display_name from LocationIQ
        if (data['display_name'] != null) {
          String fullAddress = data['display_name'];
          try {
            final decodedAddress = Uri.decodeComponent(fullAddress);
            debugPrint('🎯 LocationIQ display name: $decodedAddress');
            return decodedAddress;
          } catch (e) {
            debugPrint(
                '🎯 LocationIQ display name (no decode needed): $fullAddress');
            return fullAddress;
          }
        }
      }
    } catch (e) {
      debugPrint('💥 LocationIQ geocoding error: $e');
    }

    // Second try: BigDataCloud
    try {
      debugPrint('🌍 Trying BigDataCloud as second fallback');

      final url =
          Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?'
              'latitude=${position.latitude}&'
              'longitude=${position.longitude}&'
              'localityLanguage=en');

      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        debugPrint('🌍 BigDataCloud response received');

        final components = <String>[];

        if (data['locality'] != null &&
            data['locality'].toString().isNotEmpty) {
          String locality = data['locality'].toString();
          // Only clean up the "State of" suffix but keep full locality name
          locality = locality.replaceAll(RegExp(r',\s*State of$'), '');
          components.add(locality.trim());
        }

        if (data['city'] != null && data['city'].toString().isNotEmpty) {
          String city = data['city'].toString();
          if (components.isEmpty || !components.first.contains(city)) {
            city = city.replaceAll(RegExp(r',\s*State of$'), '');
            components.add(city.trim());
          }
        }

        if (data['countryName'] != null) {
          String country = data['countryName'].toString();
          // Clean up country name
          country = country.replaceAll(RegExp(r',\s*State of$'), '');
          country = country.replaceAll('Palestine, State of', 'Palestine');
          components.add(country.trim());
        }

        if (components.isNotEmpty) {
          final address = components.join(', ');
          // Ensure proper UTF-8 encoding
          try {
            final decodedAddress = Uri.decodeComponent(address);
            debugPrint('🎯 BigDataCloud cleaned address: $decodedAddress');
            return decodedAddress;
          } catch (e) {
            // If decoding fails, return as-is
            debugPrint(
                '🎯 BigDataCloud cleaned address (no decode needed): $address');
            return address;
          }
        }
      }
    } catch (e) {
      debugPrint('💥 BigDataCloud geocoding error: $e');
    }

    // Third try: OpenStreetMap Nominatim (free, no API key needed) - WITH SHORTENING
    try {
      debugPrint('🌍 Trying OpenStreetMap Nominatim as third fallback');

      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?'
          'lat=${position.latitude}&'
          'lon=${position.longitude}&'
          'format=json&'
          'addressdetails=1&'
          'zoom=18&'
          'accept-language=ar,en');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterApp/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        debugPrint('🌍 OpenStreetMap response received');

        // Try to build address from components first
        final addressData = data['address'] as Map<String, dynamic>?;
        if (addressData != null) {
          final components = <String>[];

          // Add street info
          if (addressData['house_number'] != null &&
              addressData['road'] != null) {
            components
                .add('${addressData['house_number']} ${addressData['road']}');
          } else if (addressData['road'] != null) {
            components.add(addressData['road']);
          }

          // Add locality
          String? locality = addressData['city'] ??
              addressData['town'] ??
              addressData['village'] ??
              addressData['suburb'] ??
              addressData['neighbourhood'];
          if (locality != null) {
            components.add(locality);
          }

          if (components.isNotEmpty) {
            final shortAddress = components
                .take(2)
                .join(', '); // Only for OSM: limit to 2 components
            // Ensure proper UTF-8 decoding
            try {
              final decodedAddress = Uri.decodeComponent(shortAddress);
              debugPrint(
                  '🎯 OpenStreetMap component address (shortened): $decodedAddress');
              return decodedAddress;
            } catch (e) {
              // If decoding fails, return as-is
              debugPrint(
                  '🎯 OpenStreetMap component address (shortened, no decode needed): $shortAddress');
              return shortAddress;
            }
          }
        }

        // Fallback to display_name but shorten it significantly (OSM ONLY)
        if (data['display_name'] != null) {
          String fullAddress = data['display_name'];
          // Take only first 2 meaningful parts and clean them (OSM ONLY)
          List<String> parts = fullAddress
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .take(2) // OSM ONLY: limit to 2 parts
              .toList();

          if (parts.isNotEmpty) {
            String shortAddress = parts.join(', ');
            // Clean up common long endings (OSM ONLY)
            shortAddress = shortAddress.replaceAll(
                RegExp(r',\s*\d{5}.*$'), ''); // Remove postal codes and after
            shortAddress = shortAddress.replaceAll(RegExp(r',\s*Palestine.*$'),
                ', Palestine'); // Shorten Palestine references

            // Ensure proper UTF-8 decoding
            try {
              final decodedAddress = Uri.decodeComponent(shortAddress);
              debugPrint('🎯 OpenStreetMap shortened address: $decodedAddress');
              return decodedAddress;
            } catch (e) {
              // If decoding fails, return as-is
              debugPrint(
                  '🎯 OpenStreetMap shortened address (no decode needed): $shortAddress');
              return shortAddress;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('💥 OpenStreetMap geocoding error: $e');
    }

    return null;
  }

  Future<void> _diagnoseGoogleGeocodingIssue() async {
    try {
      debugPrint('🔍 Diagnosing Google geocoding service...');

      // Check if Google Play Services is available
      try {
        final testPosition = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        await placemarkFromCoordinates(
            testPosition.latitude, testPosition.longitude);
        debugPrint('✅ Google geocoding service is working');
      } catch (e) {
        debugPrint('❌ Google geocoding service issue: $e');
        if (e.toString().contains('NETWORK_ERROR')) {
          debugPrint('💡 Issue: Network connectivity problem');
        } else if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
          debugPrint(
              '💡 Issue: Google Play Services not available or outdated');
        } else if (e.toString().contains('QUOTA_EXCEEDED')) {
          debugPrint('💡 Issue: API quota exceeded');
        } else if (e.toString().contains('INVALID_REQUEST')) {
          debugPrint('💡 Issue: Invalid request parameters');
        } else {
          debugPrint('💡 Issue: Unknown geocoding error');
        }
      }
    } catch (e) {
      debugPrint('💥 Error during diagnosis: $e');
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      debugPrint(
          '🔍 Getting address for coordinates: ${position.latitude}, ${position.longitude}');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      debugPrint('📍 Geocoding API returned ${placemarks.length} placemarks');

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Create a clean address from Google's data (NO SHORTENING)
        final addressComponents = <String>[];

        // Add street address
        if (place.street != null && place.street!.isNotEmpty) {
          addressComponents.add(place.street!);
        } else if (place.thoroughfare != null &&
            place.thoroughfare!.isNotEmpty) {
          if (place.subThoroughfare != null &&
              place.subThoroughfare!.isNotEmpty) {
            addressComponents
                .add('${place.subThoroughfare} ${place.thoroughfare}');
          } else {
            addressComponents.add(place.thoroughfare!);
          }
        }

        // Add locality
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressComponents.add(place.locality!);
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressComponents.add(place.subLocality!);
        }

        // Add country for clarity
        if (place.country != null && place.country!.isNotEmpty) {
          addressComponents.add(place.country!);
        }

        final finalAddress = addressComponents.isNotEmpty
            ? addressComponents.join(', ')
            : 'Unknown location';

        debugPrint('🎯 Google geocoding address: "$finalAddress"');

        setState(() {
          _currentAddress = finalAddress;
        });
      } else {
        debugPrint('❌ No placemarks found, trying fallback...');
        await _tryFallbackGeocoding(position);
      }
    } catch (e) {
      debugPrint('💥 Google geocoding error: $e');

      // Run diagnosis
      await _diagnoseGoogleGeocodingIssue();

      // Try fallback
      await _tryFallbackGeocoding(position);
    }
  }

  Future<void> _tryFallbackGeocoding(Position position) async {
    debugPrint('🔄 Trying fallback geocoding services...');
    final fallbackAddress = await _fallbackGeocoding(position);

    if (fallbackAddress != null && fallbackAddress.isNotEmpty) {
      setState(() {
        _currentAddress = fallbackAddress;
      });
      debugPrint('🎯 Using fallback address: $fallbackAddress');
    } else {
      // Use coordinates as last resort
      setState(() {
        _currentAddress =
            '📍 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      debugPrint(
          '🎯 All geocoding failed, using coordinates: $_currentAddress');
    }
  }

  void _switchMode(CameraMode mode) {
    if (_isRecording) return; // Don't allow mode switch while recording

    setState(() {
      _currentMode = mode;
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _startRecording() async {
    if (_controller == null ||
        !_isCameraInitialized ||
        _isRecording ||
        _currentMode != CameraMode.video) {
      return;
    }

    try {
      await _controller!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start the recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isRecording && mounted) {
          setState(() {
            _recordingDuration++;
          });
        } else {
          timer.cancel();
        }
      });

      // Haptic feedback
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showErrorMessage('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();

      setState(() {
        _isRecording = false;
      });

      _recordingTimer?.cancel();
      _recordButtonAnimationController.reset();

      if (widget.isAddingMedia) {
        // Return the video path to the previous page
        Navigator.pop(context, {
          'type': 'video',
          'path': videoFile.path,
          'position': _currentPosition,
          'address': _currentAddress,
        });
      } else {
        // Navigate to video preview page normally
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaPreviewPage(
                mediaPath: videoFile.path,
                mediaType: 'video',
                position: _currentPosition,
                address: _currentAddress,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorMessage('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      _recordingTimer?.cancel();
      _recordButtonAnimationController.reset();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_isCameraInitialized ||
        _currentMode != CameraMode.photo) {
      _showErrorMessage('Camera not ready');
      return;
    }

    try {
      setState(() => _isLoading = true);

      if (_isLocationPermissionGranted && _currentPosition == null) {
        await _getCurrentLocation();
      }

      final XFile photo = await _controller!.takePicture();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (widget.isAddingMedia) {
        // Return the photo path to the previous page
        Navigator.pop(context, {
          'type': 'photo',
          'path': photo.path,
          'position': _currentPosition,
          'address': _currentAddress,
        });
      } else {
        // Navigate to photo preview page normally
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaPreviewPage(
              mediaPath: photo.path,
              mediaType: 'photo',
              position: _currentPosition,
              address: _currentAddress,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error taking photo: $e');
    }
  }

  Future<void> _toggleCameraDirection() async {
    if (_cameras.length < 2) {
      _showErrorMessage('Device has only one camera');
      return;
    }

    if (_isRecording) return; // Don't allow camera flip while recording

    setState(() => _isLoading = true);

    int cameraIndex = _isRearCamera ? 1 : 0;
    await _initCamera(_cameras[cameraIndex]);

    setState(() {
      _isRearCamera = !_isRearCamera;
      _isLoading = false;
    });
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || _isRecording) return;

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(newFlashMode);

      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      _showErrorMessage('Error toggling flash: $e');
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null) return;

    zoom = zoom.clamp(_minAvailableZoom, _maxAvailableZoom);

    try {
      await _controller!.setZoomLevel(zoom);
      setState(() {
        _currentZoom = zoom;
      });
    } catch (e) {
      debugPrint('Error setting zoom: $e');
    }
  }

  // Gesture handlers for video recording - SIMPLIFIED TAP TO RECORD
  void _onRecordButtonTap() {
    if (_currentMode != CameraMode.video) return;

    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openAppSettings() async {
    if (await openAppSettings()) {
      _showErrorMessage(
          'Please enable camera and microphone permissions in app settings');
    } else {
      _showErrorMessage(
          'Could not open app settings. Please manually enable permissions in your device settings');
    }
  }

  void _showErrorMessage(String message) {
    ResponsiveSnackBar.showError(
      context: context,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: ThemeConstants.primaryColor),
        ),
      );
    }

    if (!_isCameraPermissionGranted) {
      return _buildPermissionRequest();
    }

    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'Camera initialization failed',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'REC ${_formatDuration(_recordingDuration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_isRecording) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Location indicator
          Positioned(
            top: _isRecording ? 110 : 50,
            left: 0,
            right: 0,
            child: Center(
              child: _isLocationPermissionGranted
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _currentAddress ?? 'Getting location...',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _checkPermissions(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Location disabled - tap to enable',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // Top controls
          Positioned(
            top: 50,
            right: 20,
            child: Column(
              children: [
                // Flash toggle
                if (!_isRecording)
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onTap: _toggleFlash,
                    label: _isFlashOn ? 'Flash On' : 'Flash Off',
                  ),
                if (!_isRecording) const SizedBox(height: 16),
                // Camera flip
                if (!_isRecording)
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    onTap: _toggleCameraDirection,
                    label: 'Flip',
                  ),
              ],
            ),
          ),

          // Mode switch (below location indicator)
          if (!_isRecording)
            Positioned(
              top: _isLocationPermissionGranted ? 100 : 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton(
                        'Photo',
                        Icons.camera_alt,
                        CameraMode.photo,
                      ),
                      _buildModeButton(
                        'Video',
                        Icons.videocam,
                        CameraMode.video,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Zoom control
          if (!_isRecording)
            Positioned(
              bottom: 170,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.white),
                  Expanded(
                    child: Slider(
                      value: _currentZoom,
                      min: _minAvailableZoom,
                      max: _maxAvailableZoom,
                      activeColor: ThemeConstants.primaryColor,
                      inactiveColor: Colors.white30,
                      onChanged: _setZoom,
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.white),
                ],
              ),
            ),

          // Main capture button and controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Main controls row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Left spacer or timer
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 60),

                      // Main capture button
                      GestureDetector(
                        onTap: _currentMode == CameraMode.photo
                            ? _takePicture
                            : _onRecordButtonTap,
                        child: AnimatedBuilder(
                          animation: _recordButtonAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _recordButtonAnimation.value,
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: _isRecording
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  borderRadius: _isRecording
                                      ? BorderRadius.circular(16)
                                      : null,
                                  border: _isRecording
                                      ? null
                                      : Border.all(
                                          color:
                                              _currentMode == CameraMode.video
                                                  ? Colors.red
                                                      .withValues(alpha: 0.8)
                                                  : Colors.white,
                                          width: 4,
                                        ),
                                  color: _isRecording
                                      ? Colors.red
                                      : _currentMode == CameraMode.video
                                          ? Colors.red.withValues(alpha: 0.8)
                                          : Colors.white,
                                ),
                                child: _currentMode == CameraMode.photo &&
                                        !_isRecording
                                    ? const Icon(Icons.camera_alt,
                                        color: Colors.black, size: 30)
                                    : _isRecording
                                        ? const Icon(Icons.stop,
                                            color: Colors.white, size: 30)
                                        : null,
                              ),
                            );
                          },
                        ),
                      ),

                      // Right instructions or spacer
                      if (!_isRecording)
                        SizedBox(
                          width: 60,
                          child: Column(
                            children: [
                              Text(
                                'Tap',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentMode == CameraMode.photo
                                    ? 'to capture'
                                    : 'to record',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(width: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Recording status indicator (when recording)
          if (_isRecording)
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap to stop recording',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, CameraMode mode) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ThemeConstants.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt,
                size: 80,
                color: ThemeConstants.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera & Microphone Access Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please grant camera and microphone permissions to capture photos and record videos.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _checkPermissions(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConstants.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Grant Permissions',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
