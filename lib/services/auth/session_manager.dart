import 'dart:async';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/services/auth/token_manager.dart';
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

  // Token manager instance
  final TokenManager _tokenManager = TokenManager();

  // Stream controller for session state changes
  final StreamController<SessionState> _stateController =
      StreamController<SessionState>.broadcast();
  Stream<SessionState> get onStateChanged => _stateController.stream;

  // Session data
  Account? _user;
  SessionState _state = SessionState.initializing;
  String? _error;
  bool _isInitialized = false;

  // Getters
  JwtToken? get token => _tokenManager.currentToken;
  Account? get user => _user;
  SessionState get state => _state;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated =>
      _state == SessionState.authenticated && _tokenManager.isAuthenticated;
  bool get isUserVerified => _user?.isVerified ?? false;
  bool get shouldRefreshToken => _tokenManager.needsRefresh;

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

      // Initialize the token manager
      await _tokenManager.initialize();

      final token = _tokenManager.currentToken;

      if (token == null) {
        _setState(SessionState.unauthenticated);
        _isInitialized = true;
        return;
      }

      // If we have a token but it's not authenticated, clear session
      if (!_tokenManager.isAuthenticated) {
        print('🔑 Token not authenticated, clearing session');
        await clearSession();
        _isInitialized = true;
        return;
      }

      // Try to fetch user profile with the token
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        print('🔑 Failed to get valid access token, clearing session');
        await clearSession();
        _isInitialized = true;
        return;
      }

      final userProfile = await _fetchUserProfile(accessToken);
      if (userProfile == null) {
        print('🔑 Failed to fetch user profile, clearing session');
        await clearSession();
        _isInitialized = true;
        return;
      }

      // Set session state
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

  // Set the session state and notify listeners
  void _setState(SessionState newState, {String? errorMessage}) {
    _state = newState;
    _error = errorMessage;
    _stateController.add(newState);
  }

  // Set session with token and user
  void setSession({required JwtToken token, required Account user}) {
    _tokenManager.setToken(token);
    _user = user;
    _setState(SessionState.authenticated);
  }

  // Set user data
  void setUser(Account user) {
    _user = user;
    if (_state != SessionState.authenticated && _tokenManager.isAuthenticated) {
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
    await _tokenManager.clearTokens();
    _user = null;
    developer.log('Internal _user set to null and tokens cleared.',
        name: 'LogoutTrace');

    developer.log('--- Clear Session End (SessionManager) ---',
        name: 'LogoutTrace');
  }

  // Record user activity
  Future<void> recordActivity() async {
    if (_tokenManager.isAuthenticated) {
      await SharedPrefs.setLastActivity();
    }
  }

  // Verify and refresh token if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    if (!_tokenManager.isAuthenticated) {
      return false;
    }

    // TokenManager handles all validation and refresh logic
    final accessToken = await _tokenManager.getValidAccessToken();
    return accessToken != null;
  }

  // Fetch user profile
  Future<Account?> _fetchUserProfile(String accessToken) async {
    try {
      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          Uri.parse('${ApiUrls.baseUrl}/api/accounts/profile/?_t=$timestamp');

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

          // Validate that the data has required fields for Account parsing
          final profileData = responseJson['data'];
          if (profileData is Map<String, dynamic>) {
            // Check if this is account data or profile data with nested account
            if (profileData.containsKey('account')) {
              // This is profile data, extract account from it
              return Account.fromJson(profileData['account']);
            } else if (profileData.containsKey('id') ||
                profileData.containsKey('email')) {
              // This is direct account data
              return Account.fromJson(profileData);
            } else {
              developer.log('Profile data structure unrecognized: $profileData',
                  name: 'SessionManager');
              return null;
            }
          } else {
            developer.log('Profile data is not a Map: $profileData',
                name: 'SessionManager');
            return null;
          }
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
