import 'dart:async';
import 'dart:convert';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

/// Centralized token manager to handle all JWT token operations
/// This eliminates the inconsistencies across AuthService, AccountProvider, and SessionManager
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  // Current token state
  JwtToken? _currentToken;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  /// Get current token
  JwtToken? get currentToken => _currentToken;

  /// Check if user is authenticated (has valid refresh token)
  bool get isAuthenticated =>
      _currentToken != null && !_currentToken!.isRefreshTokenExpired;

  /// Check if access token needs refresh
  bool get needsRefresh =>
      _currentToken != null &&
      _currentToken!.isAccessTokenExpired &&
      !_currentToken!.isRefreshTokenExpired;

  /// Initialize token manager - call this once at app startup
  Future<void> initialize() async {
    developer.log('🔑 TokenManager: Initializing...', name: 'TokenManager');

    try {
      final token = await SharedPrefs.getJwtToken();
      if (token != null) {
        _currentToken = token;
        developer.log('🔑 TokenManager: Loaded token from storage',
            name: 'TokenManager');

        // Validate token state
        await _ensureTokenIsValid();
      } else {
        developer.log('🔑 TokenManager: No token found in storage',
            name: 'TokenManager');
      }
    } catch (e) {
      developer.log('🔑 TokenManager: Error during initialization: $e',
          name: 'TokenManager');
      await clearTokens();
    }
  }

  /// Get a valid access token - handles refresh automatically
  Future<String?> getValidAccessToken() async {
    if (_currentToken == null) {
      developer.log('🔑 TokenManager: No token available',
          name: 'TokenManager');
      return null;
    }

    // If refresh token is expired, user needs to login again
    if (_currentToken!.isRefreshTokenExpired) {
      developer.log('🔑 TokenManager: Refresh token expired',
          name: 'TokenManager');
      await clearTokens();
      return null;
    }

    // If access token is not expired, return it
    if (!_currentToken!.isAccessTokenExpired) {
      return _currentToken!.accessToken;
    }

    // Access token is expired, refresh it
    developer.log('🔑 TokenManager: Access token expired, refreshing...',
        name: 'TokenManager');
    final refreshed = await _refreshToken();

    if (refreshed && _currentToken != null) {
      return _currentToken!.accessToken;
    }

    developer.log('🔑 TokenManager: Failed to refresh token',
        name: 'TokenManager');
    await clearTokens();
    return null;
  }

  /// Set new token (after login/register)
  Future<void> setToken(JwtToken token) async {
    developer.log('🔑 TokenManager: Setting new token', name: 'TokenManager');
    _currentToken = token;
    await SharedPrefs.saveJwtToken(token);
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    developer.log('🔑 TokenManager: Clearing tokens', name: 'TokenManager');
    _currentToken = null;
    _isRefreshing = false;
    _refreshCompleter = null;
    await SharedPrefs.clearJwtToken();
  }

  /// Check if token needs server validation and validate if needed
  Future<bool> validateTokenIfNeeded() async {
    if (_currentToken == null) return false;

    // Only validate with server if we haven't validated recently
    if (!_currentToken!.needsServerValidation) {
      return true;
    }

    developer.log('🔑 TokenManager: Validating token with server',
        name: 'TokenManager');

    try {
      final response = await http.post(
        Uri.parse(ApiUrls.tokenValidate),
        headers: {
          'Authorization': 'Bearer ${_currentToken!.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Mark token as validated
        _currentToken!.markAsValidated();
        await SharedPrefs.saveJwtToken(_currentToken!);

        // Parse response to get expiration info
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['needs_refresh_soon'] == true) {
            developer.log('🔑 TokenManager: Server suggests token refresh soon',
                name: 'TokenManager');
            // Proactively refresh the token
            await _refreshToken();
          }
        } catch (e) {
          developer.log(
              '🔑 TokenManager: Error parsing validation response: $e',
              name: 'TokenManager');
        }

        return true;
      } else if (response.statusCode == 401) {
        developer.log(
            '🔑 TokenManager: Token validation failed (401), refreshing...',
            name: 'TokenManager');
        return await _refreshToken();
      } else {
        developer.log(
            '🔑 TokenManager: Token validation failed (${response.statusCode})',
            name: 'TokenManager');
        return false;
      }
    } catch (e) {
      developer.log('🔑 TokenManager: Error validating token: $e',
          name: 'TokenManager');

      // If it's a network error, allow the token for now
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        developer.log(
            '🔑 TokenManager: Network error, allowing token temporarily',
            name: 'TokenManager');
        return true;
      }

      return false;
    }
  }

  /// Ensure current token is valid (refresh if needed, validate if required)
  Future<bool> _ensureTokenIsValid() async {
    if (_currentToken == null) return false;

    // Check if refresh token is expired
    if (_currentToken!.isRefreshTokenExpired) {
      await clearTokens();
      return false;
    }

    // Check if access token needs refreshing
    if (_currentToken!.isAccessTokenExpired) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await clearTokens();
        return false;
      }
    }

    // Validate with server if needed
    return await validateTokenIfNeeded();
  }

  /// Refresh the access token using refresh token
  Future<bool> _refreshToken() async {
    if (_currentToken == null || _currentToken!.isRefreshTokenExpired) {
      return false;
    }

    // Prevent multiple simultaneous refresh attempts
    if (_isRefreshing) {
      developer.log(
          '🔑 TokenManager: Token refresh already in progress, waiting...',
          name: 'TokenManager');
      return await _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      developer.log('🔑 TokenManager: Starting token refresh',
          name: 'TokenManager');

      final response = await http
          .post(
            Uri.parse(ApiUrls.tokenRefresh),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'refresh': _currentToken!.refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAccessToken = responseData['access'];
        final newRefreshToken =
            responseData['refresh'] ?? _currentToken!.refreshToken;

        // Extract expiration from new access token
        final expiryTime = JwtToken.getExpirationFromToken(newAccessToken);

        // Create new token
        final newToken = JwtToken(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiration: expiryTime,
        );

        // Save new token
        _currentToken = newToken;
        await SharedPrefs.saveJwtToken(newToken);
        await SharedPrefs.setLastTokenRefresh();

        developer.log('🔑 TokenManager: Token refreshed successfully',
            name: 'TokenManager');
        _refreshCompleter!.complete(true);
        return true;
      } else {
        developer.log(
            '🔑 TokenManager: Token refresh failed (${response.statusCode}): ${response.body}',
            name: 'TokenManager');
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      developer.log('🔑 TokenManager: Token refresh error: $e',
          name: 'TokenManager');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Logout from server and clear tokens
  Future<bool> logout() async {
    if (_currentToken?.refreshToken != null) {
      try {
        developer.log('🔑 TokenManager: Logging out from server',
            name: 'TokenManager');

        final response = await http
            .post(
              Uri.parse(ApiUrls.logout),
              headers: {
                'Authorization': 'Bearer ${_currentToken!.accessToken}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'refresh': _currentToken!.refreshToken,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          developer.log('🔑 TokenManager: Server logout successful',
              name: 'TokenManager');
        } else {
          developer.log(
              '🔑 TokenManager: Server logout failed (${response.statusCode})',
              name: 'TokenManager');
        }
      } catch (e) {
        developer.log('🔑 TokenManager: Error during server logout: $e',
            name: 'TokenManager');
      }
    }

    await clearTokens();
    return true;
  }

  /// Get token info for debugging
  Map<String, dynamic> getTokenInfo() {
    if (_currentToken == null) {
      return {'hasToken': false};
    }

    return {
      'hasToken': true,
      'isAccessTokenExpired': _currentToken!.isAccessTokenExpired,
      'isRefreshTokenExpired': _currentToken!.isRefreshTokenExpired,
      'needsServerValidation': _currentToken!.needsServerValidation,
      'accessTokenExpiryDate':
          _currentToken!.accessTokenExpiryDate.toIso8601String(),
      'refreshTokenExpiryDate':
          _currentToken!.refreshTokenExpiryDate.toIso8601String(),
      'lastValidationTime':
          _currentToken!.lastValidationTime?.toIso8601String(),
    };
  }
}
