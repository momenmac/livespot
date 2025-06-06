import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/token_manager.dart';
import 'account/api_urls.dart';

/// Service to interact with the event-related endpoints of the backend API
class EventApiService {
  static final TokenManager _tokenManager = TokenManager();

  /// Get events near a specific location
  static Future<List<Map<String, dynamic>>> getNearbyEvents({
    required double latitude,
    required double longitude,
    double radiusMeters = 200,
  }) async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final response = await http.get(
        Uri.parse(
            '${ApiUrls.baseUrl}/api/posts/nearby/?lat=$latitude&lng=$longitude&radius=$radiusMeters'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        debugPrint(
            '❌ Error getting nearby events: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Exception getting nearby events: $e');
      return [];
    }
  }

  /// Get details of a specific event
  static Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final response = await http.get(
        Uri.parse('${ApiUrls.baseUrl}/api/posts/$eventId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
        return null;
      } else {
        debugPrint(
            '❌ Error getting event details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception getting event details: $e');
      return null;
    }
  }

  /// Check if an event is still happening
  static Future<bool> checkEventStatus(String eventId) async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final response = await http.get(
        Uri.parse('${ApiUrls.baseUrl}/api/posts/$eventId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check the post status - if it's "happening" then it's still active
        return data['status'] == 'happening' || data['is_happening'] == true;
      } else {
        debugPrint(
            '❌ Error checking event status: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception checking event status: $e');
      return false;
    }
  }

  /// Vote on whether an event is still happening or has ended
  static Future<bool> voteOnEventStatus(String eventId, bool eventEnded) async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/api/posts/$eventId/vote_status/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'event_ended': eventEnded,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Event status vote successful');
        return true;
      } else {
        debugPrint(
            '❌ Error voting on event status: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception voting on event status: $e');
      return false;
    }
  }
}
