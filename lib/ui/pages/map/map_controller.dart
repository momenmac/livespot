import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_categories.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';

class MapPageController extends ChangeNotifier {
  final MapController mapController = MapController();
  final TextEditingController locationController = TextEditingController();

  // Add a Completer to track map readiness
  final Completer<void> _mapReadyCompleter = Completer<void>();

  // Add flag to track disposed state
  bool _isDisposed = false;

  BuildContext? _context;

  LatLng? currentLocation;
  LatLng? destination;
  List<LatLng> route = [];
  bool showMarkersAndRoute = true;
  List<String> searchSuggestions = [];
  bool showSuggestions = false;
  Timer? debounce;
  bool hasInitializedLocation = false;
  bool showRoute = false;
  StreamSubscription<Position>? positionStreamSubscription;
  DateTime selectedDate = DateTime.now();

  final LatLngBounds mapBounds = LatLngBounds(
    LatLng(-85.0, -180.0),
    LatLng(85.0, 180.0),
  );

  // Properties to hold marker information
  String? _markerEventType;
  String? _markerDescription;

  // Getters for marker information
  String get markerEventType => _markerEventType ?? 'news';
  String? get markerDescription => _markerDescription;

  // Call this from your FlutterMap's onMapReady callback
  void setMapReady() {
    if (!_mapReadyCompleter.isCompleted) {
      _mapReadyCompleter.complete();
      _safeNotifyListeners(); // Add this to trigger a refresh
    }
  }

  // Helper to move the map only when the controller is ready
  Future<void> _moveMapWhenReady(LatLng target, double zoom) async {
    if (_isDisposed) return; // Safety check
    try {
      await _mapReadyCompleter.future.timeout(const Duration(seconds: 5),
          onTimeout: () => debugPrint('Map ready timed out'));
      if (!_isDisposed) {
        try {
          mapController.move(target, zoom);
          _safeNotifyListeners(); // Add this to trigger a refresh
        } catch (e) {
          debugPrint('Error moving map: $e');
        }
      }
    } catch (e) {
      debugPrint('Error waiting for map ready: $e');
    }
  }

  // Set context for error messages
  void setContext(BuildContext context) {
    _context = context;
  }

  @override
  void dispose() {
    _isDisposed = true;
    positionStreamSubscription?.cancel();
    debounce?.cancel();
    try {
      mapController.dispose();
    } catch (e) {
      // Ignore errors during disposal
      print('Ignoring error during map controller disposal: $e');
    }
    locationController.dispose();
    super.dispose();
  }

  // Safe version of notifyListeners that checks for disposed state
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initializeLocation() async {
    if (_isDisposed) return; // Safety check

    try {
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        // Set a default location if no permission
        currentLocation =
            LatLng(31.5017, 34.4668); // Gaza coordinates as default
        _moveMapWhenReady(currentLocation!, 10);
        hasInitializedLocation = true;
        _safeNotifyListeners();
        return;
      }

      try {
        // Get position first for all platforms
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint("Position request timed out, using default");
            return Position(
              latitude: 31.5017,
              longitude: 34.4668,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          },
        );

        currentLocation = LatLng(position.latitude, position.longitude);
        // Use helper to move map when ready
        _moveMapWhenReady(currentLocation!, 10);
        hasInitializedLocation = true;
        _safeNotifyListeners();
      } catch (e) {
        debugPrint("Error getting initial position: $e");
        // Fallback to default location
        currentLocation = LatLng(31.5017, 34.4668);
        _moveMapWhenReady(currentLocation!, 10);
        hasInitializedLocation = true;
        _safeNotifyListeners();
      }

      // Start position stream
      positionStreamSubscription
          ?.cancel(); // Cancel existing subscription if any
      positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          if (_isDisposed) return; // Safety check

          final newLocation = LatLng(position.latitude, position.longitude);
          currentLocation = newLocation;
          _safeNotifyListeners();

          if (!hasInitializedLocation) {
            _moveMapWhenReady(newLocation, 10);
            hasInitializedLocation = true;
          }
        },
        onError: (error) {
          debugPrint('Error getting location stream: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize location services: $e');
      // Set a default location on error
      currentLocation = LatLng(31.5017, 34.4668);
      _moveMapWhenReady(currentLocation!, 10);
      hasInitializedLocation = true;
      _safeNotifyListeners();
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showErrorMessage(TextStrings.locationPermissionsDenied);
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        showErrorMessage(TextStrings.locationPermissionsDeniedPermanently);
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showErrorMessage(TextStrings.locationServicesDisabled);
        return false;
      }

      return true;
    } catch (e) {
      showErrorMessage('${TextStrings.errorCheckingLocationPermissions}$e');
      return false;
    }
  }

  Future<void> centerOnUserLocation() async {
    if (_isDisposed) return; // Safety check

    try {
      if (currentLocation != null) {
        await _moveMapWhenReady(currentLocation!, 12.0);
      } else {
        // Try to get current position if location is null
        final position = await Geolocator.getCurrentPosition();
        final newLocation = LatLng(position.latitude, position.longitude);
        currentLocation = newLocation;
        await _moveMapWhenReady(newLocation, 15.0);
        _safeNotifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        showErrorMessage(TextStrings.unableToGetCurrentLocation);
      }
    }
  }

  Future<void> centerOnLocation(double latitude, double longitude) async {
    if (_isDisposed) return; // Safety check

    try {
      final location = LatLng(latitude, longitude);
      await _moveMapWhenReady(location, 15.0);

      // Add a temporary marker at this location
      destination = location;
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        showErrorMessage('Error centering on location: $e');
      }
    }
  }

  Future<void> fetchCoordinatesPoints(String location) async {
    if (_isDisposed) return; // Safety check

    final url = Uri.parse(
        '${ApiUrls.nominatimSearch}/search?q=$location&format=json&limit=1');

    try {
      final response = await http.get(url);

      if (_isDisposed) return; // Check again after async operation

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newLocation = LatLng(lat, lon);

          destination = newLocation;

          // Clear existing route when not in route mode
          if (!showRoute) {
            route = [];
          }
          _safeNotifyListeners();

          // Move to the location immediately
          await _moveMapWhenReady(newLocation, 13.0);

          // Only fetch route if route mode is enabled
          if (showRoute && !_isDisposed) {
            await fetchRoute();
          }
        } else {
          showErrorMessage(TextStrings.locationNotFound);
        }
      } else {
        showErrorMessage(TextStrings.failedToFetchLocation);
      }
    } catch (e) {
      if (!_isDisposed) {
        showErrorMessage('Error fetching location: $e');
      }
    }
  }

  Future<void> fetchRoute() async {
    if (_isDisposed) return; // Safety check
    if (currentLocation == null || destination == null) return;

    final url = Uri.parse("${ApiUrls.osrmRouting}/route/v1/driving/"
        "${currentLocation!.longitude},${currentLocation!.latitude};"
        "${destination!.longitude},${destination!.latitude}?overview=full&geometries=polyline");

    try {
      final response = await http.get(url);

      if (_isDisposed) return; // Check again after async operation

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        _decodePolyline(geometry);
        _safeNotifyListeners();

        // After route is decoded, fit bounds to show entire route
        if (route.isNotEmpty && !_isDisposed) {
          final bounds = LatLngBounds.fromPoints(route);
          await _mapReadyCompleter.future;
          if (!_isDisposed) {
            try {
              mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                  maxZoom: 7,
                ),
              );
            } catch (e) {
              print('Error fitting camera bounds: $e');
            }
          }
        }
      } else {
        showErrorMessage(TextStrings.failedToFetchRoute);
      }
    } catch (e) {
      if (!_isDisposed) {
        showErrorMessage('Error fetching route: $e');
      }
    }
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    route = decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  void showErrorMessage(String message) {
    if (_isDisposed) return; // Safety check
    if (_context == null) {
      print("Error: $message"); // Fallback when context is not available
      return;
    }

    ResponsiveSnackBar.showError(
      context: _context!,
      message: message,
    );
  }

  void showInfoMessage(String message) {
    if (_isDisposed || _context == null) return; // Safety check

    ResponsiveSnackBar.showInfo(
      context: _context!,
      message: message,
    );
  }

  void showSuccessMessage(String message) {
    if (_isDisposed || _context == null) return; // Safety check

    ResponsiveSnackBar.showSuccess(
      context: _context!,
      message: message,
    );
  }

  void onSearch() {
    if (_isDisposed) return; // Safety check

    final location = locationController.text.trim();
    if (location.isNotEmpty) {
      fetchCoordinatesPoints(location);
    }
  }

  Future<void> zoomIn() async {
    if (_isDisposed) return; // Safety check

    try {
      final currentCenter = mapController.camera.center;
      final currentZoom = mapController.camera.zoom;
      await _moveMapWhenReady(currentCenter, currentZoom + 1);
    } catch (e) {
      print('Error zooming in: $e');
    }
  }

  Future<void> zoomOut() async {
    if (_isDisposed) return; // Safety check

    try {
      final currentCenter = mapController.camera.center;
      final currentZoom = mapController.camera.zoom;
      await _moveMapWhenReady(currentCenter, currentZoom - 1);
    } catch (e) {
      print('Error zooming out: $e');
    }
  }

  void toggleMarkersAndRoute() {
    if (_isDisposed) return; // Safety check

    showMarkersAndRoute = !showMarkersAndRoute;
    _safeNotifyListeners();
  }

  void toggleRoute() {
    if (_isDisposed) return; // Safety check

    showRoute = !showRoute;
    if (!showRoute) {
      // Clear the route when disabling route mode
      route = [];
    } else if (destination != null) {
      // Only fetch route if destination exists and route mode is enabled
      fetchRoute();
    }
    _safeNotifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (_isDisposed) return; // Safety check

    if (query.isEmpty) {
      searchSuggestions = [];
      showSuggestions = false;
      _safeNotifyListeners();
      return;
    }

    final url = Uri.parse(
        '${ApiUrls.nominatimSearch}/search?format=json&q=$query&limit=5');

    try {
      final response = await http.get(url);

      if (_isDisposed) return; // Check again after async operation

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        searchSuggestions =
            data.map((place) => place['display_name'].toString()).toList();
        showSuggestions = searchSuggestions.isNotEmpty;
        _safeNotifyListeners();
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  void onSuggestionSelected(String suggestion) {
    if (_isDisposed) return; // Safety check

    locationController.text = suggestion;
    showSuggestions = false;
    _safeNotifyListeners();
    fetchCoordinatesPoints(suggestion);
  }

  void handleCategorySelected(List<CategoryItem> selectedCategories) {
    if (_isDisposed) return; // Safety check

    // TODO: Filter map markers based on selected categories
    // This would update the map based on category selection
    _safeNotifyListeners();
  }

  String formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void handleDateChanged(DateTime newDate) {
    if (_isDisposed) return; // Safety check

    selectedDate = newDate;
    // TODO: Update map data based on the selected date
    showInfoMessage(
        TextStrings.showingDataForDate.replaceFirst('%s', formatDate(newDate)));
    _safeNotifyListeners();
  }

  // Method to set a custom event marker on the map
  void setCustomMarker({
    required double latitude,
    required double longitude,
    required String eventType,
    String? description,
  }) {
    if (_isDisposed) return; // Safety check

    // Set destination coordinates (for compatibility with existing code)
    destination = LatLng(latitude, longitude);

    // Store event type and description for the marker
    _markerEventType = eventType;
    _markerDescription = description;

    // Notify listeners to update UI
    _safeNotifyListeners();
  }

  // Method to get user's current location as LatLng
  Future<LatLng?> getUserLocation() async {
    if (_isDisposed) return null; // Safety check

    try {
      // If we already have a current location, return it
      if (currentLocation != null) {
        return currentLocation;
      }

      // Otherwise, try to get the current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      // Update currentLocation
      currentLocation = newLocation;

      return newLocation;
    } catch (e) {
      if (!_isDisposed) {
        print('Error getting user location: $e');
      }
      return null;
    }
  }
}
