import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart'; // Import ApiUrls

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _initialCheckComplete = false;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get initialCheckComplete => _initialCheckComplete;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  // Initialize and validate existing token
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        debugPrint('🔑 Found existing JWT token, validating with server...');
        final isValid = await validateToken();
        _isAuthenticated = isValid;

        if (!isValid) {
          await clearSession();
        }
      }
    } catch (e) {
      debugPrint('Error during auth initialization: $e');
      await clearSession();
    } finally {
      _isLoading = false;
      _initialCheckComplete = true;
      notifyListeners();
    }
  }

  // Validate token with server
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiUrls.tokenValidate),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
          '[TokenValidation] Token validation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Token is valid
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('[TokenValidation] Attempting to refresh expired token');
        return await refreshToken();
      } else {
        debugPrint('🔑 Token validation failed, clearing session');
        return false;
      }
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }

  // Refresh token
  Future<bool> refreshToken() async {
    if (_token == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiUrls.tokenRefresh),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh': _token}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access']; // Using the access token from response

        // Save new token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        await clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
      await clearSession();
      return false;
    }
  }

  // Clear session data
  Future<void> clearSession() async {
    debugPrint('[LogoutTrace] --- Clear Session Start (AuthService) ---');
    _token = null;
    _user = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    debugPrint('[LogoutTrace] --- Clear Session End (AuthService) ---');
    notifyListeners();
  }

  // Google sign in method (placeholder)
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Attempting to sign in with Google');
      // Implement actual Google sign-in logic
      // This is a placeholder for your actual implementation

      // Example of a successful response handling:
      // _token = responseData['token'];
      // _user = responseData['user'];
      // _isAuthenticated = true;

      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return false;
    }
  }
}
