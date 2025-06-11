import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart'; // Add this import
import 'package:flutter_application_2/services/auth/token_manager.dart'; // Add TokenManager import
import 'package:flutter_application_2/services/firebase_messaging_service.dart'; // Add FirebaseMessagingService import
import 'package:shared_preferences/shared_preferences.dart'; // Add SharedPreferences import
import '../../../models/account.dart';
import '../../../models/jwt_token.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'dart:async'; // Add Timer import
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:developer' as developer; // Import developer for logging

class AccountProvider extends ChangeNotifier {
  final SessionManager _sessionManager = SessionManager();
  final TokenManager _tokenManager = TokenManager();
  bool _isLoading = false;

  // Debounce mechanism to prevent rapid state changes
  Timer? _debounceTimer;
  bool _notificationPending = false;
  static const _debounceTime = Duration(milliseconds: 300);

  // Flag to track if we're currently processing a navigation related state change
  bool _inAuthStateTransition = false;

  // Callback functions for clearing caches from other providers
  // These will be set by the main app to avoid circular dependencies
  Future<void> Function()? _clearUserProfileCaches;
  Future<void> Function()? _clearPostsCaches;
  Future<void> Function()? _clearLocationCaches;

  // Methods to set cache clearing callbacks
  void setClearUserProfileCachesCallback(Future<void> Function() callback) {
    _clearUserProfileCaches = callback;
  }

  void setClearPostsCachesCallback(Future<void> Function() callback) {
    _clearPostsCaches = callback;
  }

  void setClearLocationCachesCallback(Future<void> Function() callback) {
    _clearLocationCaches = callback;
  }

  // Getters
  bool get isLoading =>
      _isLoading ||
      _sessionManager.state == SessionState.initializing ||
      _sessionManager.state == SessionState.refreshing;
  String? get error => _sessionManager.error;
  bool get isAuthenticated => _sessionManager.isAuthenticated;
  Account? get currentUser => _sessionManager.user;
  JwtToken? get token => _tokenManager.currentToken;
  bool get isUserVerified => _sessionManager.isUserVerified;
  bool get shouldRefreshToken => _tokenManager.needsRefresh;
  bool get inAuthStateTransition => _inAuthStateTransition;

  // Check if current user is an admin
  bool get isAdmin => currentUser?.isAdmin ?? false;

  // Add this getter for compatibility with main.dart navigation logic
  bool get isEmailVerified {
    // Adjust the property name if your Account model uses a different field
    return currentUser?.isEmailVerified ?? false;
  }

  final AuthService _authService = AuthService();

  // Constructor that listens for session state changes
  AccountProvider() {
    _sessionManager.onStateChanged.listen((_) {
      // Use debounced notification to prevent rapid UI rebuilds
      _debouncedNotify();
    });
  }

  // Debounced version of notifyListeners to prevent notification storms
  void _debouncedNotify() {
    if (_debounceTimer?.isActive ?? false) {
      _notificationPending = true;
      return;
    }

    // First notification happens immediately
    notifyListeners();

    // Set timer for subsequent rapid notifications
    _debounceTimer = Timer(_debounceTime, () {
      if (_notificationPending) {
        _notificationPending = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Initialize provider
  Future<void> initialize() async {
    // Session initialization happens automatically in the SessionManager constructor
    _debouncedNotify();
  }

  // Method to set auth state transition flag
  void beginAuthStateTransition() {
    _inAuthStateTransition = true;
    _debouncedNotify();
  }

  // Method to clear auth state transition flag
  void endAuthStateTransition() {
    _inAuthStateTransition = false;
    _debouncedNotify();
  }

  // Method to immediately reset auth state transition
  // This is useful for cancel/back operations that need to bypass transition delays
  void resetAuthTransition() {
    _inAuthStateTransition = false;
    _isLoading = false;
    _debouncedNotify();

    developer.log('Auth transition state forcefully reset',
        name: 'AccountProvider');
  }

  // Wrapper to manage auth transitions safely
  Future<T> withAuthTransition<T>(Future<T> Function() operation) async {
    if (_inAuthStateTransition) {
      developer.log('Auth transition already in progress, operation deferred',
          name: 'AccountProvider');
      // Wait for the current transition to complete
      await Future.delayed(Duration(milliseconds: 500));
    }

    beginAuthStateTransition();
    try {
      return await operation();
    } finally {
      // Add a small delay before ending to allow UI to stabilize
      await Future.delayed(Duration(milliseconds: 300));
      endAuthStateTransition();
    }
  }

  // Login method
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    // Begin auth state transition to signal navigation system
    beginAuthStateTransition();
    _isLoading = true;
    _debouncedNotify();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        // Set token and user data
        if (result['tokens'] != null) {
          final token = JwtToken.fromJson(result['tokens']);

          // Set token in TokenManager
          await _tokenManager.setToken(token);

          // Save preferences
          if (rememberMe) {
            await SharedPrefs.saveJwtToken(token);
            await SharedPrefs.setRememberMe(true);
          } else {
            // Don't persist token, but clear any previous token from disk
            await SharedPrefs.clearJwtToken();
            await SharedPrefs.setRememberMe(false);
          }
          await SharedPrefs.setLastUsedEmail(email);
          await SharedPrefs.setLastLoginTime();
          await SharedPrefs.setLastActivity();

          // Update SessionManager - this happens regardless of remember me setting
          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );

          // Re-initialize FCM token registration after successful login
          try {
            await FirebaseMessagingService.initialize();
            developer.log('FCM token service re-initialized after login',
                name: 'AccountProvider');
          } catch (e) {
            developer.log('Error initializing FCM token service: $e',
                name: 'AccountProvider');
          }

          // Force a notification after session is set
          _debouncedNotify();

          return true;
        }
        return false;
      } else {
        return false;
      }
    } catch (e) {
      print('🔑 Login error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();

      // Add a small delay to ensure UI updates before ending transition
      await Future.delayed(const Duration(milliseconds: 300));
      endAuthStateTransition();
    }
  }

  // Logout method
  Future<void> logout() async {
    developer.log('--- Logout Start (AccountProvider) ---',
        name: 'LogoutTrace');

    // Set transition flag at the start of logout process
    beginAuthStateTransition();

    _isLoading = true;
    _debouncedNotify(); // Notify UI that loading has started

    try {
      // Deactivate FCM token before logging out
      try {
        await FirebaseMessagingService.deactivateCurrentToken();
        developer.log('FCM token deactivated', name: 'LogoutTrace');
      } catch (e) {
        developer.log('Error deactivating FCM token: $e', name: 'LogoutTrace');
      }

      // Use TokenManager's logout method which handles server logout and local cleanup
      await _tokenManager.logout();
      developer.log('TokenManager logout completed', name: 'LogoutTrace');

      // Clear session manager state
      await _sessionManager.clearSession();
      developer.log('SessionManager cleared', name: 'LogoutTrace');

      // Clear all application-level caches
      await _clearAllApplicationCaches();
      developer.log('All application caches cleared', name: 'LogoutTrace');
    } catch (e, stackTrace) {
      developer.log('Error during logout: $e',
          name: 'LogoutTrace', error: e, stackTrace: stackTrace);
    }

    _isLoading = false;
    developer.log('Local session cleared. Setting isLoading=false.',
        name: 'LogoutTrace');
    developer.log(
        'AccountProvider: State updated (isAuthenticated=false). Calling _debouncedNotify()...',
        name: 'AccountProvider');
    _debouncedNotify(); // Notify UI about state change (isLoading=false, isAuthenticated=false)

    // Ensure we reset the navigation transition at the end of logout
    // with a small delay to ensure state changes have propagated
    await Future.delayed(const Duration(milliseconds: 100));
    endAuthStateTransition();

    developer.log('AccountProvider: _debouncedNotify() called.',
        name: 'AccountProvider');
    developer.log('--- Logout End (AccountProvider) ---', name: 'LogoutTrace');
  }

  // Clear all application caches during logout
  Future<void> _clearAllApplicationCaches() async {
    developer.log('--- Clear All Application Caches Start ---',
        name: 'LogoutTrace');

    try {
      // Clear UserProfileProvider caches
      if (_clearUserProfileCaches != null) {
        developer.log('Clearing UserProfileProvider caches...',
            name: 'LogoutTrace');
        await _clearUserProfileCaches!();
        developer.log('UserProfileProvider caches cleared',
            name: 'LogoutTrace');
      }

      // Clear PostsProvider caches
      if (_clearPostsCaches != null) {
        developer.log('Clearing PostsProvider caches...', name: 'LogoutTrace');
        await _clearPostsCaches!();
        developer.log('PostsProvider caches cleared', name: 'LogoutTrace');
      }

      // Clear LocationCacheService
      if (_clearLocationCaches != null) {
        developer.log('Clearing LocationCacheService...', name: 'LogoutTrace');
        await _clearLocationCaches!();
        developer.log('LocationCacheService cleared', name: 'LogoutTrace');
      }

      // Clear additional SharedPreferences entries
      await _clearAdditionalSharedPreferences();
      developer.log('Additional SharedPreferences cleared',
          name: 'LogoutTrace');
    } catch (e, stackTrace) {
      developer.log('Error clearing application caches: $e',
          name: 'LogoutTrace', error: e, stackTrace: stackTrace);
    }

    developer.log('--- Clear All Application Caches End ---',
        name: 'LogoutTrace');
  }

  // Clear additional SharedPreferences entries during logout
  Future<void> _clearAdditionalSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Clear news search caches
      for (final key in keys) {
        if (key.contains('news_search') ||
            key.contains('recent_searches') ||
            key.contains('search_history')) {
          await prefs.remove(key);
          developer.log('Removed SharedPreferences key: $key',
              name: 'LogoutTrace');
        }
      }

      // Clear location data caches
      await prefs.remove('user_latitude');
      await prefs.remove('user_longitude');
      await prefs.remove('location_timestamp');
      developer.log('Location cache data removed from SharedPreferences',
          name: 'LogoutTrace');

      // Clear any other app-specific cache entries
      for (final key in keys) {
        if (key.startsWith('cache_') ||
            key.contains('_cache_') ||
            key.contains('cached_')) {
          await prefs.remove(key);
          developer.log('Removed cache key: $key', name: 'LogoutTrace');
        }
      }
    } catch (e) {
      developer.log('Error clearing additional SharedPreferences: $e',
          name: 'LogoutTrace', error: e);
    }
  }

  // Record activity
  Future<void> recordActivity() async {
    await _sessionManager.recordActivity();
    _debouncedNotify();
  }

  // Validate the token with the server and refresh if needed
  Future<bool> validateToken() async {
    return await _tokenManager.validateTokenIfNeeded();
  }

  // Refresh the JWT token using the refresh token
  Future<bool> refreshToken() async {
    final accessToken = await _tokenManager.getValidAccessToken();
    if (accessToken != null) {
      // Update SessionManager with the new token
      final newToken = _tokenManager.currentToken;
      if (newToken != null && currentUser != null) {
        _sessionManager.setSession(token: newToken, user: currentUser!);
        _debouncedNotify();
      }
      return true;
    }
    return false;
  }

  // Verify token and refresh if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    final accessToken = await _tokenManager.getValidAccessToken();
    return accessToken != null;
  }

  // Register a new user
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    Uint8List? profileImage,
  }) async {
    try {
      _isLoading = true;
      _debouncedNotify();

      final result = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success']) {
        // Handle JWT token response
        if (result['tokens'] != null) {
          final token = JwtToken.fromJson(result['tokens']);

          // Set token in TokenManager
          await _tokenManager.setToken(token);

          // Save token to SharedPreferences
          await SharedPrefs.saveJwtToken(token);

          // Save last used email
          await SharedPrefs.setLastUsedEmail(email);

          // Update SessionManager
          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );

          // Re-initialize FCM token registration after successful registration
          try {
            await FirebaseMessagingService.initialize();
            developer.log('FCM token service initialized after registration',
                name: 'AccountProvider');
          } catch (e) {
            developer.log('Error initializing FCM token service: $e',
                name: 'AccountProvider');
          }
        }

        // If we have profile image, upload it after registration is successful
        if (profileImage != null) {
          try {
            await _uploadProfileImage(profileImage);
          } catch (e) {
            print('⚠️ Failed to upload profile image: $e');
          }
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('⚠️ Registration error: $e');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Upload profile image
  Future<bool> _uploadProfileImage(Uint8List imageData) async {
    if (token == null) {
      return false;
    }

    try {
      // Use TokenManager to get a valid access token
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final url = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $accessToken';

      final multipartFile = http.MultipartFile.fromBytes(
        'profile_image',
        imageData,
        filename: 'profile.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchUserProfile();
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try getting a fresh token and retry
        final newAccessToken = await _tokenManager.getValidAccessToken();
        if (newAccessToken != null) {
          return await _uploadProfileImage(imageData);
        }
        return false;
      } else {
        return await _uploadProfileImageAlternative(imageData);
      }
    } catch (e) {
      return await _uploadProfileImageAlternative(imageData);
    }
  }

  // Alternative method to upload profile image
  Future<bool> _uploadProfileImageAlternative(Uint8List imageData) async {
    if (token == null) {
      return false;
    }

    try {
      // Use TokenManager to get a valid access token
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final base64Image = base64Encode(imageData);

      final response = await http.post(
        Uri.parse(ApiUrls.updateProfile),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'profile_image': base64Image,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchUserProfile();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Fetch user profile
  Future<void> _fetchUserProfile() async {
    if (token == null) return;

    try {
      // Use TokenManager to get a valid access token (handles refresh automatically)
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        await logout();
        return;
      }

      final result = await _authService.getUserProfile(accessToken);

      if (result['success']) {
        _sessionManager.setUser(result['user'] as Account);
      } else if (result['token_expired'] == true) {
        // Try refreshing token and retry
        final newAccessToken = await _tokenManager.getValidAccessToken();
        if (newAccessToken != null) {
          await _fetchUserProfile();
        } else {
          await logout();
        }
      } else {
        if (result['error']?.toString().toLowerCase().contains('auth') ??
            false) {
          await logout();
        }
      }
    } catch (e) {
      print('❌ Profile fetch error: ${e.toString()}');
    }
  }

  // Verify email with code
  Future<bool> verifyEmail(String code) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final url = Uri.parse(ApiUrls.verifyEmail);
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${token?.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code}),
      );
      print('🌐 POST request to: $url');
      print('🌐 Request body: {"code": "$code"}');
      print('🌐 Response status: ${response.statusCode}');
      print('🌐 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Email verification successful!');

        // CRITICAL FIX: Update user verification status immediately
        if (_sessionManager.user != null) {
          final updatedUser = _sessionManager.user!.copyWith(isVerified: true);
          _sessionManager.setUser(updatedUser);
          print('✅ Updated user verification status locally');
        }

        // Try to fetch fresh profile data, but don't fail verification if it doesn't work
        try {
          await _fetchUserProfile();
          print('✅ Profile fetch after verification successful');
        } catch (profileError) {
          print('⚠️ Profile fetch after verification failed: $profileError');
          print('⚠️ This is not critical - verification was still successful');
        }

        return true;
      } else {
        print(
            '❌ Email verification failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Verify email error: $e');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Resend verification code
  Future<bool> resendVerificationCode() async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final url = Uri.parse(ApiUrls
          .resendVerificationCode); // Should be /accounts/resend-verification-code/
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${token?.accessToken}',
          'Content-Type': 'application/json',
        },
      );
      print('🌐 POST request to: $url');
      print('🌐 Response status: ${response.statusCode}');
      print('🌐 Response body: ${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Resend verification code error: $e');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    _debouncedNotify();

    try {
      if (isAuthenticated &&
          currentUser != null &&
          currentUser?.googleId != null) {
        return {
          'success': true,
          'is_new_account': false,
          'account_linked': false,
          'user': currentUser,
        };
      }

      final result = await _authService.handleGoogleSignIn();

      if (result['success']) {
        if (result['tokens'] != null) {
          final token = JwtToken.fromJson(result['tokens']);

          // Set token in TokenManager
          await _tokenManager.setToken(token);

          await SharedPrefs.saveJwtToken(token);
          await SharedPrefs.setRememberMe(true);
          await SharedPrefs.setLastActivity();

          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );

          // Re-initialize FCM token registration after successful Google login
          try {
            await FirebaseMessagingService.initialize();
            developer.log('FCM token service re-initialized after Google login',
                name: 'AccountProvider');
          } catch (e) {
            developer.log('Error initializing FCM token service: $e',
                name: 'AccountProvider');
          }
        }

        return {
          'success': true,
          'is_new_account': result['is_new_account'] ?? false,
          'account_linked': result['account_linked'] ?? false,
          'user': currentUser,
        };
      } else {
        return {
          'success': false,
        };
      }
    } catch (e) {
      return {
        'success': false,
      };
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Request password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final result = await _authService.forgotPassword(email);

      if (result['success']) {
        final bool emailExists = result['exists'] ?? false;
        final bool emailSent = result['email_sent'] ?? false;

        return {
          'success': true,
          'message': result['message'],
          'email_exists': emailExists,
          'email_sent': emailSent,
        };
      } else {
        return {
          'success': false,
        };
      }
    } catch (e) {
      return {
        'success': false,
      };
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Verify reset code
  Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final result = await _authService.verifyResetCode(email, code);

      if (result['success']) {
        return {
          'success': true,
          'reset_token': result['reset_token'],
        };
      } else {
        return {
          'success': false,
        };
      }
    } catch (e) {
      return {
        'success': false,
      };
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Reset password
  Future<bool> resetPassword(String resetToken, String newPassword) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final result = await _authService.resetPassword(resetToken, newPassword);

      if (result['success']) {
        if (result['tokens'] != null) {
          final token = JwtToken.fromJson(result['tokens']);

          // Set token in TokenManager
          await _tokenManager.setToken(token);

          await SharedPrefs.saveJwtToken(token);

          await _fetchUserProfile();
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final result = await _authService.changePassword(
        token: accessToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success']) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('🔐 Change password error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Change email
  Future<bool> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final result = await _authService.changeEmail(
        token: accessToken,
        newEmail: newEmail,
        password: password,
      );

      if (result['success']) {
        // Refresh user profile to get updated email
        await _fetchUserProfile();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('📧 Change email error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Request data download
  Future<bool> requestDataDownload() async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final result = await _authService.requestDataDownload(
        token: accessToken,
      );

      if (result['success']) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('💾 Data download request error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Deactivate account
  Future<bool> deactivateAccount() async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final result = await _authService.deactivateAccount(
        token: accessToken,
      );

      if (result['success']) {
        // After successful deactivation, perform logout
        await logout();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('⏸️ Deactivate account error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }

  // Delete account
  Future<bool> deleteAccount({
    required String password,
  }) async {
    _isLoading = true;
    _debouncedNotify();

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        return false;
      }

      final result = await _authService.deleteAccount(
        token: accessToken,
        password: password,
      );

      if (result['success']) {
        // After successful deletion, perform logout and clear all data
        await logout();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('🗑️ Delete account error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      _debouncedNotify();
    }
  }
}
