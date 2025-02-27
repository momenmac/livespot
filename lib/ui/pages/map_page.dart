import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
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
import 'dart:async';
import 'package:flutter_application_2/ui/widgets/map_message_overlay.dart';
import 'package:flutter_application_2/ui/widgets/map_categories.dart';

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
  bool _showMarkersAndRoute = true;
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  bool _hasInitializedLocation = false;
  bool _showRoute = false; // Add this property instead of _isMapInteractive
  StreamSubscription<Position>? _positionStreamSubscription;

  final flutter_map.LatLngBounds _mapBounds = flutter_map.LatLngBounds(
    LatLng(-85.0, -180.0),
    LatLng(85.0, 180.0),
  );

  // Add this property to store the selected date
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    // Cancel position subscription first
    _positionStreamSubscription?.cancel();

    // Safely remove overlay
    if (_overlayEntry != null) {
      _hideOverlay();
    }

    // Cancel debounce timer
    _debounce?.cancel();

    // Clear any references to map elements before disposal
    // This prevents the "deactivated widget's ancestor" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.dispose();
    });

    _locationController.dispose();

    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        _showErrorMessage(TextStrings.locationPermissionsRequired);
        return;
      }

      // For web, we need to get the position first before starting the stream
      if (kIsWeb) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = newLocation;
          });
          _mapController.move(newLocation, 10);
          _hasInitializedLocation = true;
        }
      }

      // Then start listening to position updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            final newLocation = LatLng(position.latitude, position.longitude);
            setState(() {
              _currentLocation = newLocation;
            });

            if (!_hasInitializedLocation) {
              _mapController.move(newLocation, 10);
              _hasInitializedLocation = true;
            }
          }
        },
        onError: (error) {
          _showErrorMessage('Error getting location: $error');
        },
      );
    } catch (e) {
      _showErrorMessage('${TextStrings.failedToInitializeLocationServices}$e');
    }
  }

  Future<void> _centerOnUserLocation() async {
    try {
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 12.0);
      } else {
        // Try to get current position if location is null
        final position = await Geolocator.getCurrentPosition();
        final newLocation = LatLng(position.latitude, position.longitude);

        if (mounted) {
          setState(() {
            _currentLocation = newLocation;
          });
          _mapController.move(newLocation, 15.0);
        }
      }
    } catch (e) {
      _showErrorMessage(TextStrings.unableToGetCurrentLocation);
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showErrorMessage(TextStrings.locationPermissionsDenied);
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorMessage(TextStrings.locationPermissionsDeniedPermanently);
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorMessage(TextStrings.locationServicesDisabled);
        return false;
      }

      return true;
    } catch (e) {
      _showErrorMessage('${TextStrings.errorCheckingLocationPermissions}$e');
      return false;
    }
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
        final newLocation = LatLng(lat, lon);

        setState(() {
          _destination = newLocation;
          // Clear existing route when new location is selected
          if (!_showRoute) {
            _route = [];
          }
        });

        // Move to the location immediately
        _mapController.move(newLocation, 13.0);

        // Only fetch route if route mode is enabled
        if (_showRoute) {
          await _fetchRoute();
        }
      } else {
        _showErrorMessage(TextStrings.locationNotFound);
      }
    } else {
      _showErrorMessage(TextStrings.failedToFetchLocation);
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

      // After route is decoded, fit bounds to show entire route
      if (_route.isNotEmpty) {
        final bounds = flutter_map.LatLngBounds.fromPoints(_route);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.all(50.0),
            maxZoom: 7,
          ),
        );
      }
    } else {
      _showErrorMessage(TextStrings.failedToFetchRoute);
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

  void _showErrorMessage(String message) {
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => MapMessageOverlay(
        message: message,
        isError: true,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), _hideOverlay);
  }

  void _hideOverlay() {
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
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

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchSuggestions =
              data.map((place) => place['display_name'].toString()).toList();
          _showSuggestions = _searchSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  void _onSuggestionSelected(String suggestion) {
    _locationController.text = suggestion;
    setState(() {
      _showSuggestions = false;
    });
    _fetchCoordinatesPoints(suggestion);
  }

  void _toggleRoute() {
    setState(() {
      _showRoute = !_showRoute;
      if (!_showRoute) {
        // Clear the route when disabling route mode
        _route = [];
      } else if (_destination != null) {
        // Only fetch route if destination exists and route mode is enabled
        _fetchRoute();
      }
    });
  }

  void _handleCategorySelected(List<CategoryItem> selectedCategories) {
    // Now we have access to all selected categories in a list

    // Update map markers/filters based on the selected categories
    // This function will be called whenever categories are toggled

    // We don't need to show error messages anymore
    // The UI handles selection visually

    // TODO: Filter map markers based on selected categories
    // TODO: Update map data query with category filters
    // TODO: Show only relevant markers based on categories
  }

  // Add formatting method for date display
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  // Add method to handle date changes
  void _handleDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      // TODO: Update map data based on the selected date
      // TODO: Fetch historical location data for the selected date
      // TODO: Show visual indicator that we're viewing historical data
      _showErrorMessage(TextStrings.showingDataForDate
          .replaceFirst('%s', _formatDate(newDate)));
    });
  }

  // Add date picker for large screens

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    // Extract date picker to a reusable method
    Widget _buildDatePicker() {
      return Container(
        height: 36,
        constraints: BoxConstraints(maxWidth: 160),
        decoration: BoxDecoration(
          color: ThemeConstants.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ThemeConstants.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != _selectedDate) {
                _handleDateChanged(picked);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: ThemeConstants.primaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.showBackButton && !isLargeScreen
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
              title: Text(TextStrings.map,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildDatePicker(),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Map and existing layers
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
          // Categories
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: MapCategories(
              onCategorySelected: _handleCategorySelected,
            ),
          ),
          // Search bar positioned at top
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDarkMode
                                ? ThemeConstants.darkCardColor
                                : ThemeConstants.lightBackgroundColor,
                            hintText: TextStrings.enterYourLocation,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onChanged: (value) {
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();
                            _debounce =
                                Timer(const Duration(milliseconds: 500), () {
                              _fetchSuggestions(value);
                            });
                          },
                          onSubmitted: (value) => _onSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
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
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? ThemeConstants.darkCardColor
                          : ThemeConstants.lightBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            _searchSuggestions[index],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () =>
                              _onSuggestionSelected(_searchSuggestions[index]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Map controls on left side
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
                          ? ThemeConstants.darkCardColor
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
                            ? ThemeConstants.darkCardColor
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
                          ? ThemeConstants.darkCardColor
                          : ThemeConstants.lightBackgroundColor,
                      onPressed: _zoomIn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: !isDarkMode
                            ? ThemeConstants.darkCardColor
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
                          ? ThemeConstants.darkCardColor
                          : ThemeConstants.lightBackgroundColor,
                      onPressed: _zoomOut,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: !isDarkMode
                            ? ThemeConstants.darkCardColor
                            : ThemeConstants.lightBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Add date picker for large screens (when no AppBar)
          if (!widget.showBackButton || isLargeScreen)
            Positioned(
              left: 60,
              bottom: 20,
              child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? ThemeConstants.darkCardColor
                        : ThemeConstants.lightBackgroundColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _buildDatePicker()),
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
              onPressed: _toggleRoute,
              backgroundColor: _showRoute ? ThemeConstants.primaryColor : null,
              child: Icon(
                Icons.route,
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
