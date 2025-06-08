import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api/event_api_service.dart';
import '../api/notification_api_service.dart';
import 'location_service.dart';

/// Service to monitor user location in relation to events
class LocationEventMonitor with WidgetsBindingObserver {
  static final LocationEventMonitor _instance =
      LocationEventMonitor._internal();
  factory LocationEventMonitor() => _instance;
  LocationEventMonitor._internal() {
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  // Dependencies
  final LocationService _locationService = LocationService();

  // State
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;

  // Configurable parameters
  double _proximityThresholdMeters = 200; // Default: 200 meters
  int _monitoringIntervalSeconds = 60; // Default: check every 60 seconds
  int _minimumTimeBetweenNotificationsMinutes = 60; // Default: 60 minutes

  // Event cache (to avoid duplicate checks)
  final Map<String, DateTime> _lastNotificationForEvent = {};

  /// Start monitoring user location in relation to events
  Future<bool> startMonitoring() async {
    if (_isMonitoring) {
      debugPrint('📍 LocationEventMonitor: Already monitoring');
      return true;
    }

    try {
      // Check if "Still happening" notifications are enabled
      bool stillHappeningEnabled = true; // Default to enabled

      try {
        final settings = await NotificationApiService.getNotificationSettings();
        stillHappeningEnabled =
            settings?['still_happening_notifications'] ?? true;
        debugPrint('📱 Using notification settings from user preferences');

        if (!stillHappeningEnabled) {
          debugPrint('📱 "Still happening" notifications are disabled by user');
          return false;
        }
      } catch (e) {
        if (e.toString().contains('User not authenticated')) {
          debugPrint('⚠️ User not authenticated, using default settings');
        } else {
          debugPrint('⚠️ Error getting notification settings: $e');
        }
        // Continue with default settings (enabled)
      }

      debugPrint('📍 LocationEventMonitor: Starting location monitoring');

      // Get current position first
      try {
        _lastPosition = await _locationService.getCurrentPosition();
        debugPrint(
            '📍 Initial position: ${_lastPosition?.latitude}, ${_lastPosition?.longitude}');
      } catch (e) {
        debugPrint(
            '⚠️ LocationEventMonitor: Could not get initial position: $e');
        // Try to get last known position as fallback (only on non-web platforms)
        if (!kIsWeb) {
          _lastPosition = await _locationService.getLastKnownPosition();
          if (_lastPosition != null) {
            debugPrint(
                '📍 Using last known position: ${_lastPosition?.latitude}, ${_lastPosition?.longitude}');
          }
        }
      }

      // Set up position stream for regular updates
      _positionStreamSubscription = _locationService
          .getPositionStream(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20, // Update when user moves 20+ meters
          )
          .listen(
            _onPositionUpdate,
            onError: (error) => debugPrint('⚠️ Position stream error: $error'),
          );

      // Set up timer for regular checks of nearby events
      _monitorTimer = Timer.periodic(
        Duration(seconds: _monitoringIntervalSeconds),
        (_) => _checkNearbyEvents(),
      );

      _isMonitoring = true;
      debugPrint('✅ LocationEventMonitor: Started monitoring');

      // Do an initial check right away
      _checkNearbyEvents();

      return true;
    } catch (e) {
      debugPrint('❌ LocationEventMonitor: Failed to start monitoring: $e');
      stopMonitoring();
      return false;
    }
  }

  /// Stop monitoring user location
  void stopMonitoring() {
    debugPrint('📍 LocationEventMonitor: Stopping monitoring');

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _monitorTimer?.cancel();
    _monitorTimer = null;

    _isMonitoring = false;
    debugPrint('✅ LocationEventMonitor: Stopped monitoring');
  }

  /// Update proximity threshold distance
  void setProximityThreshold(double meters) {
    _proximityThresholdMeters = meters;
    debugPrint(
        '📍 LocationEventMonitor: Set proximity threshold to $_proximityThresholdMeters meters');
  }

  /// Update monitoring interval
  void setMonitoringInterval(int seconds) {
    _monitoringIntervalSeconds = seconds;

    // Reset timer if already monitoring
    if (_isMonitoring && _monitorTimer != null) {
      _monitorTimer!.cancel();
      _monitorTimer = Timer.periodic(
        Duration(seconds: _monitoringIntervalSeconds),
        (_) => _checkNearbyEvents(),
      );
    }

    debugPrint(
        '📍 LocationEventMonitor: Set monitoring interval to $_monitoringIntervalSeconds seconds');
  }

  /// Handle position updates from the stream
  void _onPositionUpdate(Position position) {
    _lastPosition = position;
    debugPrint(
        '📍 Position updated: ${position.latitude}, ${position.longitude}');

    // Don't check on every position update to save battery
    // The timer will handle regular checks
  }

  /// Check for events near the user's current location
  Future<void> _checkNearbyEvents() async {
    if (_lastPosition == null) {
      debugPrint('⚠️ LocationEventMonitor: No position available for check');
      return;
    }

    try {
      // Check if "Still happening" notifications are enabled
      bool stillHappeningEnabled = true; // Default to enabled

      try {
        final settings = await NotificationApiService.getNotificationSettings();
        stillHappeningEnabled =
            settings?['still_happening_notifications'] ?? true;

        if (!stillHappeningEnabled) {
          debugPrint('📱 "Still happening" notifications are disabled by user');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Error getting notification settings: $e');
        debugPrint('📍 Using default notification settings (enabled)');
        // Continue with default settings (enabled)
      }

      debugPrint('🔍 Checking for nearby events...');

      // Get nearby events from API
      final events = await EventApiService.getNearbyEvents(
        latitude: _lastPosition!.latitude,
        longitude: _lastPosition!.longitude,
        radiusMeters: _proximityThresholdMeters,
      );

      if (events.isEmpty) {
        debugPrint('📍 No nearby events found');
        return;
      }

      debugPrint('📍 Found ${events.length} nearby events');

      // Process each nearby event
      for (final event in events) {
        final eventId = event['id'].toString();
        final eventName = event['title'] ?? 'Event';
        final eventLat = double.tryParse(event['latitude'].toString()) ?? 0;
        final eventLng = double.tryParse(event['longitude'].toString()) ?? 0;

        // Skip events we've recently notified about
        final lastNotificationTime = _lastNotificationForEvent[eventId];
        final now = DateTime.now();
        if (lastNotificationTime != null) {
          final minutesSinceLastNotification =
              now.difference(lastNotificationTime).inMinutes;

          if (minutesSinceLastNotification <
              _minimumTimeBetweenNotificationsMinutes) {
            debugPrint(
                '📍 Skipping event $eventName ($eventId): notified $minutesSinceLastNotification minutes ago');
            continue;
          }
        }

        // Calculate precise distance
        final distance = _locationService.calculateDistanceInMeters(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          eventLat,
          eventLng,
        );

        debugPrint('📍 Event $eventName ($eventId) is $distance meters away');

        if (distance <= _proximityThresholdMeters) {
          // User is near this event - send "still there" confirmation request
          await _sendStillThereNotification(event);

          // Remember when we sent this notification
          _lastNotificationForEvent[eventId] = now;
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking nearby events: $e');
    }
  }

  /// Send a "still there" confirmation notification for an event
  Future<void> _sendStillThereNotification(Map<String, dynamic> event) async {
    try {
      final eventId = event['id'].toString();
      final eventName = event['title'] ?? 'Event';

      debugPrint('📱 Sending "still there" notification for event: $eventName');

      try {
        // Create confirmation request in backend
        final confirmation =
            await NotificationApiService.createEventConfirmation(
          eventId: eventId,
        );

        if (confirmation != null && confirmation['id'] != null) {
          final confirmationId = confirmation['id'].toString();
          debugPrint('✅ Created confirmation request with ID: $confirmationId');

          // Send a local notification to show right away
          await NotificationApiService.sendStillThereConfirmation(
            eventId: eventId,
            eventTitle: eventName,
            eventImageUrl: event['image_url'] ?? '',
            confirmationId: confirmationId,
          );

          debugPrint('✅ Sent "still there" notification for event: $eventName');
        } else {
          debugPrint('❌ Failed to create confirmation request');
        }
      } catch (e) {
        if (e.toString().contains('User not authenticated')) {
          debugPrint('⚠️ Cannot send notification: User not authenticated');
          // We can't send notifications without authentication
        } else {
          debugPrint('❌ Error sending "still there" notification: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending "still there" notification: $e');
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint(
        '📱 LocationEventMonitor: App lifecycle state changed to $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and interactive
        if (_isMonitoring) {
          debugPrint('📍 App resumed - ensuring location monitoring is active');
          _resumeMonitoring();
        }
        break;

      case AppLifecycleState.inactive:
        // App is inactive, but visible
        break;

      case AppLifecycleState.paused:
        // App is in background
        if (_isMonitoring) {
          debugPrint('📍 App paused - optimizing monitoring for background');
          _optimizeForBackground();
        }
        break;

      case AppLifecycleState.detached:
        // App is detached (might be terminated)
        break;

      case AppLifecycleState.hidden:
        // App is hidden (not visible to user)
        break;
    }
  }

  /// Resume monitoring after app returns to foreground
  void _resumeMonitoring() {
    // Restore normal monitoring frequency
    if (_monitorTimer != null) {
      _monitorTimer!.cancel();
      _monitorTimer = Timer.periodic(
        Duration(seconds: _monitoringIntervalSeconds),
        (_) => _checkNearbyEvents(),
      );
    }

    // Make sure position updates are flowing
    if (_positionStreamSubscription == null) {
      _positionStreamSubscription = _locationService
          .getPositionStream(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          )
          .listen(
            _onPositionUpdate,
            onError: (error) => debugPrint('⚠️ Position stream error: $error'),
          );
    }

    // Check for events right away
    _checkNearbyEvents();
  }

  /// Optimize monitoring for background operation
  void _optimizeForBackground() {
    // Use a less frequent check interval in background
    if (_monitorTimer != null) {
      _monitorTimer!.cancel();
      _monitorTimer = Timer.periodic(
        const Duration(minutes: 15), // Less frequent checks in background
        (_) => _checkNearbyEvents(),
      );
    }

    // Keep position updates flowing but with lower frequency
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = _locationService
          .getPositionStream(
            accuracy: LocationAccuracy.medium, // Lower accuracy
            distanceFilter: 100, // Only update when moved 100+ meters
          )
          .listen(
            _onPositionUpdate,
            onError: (error) => debugPrint('⚠️ Position stream error: $error'),
          );
    }
  }

  /// Dispose resources when service is no longer needed
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopMonitoring();
  }

  /// Get the current monitoring state
  bool get isMonitoring => _isMonitoring;

  /// Get the current proximity threshold in meters
  double get proximityThresholdMeters => _proximityThresholdMeters;

  /// Get the current monitoring interval in seconds
  int get monitoringIntervalSeconds => _monitoringIntervalSeconds;
}
