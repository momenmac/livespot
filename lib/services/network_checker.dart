import 'package:http/http.dart' as http;
import '../utils/api_urls.dart';
import 'dart:async';

class NetworkChecker {
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiUrls.baseUrl),
          )
          .timeout(const Duration(seconds: 5));

      print('🌐 Server check response: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      print('🌐 Server check error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> debugNetworkInfo() async {
    final Map<String, dynamic> info = {};

    try {
      info['serverReachable'] = await isServerReachable();
      info['baseUrl'] = ApiUrls.baseUrl;

      // Try additional endpoints
      try {
        final registerResponse = await http
            .head(
              Uri.parse(ApiUrls.register),
            )
            .timeout(const Duration(seconds: 3));
        info['registerEndpoint'] = {
          'status': registerResponse.statusCode,
          'available': registerResponse.statusCode != 404
        };
      } catch (e) {
        info['registerEndpoint'] = {'error': e.toString()};
      }
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }
}
