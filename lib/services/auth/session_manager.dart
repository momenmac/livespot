import 'dart:async';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer; // Import developer for logging

enum SessionState {
  initializing,
  authenticated,
  unauthenticated,
  refreshing,
  error,
}

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();

  // Stream controller for session state changes
  final StreamController<SessionState> _stateController =
      StreamController<SessionState>.broadcast();
  Stream<SessionState> get onStateChanged => _stateController.stream;

  // Session data
  JwtToken? _token;
  Account? _user;
  SessionState _state = SessionState.initializing;
  String? _error;
  bool _isInitialized = false;

  // Getters
  JwtToken? get token => _token;
  Account? get user => _user;
  SessionState get state => _state;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated =>
      _state == SessionState.authenticated &&
      _token != null &&
      !_token!.isRefreshTokenExpired;
  bool get isUserVerified => _user?.isVerified ?? false;
  bool get shouldRefreshToken =>
      _token != null &&
      _token!.isAccessTokenExpired &&
      !_token!.isRefreshTokenExpired;

  // Add this getter for compatibility with route_guard.dart
  bool get isEmailVerified => _user?.isEmailVerified ?? false;

  // Factory constructor to return the singleton instance
  factory SessionManager() {
    return _instance;
  }

  // Private constructor
  SessionManager._internal() {
    _initializeSession();
  }

  // Initialize the session
  Future<void> _initializeSession() async {
    try {
      _setState(SessionState.initializing);
      final token = await SharedPrefs.getJwtToken();

      if (token == null) {
        _setState(SessionState.unauthenticated);
        _isInitialized = true;
        return;
      }

      // Here's the key change: validate the token with the server if needed
      if (token.needsServerValidation) {
        print('🔑 Found existing JWT token, validating with server...');
        final isValid = await _validateTokenWithServer(token);

        if (!isValid) {
          print('🔑 Token validation failed, clearing session');
          await clearSession();
          _isInitialized = true;
          return;
        }

        // Mark token as validated after successful server validation
        token.markAsValidated();
        await SharedPrefs.saveJwtToken(token);
        print('🔑 Token validated successfully with server');
      } else if (token.isRefreshTokenExpired) {
        print('🔑 Refresh token is expired');
        await clearSession();
        _isInitialized = true;
        return;
      } else if (token.isAccessTokenExpired) {
        // Try to refresh the token
        print('🔑 Access token is expired, refreshing...');
        final refreshed = await refreshToken(token);
        if (!refreshed) {
          print('🔑 Token refresh failed, clearing session');
          await clearSession();
          _isInitialized = true;
          return;
        }
      }

      // Try to fetch user profile with the token
      final userProfile = await _fetchUserProfile(token.accessToken);
      if (userProfile == null) {
        print('🔑 Failed to fetch user profile, clearing session');
        await clearSession();
        _isInitialized = true;
        return;
      }

      // Set session state
      _token = token;
      _user = userProfile;
      _setState(SessionState.authenticated);
      _isInitialized = true;

      print('🔑 Session initialized with authenticated user: ${_user?.email}');
    } catch (e) {
      print('🔑 Error initializing session: $e');
      _setState(SessionState.error, errorMessage: e.toString());
      _isInitialized = true;
      await clearSession();
    }
  }

  // Method to try to load session from SharedPreferences
  Future<void> _loadSessionFromSharedPrefs() async {
    try {
      final token = await SharedPrefs.getJwtToken();
      if (token != null) {
        // Check if the token is still valid
        if (token.isAccessTokenExpired) {
          // Try to refresh the token
          final result = await refreshToken(token);
          if (!result) {
            // If refresh failed, clear session
            await clearSession();
            return;
          }
        } else {
          _token = token;
        }

        // We don't have a SharedPrefs.getUser() method, so we'll fetch from server instead
        await _fetchUserFromServer(token);

        // Now that we have the account, update the state
        _setState(SessionState.authenticated);
      } else {
        // No token found, session is unauthenticated
        _setState(SessionState.unauthenticated);
      }
    } catch (e, stackTrace) {
      developer.log('Error loading session: $e',
          name: 'SessionManager', error: e, stackTrace: stackTrace);
      _setState(SessionState.unauthenticated, errorMessage: e.toString());
    }
  }

  // Helper method to fetch user from server using token
  Future<void> _fetchUserFromServer(JwtToken token) async {
    try {
      final userProfile = await _fetchUserProfile(token.accessToken);
      if (userProfile != null) {
        _user = userProfile;
        // We don't have a SharedPrefs.saveUser method, so we'll just update in-memory
        // No need to save to shared prefs since we can fetch again when needed
      }
    } catch (e) {
      developer.log('Error fetching user from server: $e',
          name: 'SessionManager');
    }
  }

  // Set the session state and notify listeners
  void _setState(SessionState newState, {String? errorMessage}) {
    _state = newState;
    _error = errorMessage;
    _stateController.add(newState);
  }

  // Set session with token and user
  void setSession({required JwtToken token, required Account user}) {
    _token = token;
    _user = user;
    _setState(SessionState.authenticated);
  }

  // Set user data
  void setUser(Account user) {
    _user = user;
    if (_state != SessionState.authenticated && _token != null) {
      _setState(SessionState.authenticated);
    }
    _stateController.add(_state); // Notify of user data change
  }

  // Clear the session
  Future<void> clearSession() async {
    developer.log('--- Clear Session Start (SessionManager) ---',
        name: 'LogoutTrace');

    // Notify listeners before changing state to prevent race conditions
    _setState(SessionState.unauthenticated);
    developer.log('State set to unauthenticated.', name: 'LogoutTrace');

    // Clear everything cleanly
    _token = null;
    _user = null;
    developer.log('Internal _token and _user set to null.',
        name: 'LogoutTrace');

    // Ensure we clean up any cached data
    try {
      await SharedPrefs.clearJwtToken();
      developer.log('JWT tokens cleared from SharedPrefs.',
          name: 'LogoutTrace');
    } catch (e) {
      developer.log('Error clearing JWT tokens: $e', name: 'LogoutTrace');
    }

    developer.log('--- Clear Session End (SessionManager) ---',
        name: 'LogoutTrace');
  }

  // Record user activity
  Future<void> recordActivity() async {
    if (_token != null) {
      await SharedPrefs.setLastActivity();
    }
  }

  // Verify and refresh token if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    if (_token == null) {
      return false;
    }

    // First check if token has expired
    if (_token!.isRefreshTokenExpired) {
      print('Refresh token expired, logging out');
      await clearSession();
      return false;
    }

    // Check if access token needs refreshing
    if (_token!.isAccessTokenExpired) {
      return await refreshToken(_token!);
    }

    // If token needs server validation
    if (_token!.needsServerValidation) {
      final isValid = await _validateTokenWithServer(_token!);
      if (!isValid) {
        await clearSession();
        return false;
      }
      _token!.markAsValidated();
      await SharedPrefs.saveJwtToken(_token!);
    }

    return true;
  }

  // Refresh token
  Future<bool> refreshToken(JwtToken token) async {
    if (token.isRefreshTokenExpired) {
      return false;
    }

    _setState(SessionState.refreshing);
    try {
      final url = Uri.parse(ApiUrls.tokenRefresh);
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'refresh': token.refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAccessToken = responseData['access'];

        // Extract expiration from the new token
        final expiryTime = JwtToken.getExpirationFromToken(newAccessToken);

        // Create new token with all required parameters including expiration
        final newToken = JwtToken(
          accessToken: newAccessToken,
          refreshToken: responseData['refresh'] ??
              token.refreshToken, // Use new refresh token if provided
          expiration: expiryTime,
        );

        // Save the new token
        _token = newToken;
        await SharedPrefs.saveJwtToken(newToken);

        _setState(SessionState.authenticated);
        return true;
      } else {
        _setState(SessionState.error, errorMessage: 'Failed to refresh token');
        return false;
      }
    } catch (e) {
      print('Token refresh error: $e');
      _setState(SessionState.error, errorMessage: e.toString());
      return false;
    }
  }

  // Improved token validation with better error handling
  Future<bool> _validateTokenWithServer(JwtToken token) async {
    try {
      final url = Uri.parse('${ApiUrls.baseUrl}/accounts/token/validate/');
      developer.log('Validating token with server: $url',
          name: 'TokenValidation');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      developer.log('Token validation response: ${response.statusCode}',
          name: 'TokenValidation');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        // Try to refresh the token if access token is expired
        if (token.isAccessTokenExpired && !token.isRefreshTokenExpired) {
          developer.log('Attempting to refresh expired token',
              name: 'TokenValidation');
          return await refreshToken(token);
        }
        return false;
      } else {
        print('🔑 Token validation failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🔑 Error validating token with server: $e');
      // Don't assume token is valid if we can't reach the server
      // This is safer than allowing access with potentially invalid tokens
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        print('🔑 Network error during validation. Treating as offline.');
        // If offline, allow the token for now, but mark it for revalidation
        return true;
      }
      return false;
    }
  }

  // Fetch user profile
  Future<Account?> _fetchUserProfile(String accessToken) async {
    try {
      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          Uri.parse('${ApiUrls.baseUrl}/accounts/profile/?_t=$timestamp');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        if (responseJson['data'] != null) {
          developer.log('Successfully fetched user profile data',
              name: 'SessionManager');
          return Account.fromJson(responseJson['data']);
        } else {
          developer.log('Profile data missing in response: $responseJson',
              name: 'SessionManager');
          return null;
        }
      } else {
        developer.log('Failed to fetch user profile: ${response.statusCode}',
            name: 'SessionManager');
        return null;
      }
    } catch (e) {
      developer.log('Error fetching user profile: $e', name: 'SessionManager');
      return null;
    }
  }
}
