import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'notification_model.dart';
import 'notification_popup.dart';

/// A comprehensive controller for handling notifications
/// This controller handles notification permissions, display, and management
class NotificationsController extends ChangeNotifier {
  // List of notifications
  List<NotificationModel> _notifications = [];

  // Permission state
  bool _isPermissionGranted = false;

  // FCM token
  String? _fcmToken;

  // Navigator key for showing overlays
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isPermissionGranted => _isPermissionGranted;
  String? get fcmToken => _fcmToken;

  // Constructor
  NotificationsController() {
    _loadInitialState();
  }

  /// Load initial state
  Future<void> _loadInitialState() async {
    await _loadPermissionState();
    await _loadNotifications();

    // If permission is granted, try to get the FCM token
    if (_isPermissionGranted) {
      _fcmToken = await FirebaseMessagingService.getToken();
      debugPrint('Loaded FCM token: $_fcmToken');
    }
  }

  /// Load permission state from SharedPreferences
  Future<void> _loadPermissionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPermissionGranted = prefs.getBool('notifications_enabled') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notification permission state: $e');
    }
  }

  /// Load notifications from storage
  Future<void> _loadNotifications() async {
    try {
      // In a real implementation, this would load from Firestore or another source
      // For now, we'll create some mock notifications
      _notifications = [
        NotificationModel(
          id: '1',
          title: 'Welcome to LiveSpot',
          body: 'Thank you for joining our community!',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          read: true,
          type: 'welcome',
          data: {'route': '/home'},
        ),
        NotificationModel(
          id: '2',
          title: 'New Event Nearby',
          body: 'There\'s a new event happening near you!',
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          read: false,
          type: 'event',
          data: {'route': '/events', 'eventId': '12345'},
        ),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Initialize notifications
  Future<void> initializeNotifications() async {
    try {
      // Request permission
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

        // Save permission state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_enabled', true);

        debugPrint('Notification permissions granted: $_isPermissionGranted');
        debugPrint('FCM Token: $_fcmToken');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Enable notifications
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
        debugPrint('Notifications enabled, token: $_fcmToken');
      }

      // Save setting to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _isPermissionGranted);

      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling notifications: $e');
    }
  }

  /// Disable notifications
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

      debugPrint('Notifications disabled successfully');
    } catch (e) {
      debugPrint('Error disabling notifications: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        notifyListeners();

        // In a real implementation, update the read status in Firestore
        debugPrint('Notification marked as read: $notificationId');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      _notifications.clear();
      notifyListeners();

      // In a real implementation, clear notifications in Firestore
      debugPrint('All notifications cleared');
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Show a notification popup
  void showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool autoHide = true,
  }) {
    try {
      debugPrint('Showing notification popup:');
      debugPrint('Title: $title');
      debugPrint('Body: $body');
      debugPrint('Data: $data');

      // Check if we have a valid navigator
      if (navigatorKey.currentContext != null) {
        NotificationPopup.show(
          context: navigatorKey.currentContext!,
          title: title,
          message: body,
          data: data,
          onTap: () {
            debugPrint('Notification tapped with data: $data');

            // Handle navigation based on the data
            if (data != null && data.containsKey('route')) {
              final route = data['route'];
              debugPrint('Navigating to route: $route');

              // Here you would use your app's navigation service
              // NavigationService().navigateTo(route);
            }
          },
        );

        // Add the notification to the list
        final notification = NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          body: body,
          timestamp: DateTime.now(),
          read: false,
          type: data?['type'] ?? 'general',
          data: data ?? {},
        );

        _notifications.insert(0, notification);
        notifyListeners();
      } else {
        debugPrint('No valid context for showing notification popup');
      }
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Add a new notification
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();

    // Show the notification popup
    showNotification(
      title: notification.title,
      body: notification.body,
      data: notification.data,
    );
  }

  /// Dispose of resources
  @override
  void dispose() {
    // Clean up any resources or listeners
    debugPrint('Disposing NotificationsController');
    super.dispose();
  }
}
