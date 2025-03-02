import 'package:flutter/foundation.dart';

/// Firebase configuration helper to manage different environments
class FirebaseConfig {
  // Collection names for Firestore
  static const String usersCollection = 'users';
  static const String conversationsCollection = 'conversations';
  static const String messagesSubcollection = 'messages';
  static const String statusCollection = 'status';

  // Storage paths for Firebase Storage
  static String voiceMessagePath(String conversationId, String messageId) =>
      'voice_messages/$conversationId/$messageId.m4a';

  static String imageMessagePath(String conversationId, String messageId) =>
      'image_messages/$conversationId/$messageId';

  // Firestore indexes needed (for documentation)
  static const List<String> requiredIndexes = [
    'conversations: participants ASC, lastMessageTimestamp DESC',
    'messages: conversationId ASC, timestamp DESC',
    'users: name_lowercase ASC, createdAt DESC',
  ];

  // Rules file locations (for documentation)
  static const String firestoreRulesPath = 'firestore.rules';
  static const String storageRulesPath = 'storage.rules';

  /// Helper method to check if all Firebase requirements are met
  static Future<bool> validateSetup() async {
    try {
      // In a real implementation, we'd check things like:
      // - Firebase app initialized properly
      // - Required collections exist
      // - Security rules are deployed
      // - Indexes are created

      // For now, just return true
      return true;
    } catch (e) {
      debugPrint('Firebase setup validation failed: $e');
      return false;
    }
  }
}
