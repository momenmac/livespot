import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:developer' as developer;
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'dart:async';

class ApiClient {
  // Base URL for API requests
  static String baseUrl = ApiUrls.baseUrl;

  // Add request timeout configuration
  static const Duration requestTimeout = Duration(seconds: 15);

  // Helper for GET requests
  static Future<Map<String, dynamic>> get(String endpoint,
      {String? token, Map<String, String>? headers}) async {
    try {
      developer.log('GET request to: $baseUrl$endpoint', name: 'ApiClient');

      // Add timestamp to prevent caching
      String finalEndpoint = endpoint;
      if (!finalEndpoint.contains('?')) {
        finalEndpoint =
            '$finalEndpoint?_t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        finalEndpoint =
            '$finalEndpoint&_t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Prepare headers
      final requestHeaders = headers ?? {};
      requestHeaders['Content-Type'] = 'application/json';

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // Make request with timeout
      final response = await http
          .get(Uri.parse('$baseUrl$finalEndpoint'), headers: requestHeaders)
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      // Log and handle timeout separately for better diagnostics
      if (e is TimeoutException) {
        developer.log('GET request timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Request timed out'};
      }

      developer.log('GET request error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for POST requests
  static Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body,
      String? token,
      Map<String, String>? headers}) async {
    try {
      developer.log('POST request to: $baseUrl$endpoint, body: $body',
          name: 'ApiClient');

      // Add timestamp to prevent caching
      String finalEndpoint = endpoint;
      if (!finalEndpoint.contains('?')) {
        finalEndpoint =
            '$finalEndpoint?_t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        finalEndpoint =
            '$finalEndpoint&_t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Prepare headers
      final requestHeaders = headers ?? {};
      requestHeaders['Content-Type'] = 'application/json';

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // Make request with timeout
      final response = await http
          .post(
            Uri.parse('$baseUrl$finalEndpoint'),
            body: body != null ? jsonEncode(body) : null,
            headers: requestHeaders,
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      // Log and handle timeout separately
      if (e is TimeoutException) {
        developer.log('POST request timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Request timed out'};
      }

      developer.log('POST request error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for PUT requests
  static Future<Map<String, dynamic>> put(String endpoint,
      {Map<String, dynamic>? body,
      String? token,
      Map<String, String>? headers}) async {
    try {
      developer.log('PUT request to: $baseUrl$endpoint, body: $body',
          name: 'ApiClient');

      // Add timestamp to prevent caching
      String finalEndpoint = endpoint;
      if (!finalEndpoint.contains('?')) {
        finalEndpoint =
            '$finalEndpoint?_t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        finalEndpoint =
            '$finalEndpoint&_t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Prepare headers
      final requestHeaders = headers ?? {};
      requestHeaders['Content-Type'] = 'application/json';

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // Make request with timeout
      final response = await http
          .put(
            Uri.parse('$baseUrl$finalEndpoint'),
            body: body != null ? jsonEncode(body) : null,
            headers: requestHeaders,
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        developer.log('PUT request timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Request timed out'};
      }

      developer.log('PUT request error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for DELETE requests
  static Future<Map<String, dynamic>> delete(String endpoint,
      {String? token, Map<String, String>? headers}) async {
    try {
      developer.log('DELETE request to: $baseUrl$endpoint', name: 'ApiClient');

      // Add timestamp to prevent caching
      String finalEndpoint = endpoint;
      if (!finalEndpoint.contains('?')) {
        finalEndpoint =
            '$finalEndpoint?_t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        finalEndpoint =
            '$finalEndpoint&_t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Prepare headers
      final requestHeaders = headers ?? {};
      requestHeaders['Content-Type'] = 'application/json';

      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // Make request with timeout
      final response = await http
          .delete(
            Uri.parse('$baseUrl$finalEndpoint'),
            headers: requestHeaders,
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        developer.log('DELETE request timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Request timed out'};
      }

      developer.log('DELETE request error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Upload file helper
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required String filePath,
    required String fileField,
    String? token,
    Map<String, String>? fields,
  }) async {
    try {
      developer.log('File upload to: $baseUrl$endpoint, filePath: $filePath',
          name: 'ApiClient');

      // Create multipart request
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));

      // Add file
      final file = await http.MultipartFile.fromPath(
        fileField,
        filePath,
        contentType: _getContentType(filePath),
      );
      request.files.add(file);

      // Add other fields if provided
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Add headers including token if provided
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        developer.log('File upload timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Upload timed out'};
      }

      developer.log('File upload error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Upload binary data helper (useful for in-memory image data)
  static Future<Map<String, dynamic>> uploadBytes(
    String endpoint, {
    required Uint8List bytes,
    required String fileField,
    required String fileName,
    String? contentType,
    String? token,
    Map<String, String>? fields,
  }) async {
    try {
      developer.log(
          'Binary upload to: $baseUrl$endpoint, bytes length: ${bytes.length}',
          name: 'ApiClient');

      // Create multipart request
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));

      // Add file
      final multipartFile = http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: fileName,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      );
      request.files.add(multipartFile);

      // Add other fields if provided
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Add headers including token if provided
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        developer.log('Binary upload timed out for: $endpoint',
            name: 'ApiClient');
        return {'success': false, 'error': 'Upload timed out'};
      }

      developer.log('Binary upload error: $e', name: 'ApiClient');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper to determine content type from file extension
  static MediaType _getContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.wordprocessingml.document');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  // Handle HTTP response and convert to standard format
  static Map<String, dynamic> _handleResponse(http.Response response) {
    developer.log(
        'Response status: ${response.statusCode}, body: ${response.body}',
        name: 'ApiClient');

    try {
      // Try to parse response as JSON
      final responseJson = json.decode(response.body);

      // Check for token validity/refresh issues
      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': responseJson['error'] ?? 'Authentication error',
          'statusCode': response.statusCode,
          'token_expired': true,
        };
      }

      // Create standardized response structure
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': responseJson,
          'statusCode': response.statusCode,
        };
      } else {
        // Handle error responses
        return {
          'success': false,
          'error': responseJson['error'] ??
              responseJson['message'] ??
              'Server error',
          'statusCode': response.statusCode,
          'data': responseJson,
        };
      }
    } catch (e) {
      // Handle non-JSON responses
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': 'Request successful',
          'statusCode': response.statusCode,
          'raw': response.body,
        };
      } else {
        return {
          'success': false,
          'error':
              'Failed to parse response (${response.statusCode}): ${response.body}',
          'statusCode': response.statusCode,
          'raw': response.body,
        };
      }
    }
  }
}
