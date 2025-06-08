import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/services/location/location_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;

class LocationCacheService {
  static final LocationCacheService _instance =
      LocationCacheService._internal();
  factory LocationCacheService() => _instance;
  LocationCacheService._internal();

  // Cached location data
  Position? _cachedPosition;
  DateTime? _lastUpdate;
  Timer? _updateTimer;

  // Cache settings
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _updateInterval =
      Duration(minutes: 2); // Update every 2 minutes
  static const Duration _persistentCacheExpiry = Duration(minutes: 15);

  final LocationService _locationService = LocationService();

  // Stream controller for location updates
  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  // Initialize the service
  Future<void> initialize() async {
    await _loadFromCache();
    _startPeriodicUpdates();

    // Get initial location if cache is empty or expired
    if (_cachedPosition == null || _isExpired) {
      await _updateLocation();
    }
  }

  // Start periodic location updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (timer) {
      _updateLocation();
    });
    developer.log(
        'Started automatic location updates every ${_updateInterval.inMinutes} minutes',
        name: 'LocationCache');
  }

  // Stop periodic updates
  void stopUpdates() {
    _updateTimer?.cancel();
    developer.log('Stopped automatic location updates', name: 'LocationCache');
  }

  // Get current cached position
  Position? get cachedPosition => _isValid ? _cachedPosition : null;

  // Check if cache is valid
  bool get _isValid => _cachedPosition != null && !_isExpired;

  // Check if cache is expired
  bool get _isExpired {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > _cacheExpiry;
  }

  // Force update location
  Future<Position?> forceUpdate() async {
    return await _updateLocation();
  }

  // Update location in background
  Future<Position?> _updateLocation() async {
    try {
      developer.log('Updating user location...', name: 'LocationCache');

      // Try last known position first (only on non-web platforms)
      Position? position;

      if (!kIsWeb) {
        position = await _locationService.getLastKnownPosition();
      }

      // If no last known position, get current position
      position ??= await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 5));

      _cachedPosition = position;
      _lastUpdate = DateTime.now();

      // Persist to storage
      await _saveToCache(position);

      // Notify listeners
      _locationController.add(position);

      developer.log(
          'Location updated: ${position.latitude}, ${position.longitude}',
          name: 'LocationCache');
      return position;
    } catch (e) {
      developer.log('Failed to update location: $e', name: 'LocationCache');
    }
    return null;
  }

  // Load from persistent cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latitude = prefs.getDouble('user_latitude');
      final longitude = prefs.getDouble('user_longitude');
      final timestamp = prefs.getInt('location_timestamp');

      if (latitude != null && longitude != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

        // Check if persistent cache is still valid
        if (cacheAge < _persistentCacheExpiry.inMilliseconds) {
          _cachedPosition = Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          _lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          developer.log('Loaded location from persistent cache',
              name: 'LocationCache');
        }
      }
    } catch (e) {
      developer.log('Failed to load cached location: $e',
          name: 'LocationCache');
    }
  }

  // Save to persistent cache
  Future<void> _saveToCache(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('user_latitude', position.latitude);
      await prefs.setDouble('user_longitude', position.longitude);
      await prefs.setInt(
          'location_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('Failed to save location cache: $e', name: 'LocationCache');
    }
  }

  // Calculate distance to a point
  double calculateDistance(double latitude, double longitude) {
    if (_cachedPosition == null) return -1;

    return _locationService.calculateDistance(
      _cachedPosition!.latitude,
      _cachedPosition!.longitude,
      latitude,
      longitude,
    );
  }

  // Dispose resources
  void dispose() {
    _updateTimer?.cancel();
    _locationController.close();
  }
}
