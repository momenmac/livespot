import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Event bus for notification count changes
/// Similar to MessageEventBus but specifically for notifications
class NotificationEventBus {
  static final NotificationEventBus _instance =
      NotificationEventBus._internal();
  factory NotificationEventBus() => _instance;
  NotificationEventBus._internal() {
    _restoreLastUnreadCount();
  }

  static const String _unreadCountKey = 'notification_unread_count';

  // Stream controllers for events
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<String> _notificationUpdateController =
      StreamController<String>.broadcast();

  // Keep track of the last notified count to avoid redundant notifications
  int _lastNotifiedCount = 0;

  // Streams that external widgets can listen to
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  // Stream for individual notification updates (notificationId)
  Stream<String> get notificationUpdateStream =>
      _notificationUpdateController.stream;

  // Getter for the current unread count
  int get currentUnreadCount => _lastNotifiedCount > 0 ? _lastNotifiedCount : 0;

  // Method to notify all listeners of a change in unread count
  void notifyUnreadCountChanged(int newCount) {
    if (!_unreadCountController.isClosed) {
      // Only notify if the count is different from the last notification
      // or if we're on web (where we need more frequent updates)
      if (_lastNotifiedCount != newCount || kIsWeb) {
        _lastNotifiedCount = newCount;
        _unreadCountController.add(newCount);
        debugPrint(
            '🔔 NotificationEventBus: Unread count changed to $newCount');

        // Save the new count to persistent storage
        _persistUnreadCount(newCount);
      }
    }
  }

  // Method to notify all listeners of a notification update
  void notifyNotificationChanged(String notificationId) {
    if (!_notificationUpdateController.isClosed) {
      _notificationUpdateController.add(notificationId);
      debugPrint(
          '🔔 NotificationEventBus: Notification $notificationId updated');
    }
  }

  // Method to force refresh unread count from source
  Future<void> forceRefreshUnreadCount(
      Future<int> Function() countProvider) async {
    try {
      final count = await countProvider();
      notifyUnreadCountChanged(count);
    } catch (e) {
      debugPrint('❌ NotificationEventBus: Error refreshing unread count: $e');
    }
  }

  // Persist the unread count to shared preferences
  Future<void> _persistUnreadCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, count);
      debugPrint('💾 NotificationEventBus: Persisted unread count: $count');
    } catch (e) {
      debugPrint('❌ NotificationEventBus: Failed to persist unread count: $e');
    }
  }

  // Restore the last unread count from shared preferences
  Future<void> _restoreLastUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_unreadCountKey);
      if (count != null && count != _lastNotifiedCount) {
        _lastNotifiedCount = count;
        _unreadCountController.add(count);
        debugPrint('📤 NotificationEventBus: Restored unread count: $count');
      }
    } catch (e) {
      debugPrint('❌ NotificationEventBus: Failed to restore unread count: $e');
    }
  }

  // Manual reset of the unread count (useful for sign out)
  Future<void> resetUnreadCount() async {
    notifyUnreadCountChanged(0);
  }

  // Check if we've missed any updates (especially important for web)
  void checkForMissedUpdates(Future<int> Function() countProvider) {
    if (kIsWeb) {
      // On web, we need to double-check our count more frequently
      forceRefreshUnreadCount(countProvider);
    }
  }

  // Cleanup method
  void dispose() {
    _unreadCountController.close();
    _notificationUpdateController.close();
  }
}
