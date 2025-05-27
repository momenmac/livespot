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

class VideoCameraPage extends StatefulWidget {
  const VideoCameraPage({super.key});

  @override
  State<VideoCameraPage> createState() => _VideoCameraPageState();
}

class _VideoCameraPageState extends State<VideoCameraPage>
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

  // Video recording states
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _videoPath;

  // Animation controllers
  late AnimationController _recordButtonAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _lockAnimationController;
  late Animation<double> _recordButtonAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _lockSlideAnimation;

  // Gesture detection
  double _initialPanPosition = 0;
  double _currentPanPosition = 0;
  static const double _lockThreshold = 100.0; // pixels to drag up to lock

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

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _lockAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _lockSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lockAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _recordButtonAnimationController.dispose();
    _pulseAnimationController.dispose();
    _lockAnimationController.dispose();

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
      enableAudio: true, // Enable audio for video recording
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

  Future<void> _startRecording() async {
    if (_controller == null || !_isCameraInitialized || _isRecording) return;

    try {
      await _controller!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start the recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isRecording) {
          setState(() {
            _recordingDuration++;
          });
        } else {
          timer.cancel();
        }
      });

      // Start pulse animation for recording indicator
      _pulseAnimationController.repeat(reverse: true);

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
        _isRecordingLocked = false;
        _videoPath = videoFile.path;
      });

      _recordingTimer?.cancel();
      _pulseAnimationController.stop();
      _pulseAnimationController.reset();
      _lockAnimationController.reset();

      // Navigate to video preview
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
    } catch (e) {
      _showErrorMessage('Error stopping recording: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_isCameraInitialized) {
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

  void _onRecordButtonPanStart(DragStartDetails details) {
    _initialPanPosition = details.globalPosition.dy;
    _currentPanPosition = _initialPanPosition;
    _recordButtonAnimationController.forward();
    _startRecording();
  }

  void _onRecordButtonPanUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;

    _currentPanPosition = details.globalPosition.dy;
    double dragDistance = _initialPanPosition - _currentPanPosition;

    if (dragDistance > _lockThreshold && !_isRecordingLocked) {
      setState(() {
        _isRecordingLocked = true;
      });
      _lockAnimationController.forward();
      HapticFeedback.mediumImpact();
    }
  }

  void _onRecordButtonPanEnd(DragEndDetails details) {
    _recordButtonAnimationController.reverse();

    if (_isRecording && !_isRecordingLocked) {
      _stopRecording();
    }
  }

  void _onLockButtonTap() {
    if (_isRecording && _isRecordingLocked) {
      _stopRecording();
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
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'REC ${_formatDuration(_recordingDuration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

          // Top controls
          Positioned(
            top: 50,
            right: 20,
            child: Column(
              children: [
                // Flash toggle
                _buildControlButton(
                  icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  onTap: _toggleFlash,
                  label: _isFlashOn ? 'Flash On' : 'Flash Off',
                ),
                const SizedBox(height: 16),
                // Camera flip
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  onTap: _toggleCameraDirection,
                  label: 'Flip',
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Zoom control
                if (!_isRecording)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
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

                const SizedBox(height: 20),

                // Main controls
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery/Photos button
                      if (!_isRecording)
                        _buildControlButton(
                          icon: Icons.photo_camera,
                          onTap: () {
                            // Switch to photo camera
                            Navigator.of(context)
                                .pushReplacementNamed('/camera');
                          },
                          label: 'Photo',
                        )
                      else
                        const SizedBox(width: 60),

                      // Main capture button with lock indicator
                      Column(
                        children: [
                          // Lock indicator
                          if (_isRecording)
                            AnimatedBuilder(
                              animation: _lockSlideAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                      0, -50 * _lockSlideAnimation.value),
                                  child: Opacity(
                                    opacity: _isRecordingLocked ? 1.0 : 0.5,
                                    child: GestureDetector(
                                      onTap: _onLockButtonTap,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _isRecordingLocked
                                              ? Colors.red
                                              : Colors.white.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isRecordingLocked
                                              ? Icons.lock
                                              : Icons.lock_open,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 8),

                          // Main record/capture button
                          GestureDetector(
                            onTap: _isRecording ? null : _takePicture,
                            onPanStart: _onRecordButtonPanStart,
                            onPanUpdate: _onRecordButtonPanUpdate,
                            onPanEnd: _onRecordButtonPanEnd,
                            child: AnimatedBuilder(
                              animation: _recordButtonAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _recordButtonAnimation.value,
                                  child: Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isRecording
                                            ? Colors.red
                                            : Colors.white,
                                        width: 4,
                                      ),
                                      color: Colors.transparent,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: _isRecording
                                              ? BoxShape.rectangle
                                              : BoxShape.circle,
                                          color: _isRecording
                                              ? Colors.red
                                              : Colors.white,
                                          borderRadius: _isRecording
                                              ? BorderRadius.circular(8)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Instructions
                          if (!_isRecording)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Tap for photo\nHold for video',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Mode switch or timer
                      if (!_isRecording)
                        _buildControlButton(
                          icon: Icons.videocam,
                          onTap: () {},
                          label: 'Video',
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Recording lock instruction
          if (_isRecording && !_isRecordingLocked)
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '↑ Slide up to lock recording',
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
                Icons.videocam,
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
                  backgroundColor: Colors.white.withOpacity(0.2),
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
