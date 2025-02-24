import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_2/ui/widgets/custom_marker.dart';
import 'package:flutter_application_2/ui/theme/floating_action_button_theme.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onBackPress;
  final bool showBackButton;

  const MapPage({
    super.key,
    this.onBackPress,
    this.showBackButton = true,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final TextEditingController _locationController = TextEditingController();
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _route = [];
  bool _isMapInteractive = false;
  bool _isLoading = true;
  bool _showMarkersAndRoute = true;
  bool _isRotationEnabled = false;

  final flutter_map.LatLngBounds _mapBounds = flutter_map.LatLngBounds(
    LatLng(-85.0, -180.0),
    LatLng(85.0, 180.0),
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (!await _checkPermissions()) return;

    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    });
  }

  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are denied")),
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Location permissions are permanently denied")),
      );
      return false;
    }
    return true;
  }

  Future<void> _fetchCoordinatesPoints(String location) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        setState(() {
          _destination = LatLng(lat, lon);
        });
        await _fetchRoute();
      } else {
        _showErrorMessage('Location not found. Please try another search.');
      }
    } else {
      _showErrorMessage('Failed to fetch location. Try again later.');
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    final url = Uri.parse("http://router.project-osrm.org/route/v1/driving/"
        "${_currentLocation!.longitude},${_currentLocation!.latitude};"
        "${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=polyline");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      _decodePolyline(geometry);
    } else {
      _showErrorMessage('Failed to fetch route. Try again later.');
    }
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    setState(() {
      _route = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    });
  }

  Future<void> _centerOnUserLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not available.")),
      );
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _onSearch() {
    final location = _locationController.text.trim();
    if (location.isNotEmpty) {
      _fetchCoordinatesPoints(location);
    }
  }

  void _zoomIn() {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(currentCenter, currentZoom + 1);
  }

  void _zoomOut() {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(currentCenter, currentZoom - 1);
  }

  void _toggleMarkersAndRoute() {
    setState(() {
      _showMarkersAndRoute = !_showMarkersAndRoute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.showBackButton
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (widget.onBackPress != null) {
                    widget.onBackPress!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: const Text('Map'),
            )
          : null,
      body: Stack(
        children: [
          flutter_map.FlutterMap(
            mapController: _mapController,
            options: flutter_map.MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 4,
              minZoom: 2,
              maxZoom: 18,
              cameraConstraint: flutter_map.CameraConstraint.contain(
                bounds: _mapBounds,
              ),
            ),
            children: [
              flutter_map.TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                tileProvider: kIsWeb
                    ? CancellableNetworkTileProvider()
                    : flutter_map.NetworkTileProvider(),
              ),
              if (_showMarkersAndRoute && _currentLocation != null)
                flutter_map.MarkerLayer(
                  markers: [
                    flutter_map.Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: CustomMarker(
                        location: _currentLocation!,
                        icon: Icons.home,
                        description: 'Current Location',
                        timestamp: DateTime.now(),
                        withCircle: true,
                        circleSize: 35,
                        iconSize: 30,
                      ),
                    ),
                  ],
                ),
              if (_showMarkersAndRoute && _destination != null)
                flutter_map.MarkerLayer(
                  markers: [
                    flutter_map.Marker(
                      point: _destination!,
                      width: 50,
                      height: 50,
                      child: CustomMarker(
                        location: _destination!,
                        icon: Icons.location_on,
                        description: 'Destination',
                        timestamp: DateTime.now(),
                        withCircle: true,
                        circleSize: 35,
                        iconSize: 30,
                      ),
                    ),
                  ],
                ),
              if (_showMarkersAndRoute &&
                  _currentLocation != null &&
                  _destination != null &&
                  _route.isNotEmpty)
                flutter_map.PolylineLayer(
                  polylines: [
                    flutter_map.Polyline(
                      points: _route,
                      strokeWidth: 5,
                      color: Colors.red,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDarkMode
                            ? ThemeConstants.darkBackgroundColor
                            : ThemeConstants.lightBackgroundColor,
                        hintText: 'Enter your location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (value) => _onSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      elevation: 0,
                      onPressed: _onSearch,
                      child: const Icon(
                        Icons.search,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 10,
            child: Column(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    floatingActionButtonTheme:
                        FloatingActionButtonTheme.zoomButtonTheme,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      backgroundColor: isDarkMode
                          ? ThemeConstants.darkBackgroundColor
                          : ThemeConstants.lightBackgroundColor,
                      onPressed: _toggleMarkersAndRoute,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _showMarkersAndRoute
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20,
                        color: !isDarkMode
                            ? ThemeConstants.darkBackgroundColor
                            : ThemeConstants.lightBackgroundColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    floatingActionButtonTheme:
                        FloatingActionButtonTheme.zoomButtonTheme,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      backgroundColor: isDarkMode
                          ? ThemeConstants.darkBackgroundColor
                          : ThemeConstants.lightBackgroundColor,
                      onPressed: _zoomIn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: !isDarkMode
                            ? ThemeConstants.darkBackgroundColor
                            : ThemeConstants.lightBackgroundColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    floatingActionButtonTheme:
                        FloatingActionButtonTheme.zoomButtonTheme,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      backgroundColor: isDarkMode
                          ? ThemeConstants.darkBackgroundColor
                          : ThemeConstants.lightBackgroundColor,
                      onPressed: _zoomOut,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: !isDarkMode
                            ? ThemeConstants.darkBackgroundColor
                            : ThemeConstants.lightBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              elevation: 0,
              onPressed: () async {
                await _centerOnUserLocation();
              },
              child: const Icon(
                Icons.my_location,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              elevation: 0,
              onPressed: () {
                setState(() {
                  _isMapInteractive = !_isMapInteractive;
                });
              },
              // backgroundColor: Colors.blue,
              child: Icon(
                _isMapInteractive ? Icons.lock_open : Icons.lock,
                size: 30,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
