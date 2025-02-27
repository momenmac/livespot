import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
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

  // Set context for error messages
  void setContext(BuildContext context) {
    _context = context;
  }

  @override
  void dispose() {
    super.dispose();
    positionStreamSubscription?.cancel();
    debounce?.cancel();
    mapController.dispose();
    locationController.dispose();
  }

  Future<void> initializeLocation() async {
    try {
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        return;
      }

      // For web, get position first
      if (kIsWeb) {
        final position = await Geolocator.getCurrentPosition();
        currentLocation = LatLng(position.latitude, position.longitude);
        mapController.move(currentLocation!, 10);
        hasInitializedLocation = true;
        notifyListeners();
      }

      // Start position stream
      positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          final newLocation = LatLng(position.latitude, position.longitude);
          currentLocation = newLocation;
          notifyListeners();

          if (!hasInitializedLocation) {
            mapController.move(newLocation, 10);
            hasInitializedLocation = true;
          }
        },
        onError: (error) {
          showErrorMessage('Error getting location: $error');
        },
      );
    } catch (e) {
      showErrorMessage('${TextStrings.failedToInitializeLocationServices}$e');
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
    try {
      if (currentLocation != null) {
        mapController.move(currentLocation!, 12.0);
      } else {
        // Try to get current position if location is null
        final position = await Geolocator.getCurrentPosition();
        final newLocation = LatLng(position.latitude, position.longitude);
        currentLocation = newLocation;
        mapController.move(newLocation, 15.0);
        notifyListeners();
      }
    } catch (e) {
      showErrorMessage(TextStrings.unableToGetCurrentLocation);
    }
  }

  Future<void> fetchCoordinatesPoints(String location) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1');

    try {
      final response = await http.get(url);

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
          notifyListeners();

          // Move to the location immediately
          mapController.move(newLocation, 13.0);

          // Only fetch route if route mode is enabled
          if (showRoute) {
            await fetchRoute();
          }
        } else {
          showErrorMessage(TextStrings.locationNotFound);
        }
      } else {
        showErrorMessage(TextStrings.failedToFetchLocation);
      }
    } catch (e) {
      showErrorMessage('Error fetching location: $e');
    }
  }

  Future<void> fetchRoute() async {
    if (currentLocation == null || destination == null) return;

    final url = Uri.parse("http://router.project-osrm.org/route/v1/driving/"
        "${currentLocation!.longitude},${currentLocation!.latitude};"
        "${destination!.longitude},${destination!.latitude}?overview=full&geometries=polyline");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        _decodePolyline(geometry);
        notifyListeners();

        // After route is decoded, fit bounds to show entire route
        if (route.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(route);
          mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50.0),
              maxZoom: 7,
            ),
          );
        }
      } else {
        showErrorMessage(TextStrings.failedToFetchRoute);
      }
    } catch (e) {
      showErrorMessage('Error fetching route: $e');
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
    if (_context == null) return;

    ResponsiveSnackBar.showInfo(
      context: _context!,
      message: message,
    );
  }

  void showSuccessMessage(String message) {
    if (_context == null) return;

    ResponsiveSnackBar.showSuccess(
      context: _context!,
      message: message,
    );
  }

  void onSearch() {
    final location = locationController.text.trim();
    if (location.isNotEmpty) {
      fetchCoordinatesPoints(location);
    }
  }

  void zoomIn() {
    final currentCenter = mapController.camera.center;
    final currentZoom = mapController.camera.zoom;
    mapController.move(currentCenter, currentZoom + 1);
  }

  void zoomOut() {
    final currentCenter = mapController.camera.center;
    final currentZoom = mapController.camera.zoom;
    mapController.move(currentCenter, currentZoom - 1);
  }

  void toggleMarkersAndRoute() {
    showMarkersAndRoute = !showMarkersAndRoute;
    notifyListeners();
  }

  void toggleRoute() {
    showRoute = !showRoute;
    if (!showRoute) {
      // Clear the route when disabling route mode
      route = [];
    } else if (destination != null) {
      // Only fetch route if destination exists and route mode is enabled
      fetchRoute();
    }
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      searchSuggestions = [];
      showSuggestions = false;
      notifyListeners();
      return;
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        searchSuggestions =
            data.map((place) => place['display_name'].toString()).toList();
        showSuggestions = searchSuggestions.isNotEmpty;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  void onSuggestionSelected(String suggestion) {
    locationController.text = suggestion;
    showSuggestions = false;
    notifyListeners();
    fetchCoordinatesPoints(suggestion);
  }

  void handleCategorySelected(List<CategoryItem> selectedCategories) {
    // TODO: Filter map markers based on selected categories
    // This would update the map based on category selection
    notifyListeners();
  }

  String formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void handleDateChanged(DateTime newDate) {
    selectedDate = newDate;
    // TODO: Update map data based on the selected date
    showInfoMessage(
        TextStrings.showingDataForDate.replaceFirst('%s', formatDate(newDate)));
    notifyListeners();
  }
}
