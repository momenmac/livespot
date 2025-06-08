import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationService {
  /// Get the current position of the user
  Future<Position> getCurrentPosition() async {
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
    return await Geolocator.getCurrentPosition();
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
