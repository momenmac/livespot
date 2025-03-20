import 'dart:async';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Session states
enum SessionState {
  initializing,
  authenticated,
  unauthenticated,
  expired,
  refreshing,
  error
}

class SessionManager {
  // Singleton pattern
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;

  // Private constructor that initializes the session
  SessionManager._internal() {
    _initializeSession();
  }

  // State variables
  SessionState _state = SessionState.initializing;
  JwtToken? _token;
  Account? _user;
  String? _error;
  Timer? _refreshTimer;
  bool _isInitializing = false;

  // Event controller for session state changes
  final _stateController = StreamController<SessionState>.broadcast();
  Stream<SessionState> get onStateChanged => _stateController.stream;

  // Getters
  SessionState get state => _state;
  JwtToken? get token => _token;
  Account? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _token != null && !_token!.isRefreshTokenExpired;
  bool get isInitialized =>
      _state != SessionState.initializing && !_isInitializing;
  bool get isUserVerified => _user?.isVerified ?? false;

  bool get shouldRefreshToken {
    if (_token == null) return false;
    final fiveMinutesFromNow = DateTime.now().add(Duration(minutes: 5));
    return _token!.accessTokenExpiry.isBefore(fiveMinutesFromNow) &&
        !_token!.isRefreshTokenExpired;
  }

  // Initialize session safely (avoiding async in constructor)
  void _initializeSession() {
    if (_isInitializing) return;
    _isInitializing = true;

    Future.microtask(() async {
      try {
        await _initSession();
      } finally {
        _isInitializing = false;
      }
    });
  }

  // Initialize session from shared preferences
  Future<void> _initSession() async {
    _setState(SessionState.initializing);

    try {
      // Remove legacy tokens if they exist
      await SharedPrefs.removeLegacyToken();

      // Get token from SharedPreferences
      _token = await SharedPrefs.getJwtToken();

      if (_token != null) {
        print('🔑 Found existing JWT token, checking validity...');

        // Check if tokens are still valid
        if (_token!.isRefreshTokenExpired) {
          print('🔑 Refresh token is expired');
          await _clearSession();
          _setState(SessionState.expired);
          return;
        } else if (_token!.isAccessTokenExpired) {
          print('🔑 Access token is expired, attempting to refresh...');

          // Check if Remember Me was enabled
          final rememberMe = await SharedPrefs.getRememberMe();

          if (rememberMe) {
            // Try to refresh the token if Remember Me was enabled
            final refreshed = await _refreshToken();
            if (!refreshed) {
              print('🔑 Token refresh failed');
              await _clearSession();
              _setState(SessionState.expired);
              return;
            }
          } else {
            // Don't auto-refresh if Remember Me wasn't enabled
            print('🔑 Access token expired and Remember Me not enabled');
            await _clearSession();
            _setState(SessionState.expired);
            return;
          }
        }

        // Check for session timeout
        if (await SharedPrefs.isSessionTimedOut()) {
          print('🔑 Session timeout - User didn\'t select "Remember Me"');
          await _clearSession();
          _setState(SessionState.expired);
          return;
        }

        // Update last activity time
        await SharedPrefs.setLastActivity();

        _setState(SessionState.authenticated);
      } else {
        _setState(SessionState.unauthenticated);
      }
    } catch (e) {
      print('🔑 Error during session initialization: ${e.toString()}');
      _error = 'Failed to initialize session: ${e.toString()}';
      _setState(SessionState.error);
    }
  }

  // Set state and notify listeners
  void _setState(SessionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  // Clean up the session
  Future<void> _clearSession() async {
    await SharedPrefs.clearSession();
    _token = null;
    _user = null;
    _refreshTimer?.cancel();
  }

  // Refresh token
  Future<bool> _refreshToken() async {
    if (_token == null || _token!.isRefreshTokenExpired) {
      return false;
    }

    _setState(SessionState.refreshing);

    try {
      final response = await http.post(
        Uri.parse(ApiUrls.tokenRefresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _token!.refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update only the access token, keeping the same refresh token
        _token = JwtToken(
          accessToken: data['access'],
          refreshToken: _token!.refreshToken,
          accessTokenExpiry: JwtToken.getExpiryFromToken(data['access']),
          refreshTokenExpiry: _token!.refreshTokenExpiry,
        );

        // Save updated token to SharedPreferences
        await SharedPrefs.saveJwtToken(_token!);

        _setState(SessionState.authenticated);
        return true;
      } else {
        print('🔄 Token refresh failed: ${response.body}');
        _setState(SessionState.error);
        return false;
      }
    } catch (e) {
      print('🔄 Token refresh error: $e');
      _setState(SessionState.error);
      return false;
    }
  }

  // Verify and refresh token if needed (public)
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    if (_token == null) return false;

    try {
      if (_token!.isRefreshTokenExpired) {
        print('🔑 Refresh token expired, logging out');
        _setState(SessionState.expired);
        return false;
      }

      if (_token!.isAccessTokenExpired || shouldRefreshToken) {
        print('🔑 Access token expired or will expire soon, refreshing');
        return await _refreshToken();
      }

      return true;
    } catch (e) {
      print('❌ Token verification error: ${e.toString()}');
      try {
        return await _refreshToken();
      } catch (_) {
        _setState(SessionState.expired);
        return false;
      }
    }
  }

  // Record user activity
  Future<void> recordActivity() async {
    if (!isAuthenticated) return;

    await SharedPrefs.setLastActivity();

    // Refresh token if needed
    if (_token?.isAccessTokenExpired == true || shouldRefreshToken) {
      final rememberMe = await SharedPrefs.getRememberMe();
      if (rememberMe) {
        await _refreshToken();
      }
    }
  }

  // Set the user and token (used by AccountProvider)
  void setSession({JwtToken? token, Account? user}) {
    _token = token;
    _user = user;

    if (token != null && user != null) {
      _setState(SessionState.authenticated);
    } else if (token == null && user == null) {
      _setState(SessionState.unauthenticated);
    }
  }

  // Add a method to update just the user object
  void setUser(Account user) {
    _user = user;
    // If we're setting a user object, we must already be authenticated
    if (_state != SessionState.authenticated && _token != null) {
      _setState(SessionState.authenticated);
    }
  }

  // Clear the session (used for logout)
  Future<void> clearSession() async {
    await _clearSession();
    _setState(SessionState.unauthenticated);
  }

  // Dispose
  void dispose() {
    _refreshTimer?.cancel();
    _stateController.close();
  }
}
