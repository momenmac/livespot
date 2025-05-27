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
