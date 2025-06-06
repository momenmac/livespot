import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class ApiTester {
  static Future<void> testRegisterEndpoint() async {
    const baseUrls = [
      'http://192.168.1.36:8000',
      'http://10.0.0.3:8000', //change ip when for access
      'http://localhost:8000',
      'http://127.0.0.1:8000'
    ];

    for (final baseUrl in baseUrls) {
      try {
        print('🧪 Testing API at: $baseUrl/accounts/register/');

        final response = await http
            .post(
              Uri.parse('$baseUrl/accounts/register/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': 'test@example.com',
                'password': 'Password123',
                'first_name': 'Test',
                'last_name': 'User',
              }),
            )
            .timeout(const Duration(seconds: 5));

        print('🧪 Response from $baseUrl: ${response.statusCode}');
        print('🧪 Response body: ${response.body}');
      } catch (e) {
        print('🧪 Error with $baseUrl: $e');
      }
    }
  }
}
