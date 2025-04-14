import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/models/account.dart';

class ApiClient {
  // Default timeout for API requests
  static const Duration _defaultTimeout = Duration(seconds: 15);

  // GET request with authorization
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final url = Uri.parse('${ApiUrls.baseUrl}$endpoint');
      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(timeout);

      return _processResponse(response);
    } catch (e) {
      print('❌ API GET error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // POST request with optional authorization
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final url = Uri.parse('${ApiUrls.baseUrl}$endpoint');
      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _processResponse(response);
    } catch (e) {
      print('❌ API POST error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Process HTTP response
  static Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      // Token expired check
      if (response.statusCode == 401) {
        if (data is Map &&
            (data['detail']?.toString().toLowerCase().contains('expired') ??
                false)) {
          return {'success': false, 'token_expired': true};
        }
      }

      // Success check
      final success = response.statusCode >= 200 && response.statusCode < 300;

      if (success) {
        if (data is Map) {
          return {'success': true, ...data};
        } else {
          return {'success': true, 'data': data};
        }
      } else {
        final errorMessage = data is Map
            ? data['detail'] ?? data['error'] ?? 'Unknown error'
            : 'Unknown error';

        return {
          'success': false,
          'error': errorMessage,
          'status': response.statusCode
        };
      }
    } catch (e) {
      print('❌ Response processing error: $e');
      return {
        'success': false,
        'error': 'Invalid response format',
        'status': response.statusCode,
        'raw': response.body
      };
    }
  }

  // Helper method for user profile
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    final result = await get('/accounts/profile/', token: token);

    if (result['success'] && result is Map) {
      try {
        final account = Account.fromJson(result);
        return {'success': true, 'user': account};
      } catch (e) {
        print('❌ Error parsing profile: $e');
        return {'success': false, 'error': 'Failed to parse user data'};
      }
    }

    return result;
  }
}
