import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simple event bus specifically for messaging-related events
/// like unread count changes, new messages, etc.
class MessageEventBus {
  // Singleton instance
  static final MessageEventBus _instance = MessageEventBus._internal();
  factory MessageEventBus() => _instance;
  MessageEventBus._internal();

  // Stream controller for unread count changes
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Stream controller for conversation updates
  final StreamController<String> _conversationUpdateController =
      StreamController<String>.broadcast();

  // Keep track of the last notified unread count to prevent repeating the same value
  int _lastNotifiedCount = -1;

  // Stream for receiving unread count updates
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  // Stream for conversation updates (conversationId)
  Stream<String> get conversationUpdateStream =>
      _conversationUpdateController.stream;

  // Method to notify all listeners of a change in unread count
  void notifyUnreadCountChanged(int newCount) {
    if (!_unreadCountController.isClosed) {
      // Only notify if the count is different from the last notification
      if (_lastNotifiedCount != newCount) {
        _lastNotifiedCount = newCount;
        _unreadCountController.add(newCount);
        debugPrint('🔔 MessageEventBus: Unread count changed to $newCount');
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

  // Cleanup method
  void dispose() {
    _unreadCountController.close();
    _conversationUpdateController.close();
  }
}
