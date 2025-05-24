import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_application_2/services/auth/token_manager.dart';

// An HTTP client that automatically adds authentication tokens to requests using TokenManager
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final TokenManager _tokenManager = TokenManager();

  AuthenticatedClient(this._inner);

  Future<String?> get _authToken async {
    // Use TokenManager to get a valid access token
    return await _tokenManager.getValidAccessToken();
  }

  // Clear cached token, used when logging out - delegate to TokenManager
  void clearToken() {
    // TokenManager handles token clearing internally
    _tokenManager.clearTokens();
  }

  // Set token directly, used when logging in - delegate to TokenManager
  void setToken(String token) {
    // TokenManager handles token setting through its setToken method
    // This method is kept for compatibility but tokens should be set through TokenManager directly
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _authToken;

    if (token != null) {
      request.headers['Authorization'] =
          'Bearer $token'; // Use Bearer instead of Token
    }

    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }
}
