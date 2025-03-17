import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// An HTTP client that automatically adds authentication tokens to requests
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  String? _cachedToken;

  AuthenticatedClient(this._inner);

  Future<String?> get _authToken async {
    if (_cachedToken != null) return _cachedToken;

    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  // Clear cached token, used when logging out
  void clearToken() {
    _cachedToken = null;
  }

  // Set token directly, used when logging in
  void setToken(String token) {
    _cachedToken = token;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _authToken;

    if (token != null) {
      request.headers['Authorization'] = 'Token $token';
    }

    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }
}
