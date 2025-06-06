import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'package:flutter_application_2/services/api/notification_api_service.dart';
import 'package:flutter_application_2/services/notifications/notification_event_bus.dart';
import 'notification_model.dart';
import 'notification_popup.dart';

class NotificationsController extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isPermissionGranted = false;
  String? _fcmToken;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isPermissionGranted => _isPermissionGranted;
  String? get fcmToken => _fcmToken;
  int get unreadCount => _unreadCount;

  // Global key for accessing navigator
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  NotificationsController() {
    _loadInitialState();
  }

  /// Load initial state
  Future<void> _loadInitialState() async {
    await _loadPermissionState();
    await loadNotifications();
    await loadUnreadCount(); // Load unread count on initialization

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

  Future<void> initializeNotifications() async {
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

  Future<void> loadNotifications() async {
    try {
      // For now, use mock data with updated model structure
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
        NotificationModel.legacy(
          message: "New message from John Doe",
          dateTime: DateTime.now(),
          icon: Icons.message,
        ),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

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

      // Fallback: just update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      _isPermissionGranted = false;
      notifyListeners();
    }
  }

  void markAsRead(String notificationId) {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        notifyListeners();
        debugPrint('Notification marked as read: $notificationId');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void clearAll() {
    try {
      _notifications.clear();
      notifyListeners();
      debugPrint('All notifications cleared');
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  static void showNotification({
    required String title,
    required String message,
    IconData? icon,
    VoidCallback? onTap,
    Map<String, dynamic>? data,
  }) {
    debugPrint('🚀 NotificationsController.showNotification() called');
    debugPrint('📝 Title: "$title"');
    debugPrint('💬 Message: "$message"');

    if (navigatorKey.currentContext == null) {
      debugPrint('❌ Navigator context is NULL! Cannot show notification');
      return;
    }

    debugPrint('✅ Navigator context found, showing notification popup');

    try {
      NotificationPopup.show(
        context: navigatorKey.currentContext!,
        title: title,
        message: message,
        icon: icon,
        data: data,
        onTap: () {
          debugPrint('🎯 Notification tapped: $title');
          onTap?.call();
        },
      );
      debugPrint('✅ Notification popup shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Add a new notification
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();

    // Show the notification popup
    showNotification(
      title: notification.title,
      message: notification.body,
      data: notification.data,
    );
  }

  /// Load unread notification count from API
  Future<void> loadUnreadCount() async {
    try {
      final count = await NotificationApiService.getUnreadNotificationCount();
      _unreadCount = count;

      // Notify the event bus of the updated count
      NotificationEventBus().notifyUnreadCountChanged(count);

      notifyListeners();
      debugPrint('✅ Unread notification count loaded: $count');
    } catch (e) {
      debugPrint('❌ Error loading unread notification count: $e');
    }
  }

  /// Update unread count and notify listeners
  void updateUnreadCount(int newCount) {
    if (_unreadCount != newCount) {
      _unreadCount = newCount;
      NotificationEventBus().notifyUnreadCountChanged(newCount);
      notifyListeners();
      debugPrint('🔔 Unread notification count updated to: $newCount');
    }
  }

  /// Refresh unread count from server
  Future<void> refreshUnreadCount() async {
    await loadUnreadCount();
  }

  @override
  void dispose() {
    debugPrint('Disposing NotificationsController');
    super.dispose();
  }
}
