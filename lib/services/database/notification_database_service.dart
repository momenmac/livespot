import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../notifications/notification_types.dart';

/// Service for handling notification database operations with Firestore
class NotificationDatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save FCM token to user document using a collection for multiple devices
  static Future<void> saveFCMToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No authenticated user to save FCM token');
      return;
    }

    try {
      // Create a unique token ID based on the token itself (substring for shorter ID)
      final String tokenId = token.substring(0, min(token.length, 32));

      // Save token in a subcollection to support multiple devices
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(tokenId)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // For backward compatibility, also keep the old location
      await _firestore.collection('users').doc(user.uid).set({
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': defaultTargetPlatform.name,
          'lastActive': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved to Firestore for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from user document
  static Future<void> removeFCMToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No authenticated user to remove FCM token');
      return;
    }

    try {
      // Create a unique token ID based on the token itself
      final String tokenId = token.substring(0, min(token.length, 32));

      // Mark token as inactive rather than deleting it
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(tokenId)
          .update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCM token removed from Firestore for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  /// Save notification to database for history
  static Future<String?> saveNotification({
    required String userId,
    required NotificationData notificationData,
    required Map<String, dynamic> rawData,
  }) async {
    try {
      final docRef = await _firestore.collection('notifications').add({
        'userId': userId,
        'type': notificationData.type.toString().split('.').last,
        'title': notificationData.title,
        'body': notificationData.body,
        'data': rawData,
        'timestamp': Timestamp.fromDate(notificationData.timestamp),
        'read': false,
        'processed': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification saved to database with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
      return null;
    }
  }

  /// Create friend request in database
  static Future<String?> createFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String requestId,
    required String fromUserName,
    String? fromUserAvatar,
  }) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).set({
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'fromUserAvatar': fromUserAvatar ?? '',
        'toUserId': toUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'notificationSent': true,
      });

      debugPrint('✅ Friend request created in database: $requestId');
      return requestId;
    } catch (e) {
      debugPrint('❌ Error creating friend request: $e');
      return null;
    }
  }

  /// Update friend request status
  static Future<void> updateFriendRequestStatus({
    required String requestId,
    required String status, // 'accepted', 'rejected', 'cancelled'
  }) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': status,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Friend request status updated: $requestId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating friend request: $e');
    }
  }

  /// Save event confirmation response
  static Future<void> saveEventConfirmation({
    required String eventId,
    required String userId,
    required bool isStillThere,
    required String confirmationId,
  }) async {
    try {
      // Save the confirmation response
      await _firestore
          .collection('eventConfirmations')
          .doc(confirmationId)
          .set({
        'eventId': eventId,
        'userId': userId,
        'isStillThere': isStillThere,
        'timestamp': FieldValue.serverTimestamp(),
        'responseReceived': true,
      });

      // Update event document with confirmation
      await _firestore.collection('events').doc(eventId).update({
        'confirmationResponses.$userId': {
          'isStillThere': isStillThere,
          'timestamp': FieldValue.serverTimestamp(),
          'confirmationId': confirmationId,
        },
        'lastConfirmationUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '✅ Event confirmation saved: $confirmationId -> $isStillThere');
    } catch (e) {
      debugPrint('❌ Error saving event confirmation: $e');
    }
  }

  /// Get user's notification settings
  static Future<Map<String, bool>> getNotificationSettings(
      String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();

      if (data == null || data['notificationSettings'] == null) {
        // Return default settings if none exist
        return {
          'friendRequests': true,
          'events': true,
          'reminders': true,
          'nearbyEvents': true,
          'systemNotifications': true,
          'followNotifications': true,
          'stillHappeningNotifications': true,
        };
      }

      final settings = Map<String, dynamic>.from(data['notificationSettings']);
      return {
        'friendRequests': settings['friendRequests'] ?? true,
        'events': settings['events'] ?? true,
        'reminders': settings['reminders'] ?? true,
        'nearbyEvents': settings['nearbyEvents'] ?? true,
        'systemNotifications': settings['systemNotifications'] ?? true,
        'followNotifications': settings['followNotifications'] ?? true,
        'stillHappeningNotifications':
            settings['stillHappeningNotifications'] ?? true,
      };
    } catch (e) {
      debugPrint('❌ Error getting notification settings: $e');
      // Return default settings on error
      return {
        'friendRequests': true,
        'events': true,
        'reminders': true,
        'nearbyEvents': true,
        'systemNotifications': true,
        'followNotifications': true,
        'stillHappeningNotifications': true,
      };
    }
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    required String userId,
    required Map<String, bool> settings,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'notificationSettings': settings,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Notification settings updated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error updating notification settings: $e');
    }
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Get user's notification history
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Get unread notification count
  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark all notifications as read for user
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ All notifications marked as read for user: $userId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Delete old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final oldNotifications = await _firestore
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
          '✅ Cleaned up ${oldNotifications.docs.length} old notifications');
    } catch (e) {
      debugPrint('❌ Error cleaning up old notifications: $e');
    }
  }

  /// Initialize user document with default settings
  static Future<void> initializeUserDocument(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'notificationSettings': {
          'friendRequests': true,
          'events': true,
          'reminders': true,
          'nearbyEvents': true,
          'systemNotifications': true,
          'followNotifications': true,
          'stillHappeningNotifications': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User document initialized: $userId');
    } catch (e) {
      debugPrint('❌ Error initializing user document: $e');
    }
  }
}
