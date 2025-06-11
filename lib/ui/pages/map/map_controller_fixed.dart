import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
      debugPrint('Ignoring error during map controller disposal: $e');
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
      debugPrint('🗺️ Centering on user location');
      if (currentLocation != null) {
        await _moveMapWhenReady(currentLocation!, 15.0);
        showInfoMessage("Centered on your location");
      } else {
        // Try to get current position if location is null
        debugPrint('🗺️ Current location not available, fetching position');
        showInfoMessage("Finding your location...");

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          ),
        );

        final newLocation = LatLng(position.latitude, position.longitude);
        currentLocation = newLocation;

        debugPrint(
            '🗺️ Got user location: ${position.latitude}, ${position.longitude}');
        await _moveMapWhenReady(newLocation, 15.0);

        showSuccessMessage("Found your location");
        _safeNotifyListeners();
      }

      // If route mode is enabled and we have a destination, recalculate route
      if (showRoute && destination != null) {
        debugPrint('🛣️ Recalculating route with updated user location');
        await fetchRoute();
      }
    } catch (e) {
      debugPrint('🗺️ Error centering on user location: $e');
      if (!_isDisposed) {
        showErrorMessage(TextStrings.unableToGetCurrentLocation);
      }
    }
  }

  Future<void> centerOnLocation(double latitude, double longitude) async {
    if (_isDisposed) return; // Safety check

    try {
      debugPrint('🗺️ Centering map on location: $latitude, $longitude');
      final location = LatLng(latitude, longitude);

      // Add a temporary marker at this location
      destination = location;
      _markerEventType = 'destination';
      _markerDescription = "Selected Location";

      // Make sure markers are visible
      showMarkersAndRoute = true;

      // Update UI
      _safeNotifyListeners();

      // Move map to the location
      await _moveMapWhenReady(location, 15.0);

      // If route mode is enabled, calculate route
      if (showRoute && currentLocation != null) {
        debugPrint(
            '🛣️ Route mode is enabled, calculating route to selected location');
        await fetchRoute();
      }

      showInfoMessage("Location centered on map");
    } catch (e) {
      debugPrint('🗺️ Error centering on location: $e');
      if (!_isDisposed) {
        showErrorMessage('Error centering on location: $e');
      }
    }
  }

  Future<void> fetchCoordinatesPoints(String location) async {
    if (_isDisposed) return; // Safety check

    // Trim and validate query
    final query = location.trim();
    if (query.isEmpty) {
      showInfoMessage("Please enter a location to search");
      return;
    }

    debugPrint('🔍 Searching for location: $query');
    showInfoMessage("Searching for $query...");

    // Track search start time for performance monitoring
    final searchStartTime = DateTime.now();

    // Create URL with optimization to return limited fields for faster response
    final url = Uri.parse(
        '${ApiUrls.nominatimSearch}/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&addressdetails=0&namedetails=0');

    debugPrint('🔍 Search URL: $url');

    try {
      final response = await http.get(url).timeout(
        const Duration(
            seconds:
                5), // Reduced timeout from 10 to 5 seconds for faster failures
        onTimeout: () {
          debugPrint('🔍 Search request timed out');
          showErrorMessage('Location search timed out. Please try again.');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      if (_isDisposed) return; // Check again after async operation

      // Calculate search response time
      final searchResponseTime =
          DateTime.now().difference(searchStartTime).inMilliseconds;
      debugPrint('🔍 Search API response took $searchResponseTime ms');

      if (response.statusCode == 200) {
        // Early validation of JSON response
        if (response.body.isEmpty) {
          debugPrint('🔍 Empty response received');
          showErrorMessage("No location data received. Please try again.");
          return;
        }

        try {
          final data = json.decode(response.body);

          if (data is! List || data.isEmpty) {
            debugPrint('🔍 No results found for location: $query');
            showErrorMessage(
                "Location not found. Please try a different search term.");
            return;
          }

          // Extract location data with safeguards
          final lat = double.tryParse(data[0]['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(data[0]['lon']?.toString() ?? '') ?? 0.0;
          final displayName =
              data[0]['display_name']?.toString() ?? 'Unknown location';

          // Validate coordinates
          if (lat == 0.0 && lon == 0.0) {
            debugPrint('🔍 Invalid coordinates received: $lat, $lon');
            showErrorMessage(
                "Invalid location coordinates received. Please try again.");
            return;
          }

          final newLocation = LatLng(lat, lon);
          debugPrint('🔍 Location found: $displayName at $lat,$lon');

          // Update destination and description
          destination = newLocation;
          _markerDescription = displayName;
          _markerEventType = 'destination';

          // Enable markers visibility
          showMarkersAndRoute = true;

          // Clear existing route when not in route mode
          if (!showRoute) {
            route = [];
          }

          // Notify listeners to update UI
          _safeNotifyListeners();

          // Move to the location immediately
          await _moveMapWhenReady(newLocation, 13.0);

          // Show success message
          showSuccessMessage("Location found: $displayName");

          // If route mode is enabled, calculate the route immediately
          if (showRoute && !_isDisposed) {
            debugPrint('🛣️ Route mode is enabled, calculating route...');
            await calculateRouteTo(newLocation); // Use the enhanced method
          }
        } catch (e) {
          debugPrint('🔍 Error parsing location data: $e');
          showErrorMessage("Error processing location data. Please try again.");
        }
      } else {
        debugPrint(
            '🔍 Search API error: ${response.statusCode} - ${response.body}');
        showErrorMessage(
            "Server error while finding location. Please try again.");
      }
    } catch (e) {
      debugPrint('🔍 Exception while searching location: $e');
      if (!_isDisposed) {
        showErrorMessage(
            'Network error. Please check your connection and try again.');
      }
    }
  }

  Future<void> fetchRoute() async {
    if (_isDisposed) return; // Safety check
    if (currentLocation == null || destination == null) {
      debugPrint(
          '🛣️ Cannot fetch route: current location or destination is null');
      showErrorMessage(TextStrings.failedToFetchRoute);
      return;
    }

    debugPrint(
        '🛣️ Fetching route from ${currentLocation!.latitude},${currentLocation!.longitude} to ${destination!.latitude},${destination!.longitude}');
    showInfoMessage("Finding route...");

    // Calculate straight-line distance (in km) between points using Haversine formula
    final double lat1 = currentLocation!.latitude;
    final double lon1 = currentLocation!.longitude;
    final double lat2 = destination!.latitude;
    final double lon2 = destination!.longitude;

    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = (lat2 - lat1) * pi / 180.0;
    final double dLon = (lon2 - lon1) * pi / 180.0;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c; // Distance in km

    // For very close points (under 100m), just create a direct line
    if (distance < 0.1) {
      // Less than 100 meters
      debugPrint(
          '🛣️ Points are very close (${(distance * 1000).toStringAsFixed(0)}m), creating direct route');
      route = [currentLocation!, destination!];
      showMarkersAndRoute = true;
      _safeNotifyListeners();
      showSuccessMessage(
          'Destination is ${(distance * 1000).toStringAsFixed(0)}m away');
      return;
    }

    // Important: OSRM API uses longitude,latitude order (not latitude,longitude)
    final url = Uri.parse("${ApiUrls.osrmRouting}/route/v1/driving/"
        "${currentLocation!.longitude},${currentLocation!.latitude};"
        "${destination!.longitude},${destination!.latitude}?overview=full&geometries=polyline&steps=true");

    debugPrint('🛣️ API URL: $url');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('🛣️ Route request timed out');
          showErrorMessage(
              'Route calculation is taking too long. Please try again.');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      if (_isDisposed) return; // Check again after async operation

      debugPrint('🛣️ Route API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if request was successful
        if (data['code'] != 'Ok') {
          debugPrint(
              '🛣️ OSRM API returned an error: ${data['code']} - ${data['message'] ?? 'Unknown error'}');
          showErrorMessage(
              'Route error: ${data['message'] ?? 'Failed to find route'}');
          return;
        }

        // Check if routes array exists and is not empty
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          debugPrint('🛣️ No routes found in API response');
          showErrorMessage('No route found for this destination');
          return;
        }

        final geometry = data['routes'][0]['geometry'];
        debugPrint('🛣️ Successfully received route geometry');

        // Clear existing route
        route.clear();

        // Decode new polyline
        _decodePolyline(geometry);
        debugPrint('🛣️ Route decoded with ${route.length} points');

        // Ensure showMarkersAndRoute is enabled
        showMarkersAndRoute = true;

        // Notify listeners to update the UI
        _safeNotifyListeners();

        // Show success message
        final distance =
            (data['routes'][0]['distance'] / 1000).toStringAsFixed(1);
        final duration =
            (data['routes'][0]['duration'] / 60).toStringAsFixed(0);
        showSuccessMessage(
            'Route found! Distance: $distance km (approx. $duration mins)');

        // After route is decoded, fit bounds to show entire route
        if (route.isNotEmpty && !_isDisposed) {
          final bounds = LatLngBounds.fromPoints(route);
          await _mapReadyCompleter.future;
          if (!_isDisposed) {
            try {
              debugPrint('🛣️ Fitting map to show entire route');
              mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                  maxZoom: 15, // Increased from 7 to 15 for better visibility
                ),
              );
            } catch (e) {
              debugPrint('🛣️ Error fitting camera bounds: $e');
            }
          }
        }
      } else {
        String errorBody = 'Unknown error';
        try {
          errorBody = response.body;
        } catch (_) {}
        debugPrint('🛣️ Route API error: ${response.statusCode} - $errorBody');
        showErrorMessage('Failed to find route. Please try again.');
      }
    } catch (e) {
      debugPrint('🛣️ Exception while fetching route: $e');
      if (!_isDisposed) {
        showErrorMessage(
            'Error calculating route: Connection problem. Please try again.');
      }
    }
  }

  void _decodePolyline(String encodedPolyline) {
    debugPrint('🛣️ Decoding polyline...');
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(encodedPolyline);

      if (decodedPoints.isEmpty) {
        debugPrint('🛣️ Warning: Decoded polyline is empty');
        return;
      }

      // Clear existing route points
      route.clear();

      // Add new route points
      route = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      debugPrint('🛣️ Polyline decoded with ${route.length} points');
    } catch (e) {
      debugPrint('🛣️ Error decoding polyline: $e');
      showErrorMessage('Error processing route data');
    }
  }

  void showErrorMessage(String message) {
    if (_isDisposed) return; // Safety check
    if (_context == null) {
      debugPrint("Error: $message"); // Fallback when context is not available
      return;
    }

    // Disable snackbars on web platform for map pages
    if (kIsWeb) {
      debugPrint("Map Error (Web): $message");
      return;
    }

    ResponsiveSnackBar.showError(
      context: _context!,
      message: message,
    );
  }

  void showInfoMessage(String message) {
    if (_isDisposed || _context == null) return; // Safety check

    // Disable snackbars on web platform for map pages
    if (kIsWeb) {
      debugPrint("Map Info (Web): $message");
      return;
    }

    ResponsiveSnackBar.showInfo(
      context: _context!,
      message: message,
    );
  }

  void showSuccessMessage(String message) {
    if (_isDisposed || _context == null) return; // Safety check

    // Disable snackbars on web platform for map pages
    if (kIsWeb) {
      debugPrint("Map Success (Web): $message");
      return;
    }

    ResponsiveSnackBar.showSuccess(
      context: _context!,
      message: message,
    );
  }

  void onSearch() {
    if (_isDisposed) return; // Safety check

    final location = locationController.text.trim();
    if (location.isNotEmpty) {
      debugPrint('🔍 Search button pressed for location: $location');
      fetchCoordinatesPoints(location);
    } else {
      debugPrint('🔍 Empty search query');
      showInfoMessage("Please enter a location to search");
    }
  }

  Future<void> zoomIn() async {
    if (_isDisposed) return; // Safety check

    try {
      final currentCenter = mapController.camera.center;
      final currentZoom = mapController.camera.zoom;
      await _moveMapWhenReady(currentCenter, currentZoom + 1);
    } catch (e) {
      debugPrint('Error zooming in: $e');
    }
  }

  Future<void> zoomOut() async {
    if (_isDisposed) return; // Safety check

    try {
      final currentCenter = mapController.camera.center;
      final currentZoom = mapController.camera.zoom;
      await _moveMapWhenReady(currentCenter, currentZoom - 1);
    } catch (e) {
      debugPrint('Error zooming out: $e');
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
    debugPrint('🛣️ Route mode ${showRoute ? 'enabled' : 'disabled'}');

    if (!showRoute) {
      // Clear the route when disabling route mode
      route = [];
      showInfoMessage("Route mode disabled");
    } else {
      showInfoMessage("Route mode enabled");
      // Only fetch route if destination exists and route mode is enabled
      if (destination != null && currentLocation != null) {
        debugPrint('🛣️ Destination exists, fetching route');
        // Small delay to improve user experience
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isDisposed) {
            fetchRoute();
          }
        });
      } else {
        debugPrint('🛣️ No destination set yet. Search for a location first.');
        showInfoMessage("Search for a destination to see the route");
      }
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
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void onSuggestionSelected(String suggestion) {
    if (_isDisposed) return; // Safety check

    debugPrint('🔍 Suggestion selected: $suggestion');
    locationController.text = suggestion;
    showSuggestions = false;
    _safeNotifyListeners();

    // Start search with a small delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isDisposed) {
        debugPrint('🔍 Starting search for selected suggestion');
        fetchCoordinatesPoints(suggestion);
      }
    });
  }

  void handleCategorySelected(List<CategoryItem> selectedCategories) {
    if (_isDisposed) return; // Safety check

    // Extract category names from the selected category items
    final categoryNames =
        selectedCategories.map((item) => item.name.toLowerCase()).toList();

    debugPrint(
        '🔖 Controller received ${selectedCategories.length} categories: $categoryNames');

    // Notify listeners to update the UI and trigger API request with the new filters
    _safeNotifyListeners();
  }

  String formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void handleDateChanged(DateTime newDate) {
    if (_isDisposed) return; // Safety check

    // Format for logs to make debugging easier
    final formattedDate =
        "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";

    debugPrint('📆 Date filter changed to: $formattedDate');
    selectedDate = newDate;

    // Update filter message for UI
    showInfoMessage(
        TextStrings.showingDataForDate.replaceFirst('%s', formatDate(newDate)));

    // Ensure this change is immediately reflected in the UI
    _safeNotifyListeners();

    // Log to make debugging easier
    debugPrint(
        '📣 Date change notification sent to listeners - API request will follow');
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      // Update currentLocation
      currentLocation = newLocation;

      return newLocation;
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error getting user location: $e');
      }
      return null;
    }
  }

  // Method for directly calculating a route to a given destination
  Future<void> calculateRouteTo(LatLng destinationPoint) async {
    if (_isDisposed) return; // Safety check

    debugPrint(
        '🛣️ Direct route calculation requested to: ${destinationPoint.latitude}, ${destinationPoint.longitude}');

    // Update destination
    destination = destinationPoint;
    _markerEventType = 'destination';
    _markerDescription = "Route Destination";

    // Enable markers and route visibility
    showMarkersAndRoute = true;
    showRoute = true;

    // Notify listeners to update UI
    _safeNotifyListeners();

    // Calculate distance first
    if (currentLocation != null) {
      // Calculate straight-line distance (in km) using Haversine formula
      final double lat1 = currentLocation!.latitude;
      final double lon1 = currentLocation!.longitude;
      final double lat2 = destinationPoint.latitude;
      final double lon2 = destinationPoint.longitude;

      const double earthRadius = 6371; // Radius of the earth in km
      final double dLat = (lat2 - lat1) * pi / 180.0;
      final double dLon = (lon2 - lon1) * pi / 180.0;

      final double a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180.0) *
              cos(lat2 * pi / 180.0) *
              sin(dLon / 2) *
              sin(dLon / 2);

      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final double distance = earthRadius * c; // Distance in km

      // For very close points (under 100m), just create a direct line
      if (distance < 0.1) {
        // Less than 100 meters
        debugPrint(
            '🛣️ Points are very close (${(distance * 1000).toStringAsFixed(0)}m), creating direct route');
        route = [currentLocation!, destinationPoint];
        showSuccessMessage(
            'Destination is ${(distance * 1000).toStringAsFixed(0)}m away');
        _safeNotifyListeners();
        return;
      }
    }

    // Calculate full route
    await fetchRoute();
  }
}
