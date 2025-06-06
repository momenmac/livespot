import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/token_manager.dart';
import 'account/api_urls.dart';

/// Service for handling notification API requests to Django backend
class NotificationApiService {
  static String get _baseUrl => '${ApiUrls.baseUrl}/api/notifications';

  // For production, this would be your actual server URL
  // static const String _baseUrl = 'https://your-app.com/api/notifications';

  /// Get authorization headers with Django JWT token
  static Future<Map<String, String>> _getHeaders() async {
    final tokenManager = TokenManager();
    final accessToken = await tokenManager.getValidAccessToken();

    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
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
        Uri.parse(ApiUrls.registerFcmToken),
        headers: headers,
        body: jsonEncode({
          'token': token,
          'platform': platform,
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

  /// Deactivate an FCM token
  static Future<bool> deactivateToken(String token) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiUrls.deactivateFcmToken),
        headers: headers,
        body: jsonEncode({
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token deactivated successfully');
        return true;
      } else {
        debugPrint('❌ Failed to deactivate FCM token: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deactivating FCM token: $e');
      return false;
    }
  }

  /// Get user's notification settings
  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      // Check if user is authenticated using TokenManager
      final tokenManager = TokenManager();
      if (!tokenManager.isAuthenticated) {
        debugPrint('⚠️ User not authenticated, returning default settings');
        return _getDefaultSettings();
      }

      // Try to get settings from server
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiUrls.notificationSettings),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Notification settings retrieved from server');
        return data.isNotEmpty ? data[0] : null; // ViewSet returns a list
      } else {
        debugPrint(
            '❌ Failed to get notification settings from server: ${response.statusCode}');

        // Return default settings as fallback since we're using Django backend now
        debugPrint('📱 Using default notification settings');
        return _getDefaultSettings();
      }
    } catch (e) {
      debugPrint('❌ Error getting notification settings: $e');

      // Return default settings when any error occurs
      return _getDefaultSettings();
    }
  }

  /// Get default notification settings
  static Map<String, dynamic> _getDefaultSettings() {
    debugPrint('📱 Using default notification settings');
    return {
      'friend_requests': true,
      'events': true,
      'reminders': true,
      'nearby_events': true,
      'system_notifications': true,
      'follow_notifications': true,
      'still_happening_notifications': true,
    };
  }

  /// Update user's notification settings
  static Future<bool> updateNotificationSettings({
    required bool friendRequests,
    required bool events,
    required bool reminders,
    required bool nearbyEvents,
    required bool systemNotifications,
    bool? followNotifications,
    bool? stillHappeningNotifications,
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
        'follow_notifications': followNotifications ?? true,
        'still_happening_notifications': stillHappeningNotifications ?? true,
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
      final response = await http.post(
        Uri.parse('$_baseUrl/history/$notificationId/mark_read/'),
        headers: headers,
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

  /// Mark notification as unread
  static Future<bool> markNotificationAsUnread(String notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/history/$notificationId/mark_unread/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification marked as unread');
        return true;
      } else {
        debugPrint(
            '❌ Failed to mark notification as unread: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as unread: $e');
      return false;
    }
  }

  /// Delete notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/$notificationId/delete_notification/'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Notification deleted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to delete notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/history/mark_all_read/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ All notifications marked as read');
        return true;
      } else {
        debugPrint(
            '❌ Failed to mark all notifications as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
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

  /// Create an event confirmation request in the backend
  static Future<Map<String, dynamic>?> createEventConfirmation({
    required String eventId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/event-confirmations/'),
        headers: headers,
        body: jsonEncode({
          'event_id': eventId,
          'confirmation_request_sent': true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Event confirmation created successfully');
        return data;
      } else {
        debugPrint(
            '❌ Failed to create event confirmation: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating event confirmation: $e');
      return null;
    }
  }

  /// Send a "still there" confirmation notification via the API
  static Future<bool> sendStillThereConfirmation({
    required String eventId,
    required String eventTitle,
    required String eventImageUrl,
    required String confirmationId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/actions/send-still-there-confirmation/'),
        headers: headers,
        body: jsonEncode({
          'event_id': eventId,
          'event_title': eventTitle,
          'event_image_url': eventImageUrl,
          'confirmation_id': confirmationId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Still there notification sent successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to send still there notification: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending still there notification: $e');
      return false;
    }
  }

  /// Respond to a "Still happening" event confirmation
  static Future<bool> respondToStillThereConfirmation({
    required String confirmationId,
    required bool isStillThere,
    String? responseMessage,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/event-confirmations/$confirmationId/respond/'),
        headers: headers,
        body: jsonEncode({
          'is_still_there': isStillThere,
          'response_message': responseMessage ??
              (isStillThere
                  ? 'Event is still happening'
                  : 'Event is no longer happening'),
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

  /// Get unread notification count from server
  static Future<int> getUnreadNotificationCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/history/unread_count/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['unread_count'] ?? 0;
        debugPrint('✅ Unread notification count retrieved: $count');
        return count;
      } else {
        debugPrint(
            '❌ Failed to get unread notification count: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return 0;
      }
    } catch (e) {
      debugPrint('❌ Error getting unread notification count: $e');
      return 0;
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
