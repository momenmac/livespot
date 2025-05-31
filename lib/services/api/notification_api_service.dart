import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling notification API requests to Django backend
class NotificationApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api/notifications';

  // For production, this would be your actual server URL
  // static const String _baseUrl = 'https://your-app.com/api/notifications';

  /// Get authorization headers with Firebase JWT token
  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Register or update FCM token
  static Future<bool> registerFCMToken({
    required String token,
    required String platform,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/fcm-tokens/'),
        headers: headers,
        body: jsonEncode({
          'token': token,
          'device_platform': platform,
          'is_active': true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ FCM token registered successfully');
        return true;
      } else {
        debugPrint('❌ Failed to register FCM token: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      return false;
    }
  }

  /// Get user's notification settings
  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/settings/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Notification settings retrieved');
        return data.isNotEmpty ? data[0] : null; // ViewSet returns a list
      } else {
        debugPrint(
            '❌ Failed to get notification settings: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting notification settings: $e');
      return null;
    }
  }

  /// Update user's notification settings
  static Future<bool> updateNotificationSettings({
    required bool friendRequests,
    required bool events,
    required bool reminders,
    required bool nearbyEvents,
    required bool systemNotifications,
  }) async {
    try {
      final headers = await _getHeaders();

      // First, try to get existing settings to get the ID
      final existingSettings = await getNotificationSettings();

      final body = {
        'friend_requests': friendRequests,
        'events': events,
        'reminders': reminders,
        'nearby_events': nearbyEvents,
        'system_notifications': systemNotifications,
      };

      http.Response response;

      if (existingSettings != null) {
        // Update existing settings
        response = await http.put(
          Uri.parse('$_baseUrl/settings/${existingSettings['id']}/'),
          headers: headers,
          body: jsonEncode(body),
        );
      } else {
        // Create new settings
        response = await http.post(
          Uri.parse('$_baseUrl/settings/'),
          headers: headers,
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Notification settings updated successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to update notification settings: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating notification settings: $e');
      return false;
    }
  }

  /// Send friend request response
  static Future<bool> respondToFriendRequest({
    required String requestId,
    required bool accepted,
    String? message,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/friend-requests/$requestId/'),
        headers: headers,
        body: jsonEncode({
          'status': accepted ? 'accepted' : 'rejected',
          'message': message ?? '',
          'responded_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Friend request response sent successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to respond to friend request: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error responding to friend request: $e');
      return false;
    }
  }

  /// Send event confirmation response
  static Future<bool> respondToEventConfirmation({
    required String confirmationId,
    required bool isStillThere,
    String? responseMessage,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/event-confirmations/$confirmationId/'),
        headers: headers,
        body: jsonEncode({
          'is_still_there': isStillThere,
          'response_message': responseMessage ?? '',
          'response_received': true,
          'responded_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Event confirmation response sent successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to respond to event confirmation: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error responding to event confirmation: $e');
      return false;
    }
  }

  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/history/$notificationId/'),
        headers: headers,
        body: jsonEncode({
          'read': true,
          'read_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification marked as read');
        return true;
      } else {
        debugPrint(
            '❌ Failed to mark notification as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Get notification history
  static Future<List<Map<String, dynamic>>> getNotificationHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/history/?page=$page&page_size=$pageSize'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Notification history retrieved');
        return List<Map<String, dynamic>>.from(data['results'] ?? data);
      } else {
        debugPrint(
            '❌ Failed to get notification history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting notification history: $e');
      return [];
    }
  }

  /// Get pending friend requests
  static Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/friend-requests/?status=pending'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Pending friend requests retrieved');
        return List<Map<String, dynamic>>.from(data['results'] ?? data);
      } else {
        debugPrint(
            '❌ Failed to get pending friend requests: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting pending friend requests: $e');
      return [];
    }
  }

  /// Send a friend request
  static Future<bool> sendFriendRequest({
    required String toUserId,
    String? message,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/friend-requests/'),
        headers: headers,
        body: jsonEncode({
          'to_user': toUserId,
          'message': message ?? '',
          'status': 'pending',
        }),
      );

      if (response.statusCode == 201) {
        debugPrint('✅ Friend request sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send friend request: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending friend request: $e');
      return false;
    }
  }

  /// Create event confirmation request
  static Future<bool> createEventConfirmation({
    required String eventId,
    required String eventTitle,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/event-confirmations/'),
        headers: headers,
        body: jsonEncode({
          'event_id': eventId,
          'is_still_there': false, // Will be updated when user responds
          'response_received': false,
          'confirmation_request_sent': true,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint('✅ Event confirmation request created successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to create event confirmation: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error creating event confirmation: $e');
      return false;
    }
  }

  /// Test API connection
  static Future<bool> testConnection() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/settings/'),
        headers: headers,
      );

      // Any response other than connection error means API is reachable
      debugPrint('✅ API connection test: ${response.statusCode}');
      return true;
    } catch (e) {
      debugPrint('❌ API connection test failed: $e');
      return false;
    }
  }
}
