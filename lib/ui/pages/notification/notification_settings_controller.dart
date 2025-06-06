import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';

/// A controller for managing notification settings and permissions
class NotificationSettingsController extends ChangeNotifier {
  bool _isPermissionGranted = false;
  String? _fcmToken;

  bool get isPermissionGranted => _isPermissionGranted;
  String? get fcmToken => _fcmToken;

  NotificationSettingsController() {
    _loadSettings();
  }

  /// Load notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPermissionGranted = prefs.getBool('notifications_enabled') ?? false;

      if (_isPermissionGranted) {
        // Get current FCM token if permissions are granted
        _fcmToken = await FirebaseMessagingService.getToken();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading notification settings: $e');
    }
  }

  /// Enable notifications and register FCM token
  Future<void> enableNotifications() async {
    try {
      // Request notification permissions
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _isPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (_isPermissionGranted) {
        // Initialize FCM token service
        await FirebaseMessagingService.initialize();
        _fcmToken = await FirebaseMessagingService.getToken();
        debugPrint('✅ Notifications enabled, token: $_fcmToken');
      }

      // Save setting to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _isPermissionGranted);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error enabling notifications: $e');
      throw Exception('Failed to enable notifications: $e');
    }
  }

  /// Disable notifications and deactivate FCM token
  Future<void> disableNotifications() async {
    try {
      // Deactivate the current FCM token
      await FirebaseMessagingService.deactivateCurrentToken();

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);

      _isPermissionGranted = false;
      _fcmToken = null;
      notifyListeners();

      debugPrint('✅ Notifications disabled successfully');
    } catch (e) {
      debugPrint('❌ Error disabling notifications: $e');
      throw Exception('Failed to disable notifications: $e');
    }
  }

  /// Check current notification permission status
  Future<void> checkPermissionStatus() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      _isPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _isPermissionGranted);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking notification permission status: $e');
    }
  }
}
