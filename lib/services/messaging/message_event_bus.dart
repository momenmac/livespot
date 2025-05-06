import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple event bus specifically for messaging-related events
/// like unread count changes, new messages, etc.
class MessageEventBus {
  // Singleton instance
  static final MessageEventBus _instance = MessageEventBus._internal();
  factory MessageEventBus() => _instance;
  MessageEventBus._internal() {
    // Initialize by trying to restore the last unread count
    _restoreLastUnreadCount();
  }

  // Stream controller for unread count changes
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Stream controller for conversation updates
  final StreamController<String> _conversationUpdateController =
      StreamController<String>.broadcast();

  // Keep track of the last notified unread count to prevent repeating the same value
  int _lastNotifiedCount = -1;
  
  // Key for storing the last unread count in shared preferences
  static const _unreadCountKey = 'last_unread_message_count';

  // Stream for receiving unread count updates
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  // Stream for conversation updates (conversationId)
  Stream<String> get conversationUpdateStream =>
      _conversationUpdateController.stream;
  
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
        debugPrint('🔔 MessageEventBus: Unread count changed to $newCount');
        
        // Save the new count to persistent storage
        _persistUnreadCount(newCount);
      }
    }
  }

  // Method to notify all listeners of a conversation update
  void notifyConversationChanged(String conversationId) {
    if (!_conversationUpdateController.isClosed) {
      _conversationUpdateController.add(conversationId);
      debugPrint('🔔 MessageEventBus: Conversation $conversationId updated');
    }
  }

  // Method to force refresh unread count from source
  Future<void> forceRefreshUnreadCount(Future<int> Function() countProvider) async {
    try {
      final count = await countProvider();
      notifyUnreadCountChanged(count);
    } catch (e) {
      debugPrint('❌ MessageEventBus: Error refreshing unread count: $e');
    }
  }

  // Persist the unread count to shared preferences
  Future<void> _persistUnreadCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, count);
      debugPrint('💾 MessageEventBus: Persisted unread count: $count');
    } catch (e) {
      debugPrint('❌ MessageEventBus: Failed to persist unread count: $e');
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
        debugPrint('📤 MessageEventBus: Restored unread count: $count');
      }
    } catch (e) {
      debugPrint('❌ MessageEventBus: Failed to restore unread count: $e');
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
    _conversationUpdateController.close();
  }
}
