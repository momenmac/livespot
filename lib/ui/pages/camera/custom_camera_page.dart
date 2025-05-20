import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/services/location/location_service.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/camera/photo_preview_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class CustomCameraPage extends StatefulWidget {
  const CustomCameraPage({super.key});

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage>
    with WidgetsBindingObserver {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    // First remove the widget binding observer to prevent any callbacks during disposal
    WidgetsBinding.instance.removeObserver(this);

    if (_controller != null) {
      // Stop the preview and release resources before disposing
      _controller!.pausePreview().then((_) {
        _controller!.dispose().then((_) {
          // Clear the controller reference after disposal
          if (mounted) {
            setState(() {
              _controller = null;
              _isCameraInitialized = false;
            });
          }
        });
      });
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;

    // App state changed before camera was initialized
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(controller.description);
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    // Check camera permission
    final cameraStatus = await Permission.camera.request();
    setState(() => _isCameraPermissionGranted = cameraStatus.isGranted);

    if (cameraStatus.isGranted) {
      // Initialize available cameras
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
    } else if (cameraStatus.isPermanentlyDenied) {
      await _openAppSettings();
    } else {
      _showErrorMessage('Camera permission is required to use this feature');
    }

    // Check location permission
    final locationStatus = await Permission.location.request();
    setState(() => _isLocationPermissionGranted = locationStatus.isGranted);

    if (locationStatus.isGranted) {
      await _getCurrentLocation();
    } else if (locationStatus.isPermanentlyDenied) {
      // Inform user that location is helpful but not required
      ResponsiveSnackBar.showSuccess(
        context: context,
        message:
            'You can still use the camera without location. Posts won\'t include location information.',
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      // Get zoom constraints
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
    if (!_isLocationPermissionGranted) {
      return;
    }

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();

      setState(() => _currentPosition = position);

      // Get address from coordinates
      await _getAddressFromLatLng(position);
    } catch (e) {
      _showErrorMessage('Error getting location: $e');
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentAddress = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.postalCode,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Future<void> _toggleCameraDirection() async {
    if (_cameras.length < 2) {
      _showErrorMessage('Device has only one camera');
      return;
    }

    setState(() => _isLoading = true);

    int cameraIndex = _isRearCamera ? 1 : 0;
    await _initCamera(_cameras[cameraIndex]);

    setState(() {
      _isRearCamera = !_isRearCamera;
      _isLoading = false;
    });
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

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

    // Ensure zoom is within valid range
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

  Future<void> _takePicture() async {
    if (_controller == null || !_isCameraInitialized) {
      _showErrorMessage('Camera not ready');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Check location permission and update if needed
      if (_isLocationPermissionGranted && _currentPosition == null) {
        await _getCurrentLocation();
      }

      // Capture the image
      final XFile photo = await _controller!.takePicture();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navigate to preview screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoPreviewPage(
            imagePath: photo.path,
            position: _currentPosition,
            address: _currentAddress,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error taking photo: $e');
    }
  }

  Future<void> _openAppSettings() async {
    if (await openAppSettings()) {
      _showErrorMessage('Please enable camera permission in app settings');
    } else {
      _showErrorMessage(
          'Could not open app settings. Please manually enable camera permission in your device settings');
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

          // Location indicator
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: _isLocationPermissionGranted
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
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
                          color: Colors.red.withOpacity(0.6),
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

          // Bottom controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash toggle button
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onTap: _toggleFlash,
                    label: _isFlashOn ? 'Flash On' : 'Flash Off',
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.transparent,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: ThemeConstants.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Camera flip button
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    onTap: _toggleCameraDirection,
                    label: 'Flip',
                  ),
                ],
              ),
            ),
          ),

          // Zoom control
          Positioned(
            bottom: 150,
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
                    onChanged: (value) {
                      _setZoom(value);
                    },
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
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
              color: Colors.black.withOpacity(0.4),
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
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please grant camera permission to capture photos. This app uses your camera only when you choose to take photos.',
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
                child: const Text('Grant Permission',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
