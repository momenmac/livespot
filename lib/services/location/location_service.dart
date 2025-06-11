import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class LocationService {
  // Tulkarm coordinates as fallback
  static const double _tulkarmLatitude = 32.3082;
  static const double _tulkarmLongitude = 35.0283;

  /// Get the current position with multiple fallback strategies
  Future<Position> getCurrentPositionWithFallback() async {
    // For production web builds, immediately use Tulkarm to avoid permission issues
    if (kIsWeb && !kDebugMode) {
      print('Production web detected: Using Tulkarm location immediately');
      return _createTulkarmPosition();
    }

    try {
      // Strategy 1: Try to get current position (with shorter timeout for web)
      if (kIsWeb) {
        return await getCurrentPosition().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Web location request timed out, using fallback');
            throw Exception('Location timeout');
          },
        );
      } else {
        return await getCurrentPosition();
      }
    } catch (e) {
      print('Strategy 1 failed (getCurrentPosition): $e');

      try {
        // Strategy 2: Try to get last known position
        final lastKnown = await getLastKnownPosition();
        if (lastKnown != null) {
          print('Strategy 2 succeeded: Using last known position');
          return lastKnown;
        }
      } catch (e2) {
        print('Strategy 2 failed (getLastKnownPosition): $e2');
      }

      try {
        // Strategy 3: Try with lower accuracy and longer timeout (only in debug mode)
        if (kIsWeb && kDebugMode) {
          print('Strategy 3: Trying with lower accuracy for web (debug mode)');
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
        }
      } catch (e3) {
        print('Strategy 3 failed (low accuracy): $e3');
      }

      // Strategy 4: Final fallback to Tulkarm
      print(
          'All location strategies failed. Using Tulkarm as fallback location.');
      return _createTulkarmPosition();
    }
  }

  /// Create a Position object for Tulkarm as fallback
  Position _createTulkarmPosition() {
    return Position(
      latitude: _tulkarmLatitude,
      longitude: _tulkarmLongitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  /// Get the current position of the user (original method)
  Future<Position> getCurrentPosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, handle accordingly
        return Future.error('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, handle accordingly
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle accordingly
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      // When we reach here, permissions are granted and we can get the position
      // Add timeout for web to handle browser popup delays
      if (kIsWeb) {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } else {
        return await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      // Re-throw with more context for better debugging
      return Future.error('Failed to get current position: $e');
    }
  }

  /// Get the last known position of the user
  Future<Position?> getLastKnownPosition() async {
    // getLastKnownPosition is not supported on web platform
    if (kIsWeb) {
      // For web, we need to get current position instead
      try {
        return await getCurrentPosition();
      } catch (e) {
        // If we can't get current position, return null
        return null;
      }
    }
    return await Geolocator.getLastKnownPosition();
  }

  /// Calculate distance between two coordinates in meters
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Calculate distance between two coordinates in meters (alias for calculateDistance)
  double calculateDistanceInMeters(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return calculateDistance(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Stream position updates
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // minimum distance (in meters) before updates
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
