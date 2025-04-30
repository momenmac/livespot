import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart'; // Add this import
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
  bool _isLoading = false;

  // Debounce mechanism to prevent rapid state changes
  Timer? _debounceTimer;
  bool _notificationPending = false;
  static const _debounceTime = Duration(milliseconds: 300);

  // Flag to track if we're currently processing a navigation related state change
  bool _inAuthStateTransition = false;

  // Getters
  bool get isLoading =>
      _isLoading ||
      _sessionManager.state == SessionState.initializing ||
      _sessionManager.state == SessionState.refreshing;
  String? get error => _sessionManager.error;
  bool get isAuthenticated => _sessionManager.isAuthenticated;
  Account? get currentUser => _sessionManager.user;
  JwtToken? get token => _sessionManager.token;
  bool get isUserVerified => _sessionManager.isUserVerified;
  bool get shouldRefreshToken => _sessionManager.shouldRefreshToken;
  bool get inAuthStateTransition => _inAuthStateTransition;

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

    final currentToken = await SharedPrefs.getJwtToken();
    String? refreshToken = currentToken?.refreshToken;
    String? accessToken = currentToken?.accessToken;
    developer.log(
        'Retrieved tokens: Access=${accessToken != null}, Refresh=${refreshToken != null}',
        name: 'LogoutTrace');

    if (refreshToken != null && accessToken != null) {
      final logoutUrl = ApiUrls.logout;
      developer.log('Attempting server logout to URL: $logoutUrl',
          name: 'LogoutTrace');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final body = jsonEncode({'refresh': refreshToken});
      developer.log('Headers: $headers', name: 'LogoutTrace');
      developer.log('Body: $body', name: 'LogoutTrace');

      try {
        final response = await http
            .post(
              Uri.parse(logoutUrl),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15)); // Increased timeout slightly

        developer.log('Server response status: ${response.statusCode}',
            name: 'LogoutTrace');
        developer.log('Server response body: ${response.body}',
            name: 'LogoutTrace');

        if (response.statusCode == 200) {
          developer.log('Server logout successful.', name: 'LogoutTrace');
        } else if (response.statusCode == 401) {
          developer.log(
              'Server logout failed: 401 Unauthorized. Proceeding with local logout.',
              name: 'LogoutTrace');
        } else {
          developer.log(
              'Server logout failed with status ${response.statusCode}. Proceeding with local logout.',
              name: 'LogoutTrace');
        }
      } catch (e, stackTrace) {
        developer.log('Error during server logout HTTP request: $e',
            name: 'LogoutTrace', error: e, stackTrace: stackTrace);
        // Continue with local logout even if server communication fails
      }
    } else {
      developer.log('Missing refresh or access token. Skipping server logout.',
          name: 'LogoutTrace');
    }

    // Always clear local session regardless of server response
    developer.log('Calling _clearSession()...', name: 'LogoutTrace');
    await _clearSession();
    developer.log('_clearSession() finished.', name: 'LogoutTrace');

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

  // Clear session data
  Future<void> _clearSession() async {
    developer.log('--- Clear Session Start (AccountProvider) ---',
        name: 'LogoutTrace');
    developer.log('Calling _sessionManager.clearSession()...',
        name: 'LogoutTrace');
    await _sessionManager.clearSession(); // Clear session manager state
    developer.log('_sessionManager.clearSession() finished.',
        name: 'LogoutTrace');

    developer.log('Calling SharedPrefs.clearSession()...', name: 'LogoutTrace');
    await SharedPrefs.clearSession(); // Clear relevant shared preferences
    developer.log('SharedPrefs.clearSession() finished.', name: 'LogoutTrace');
    developer.log('--- Clear Session End (AccountProvider) ---',
        name: 'LogoutTrace');
    // No need to notify here, logout method will notify
  }

  // Record activity
  Future<void> recordActivity() async {
    await _sessionManager.recordActivity();
    _debouncedNotify();
  }

  // Verify and refresh token if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    final result = await _sessionManager.verifyAndRefreshTokenIfNeeded();
    _debouncedNotify();
    return result;
  }

  // Refresh token
  Future<bool> refreshToken() async {
    return await verifyAndRefreshTokenIfNeeded();
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

          // Save token to SharedPreferences
          await SharedPrefs.saveJwtToken(token);

          // Save last used email
          await SharedPrefs.setLastUsedEmail(email);

          // Update SessionManager
          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );
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
      final url = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer ${token!.accessToken}';

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
        if (await refreshToken()) {
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
      await verifyAndRefreshTokenIfNeeded();

      final base64Image = base64Encode(imageData);

      final response = await http.post(
        Uri.parse(ApiUrls.updateProfile),
        headers: {
          'Authorization': 'Bearer ${token!.accessToken}',
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
      if (token!.isAccessTokenExpired) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          await logout();
          return;
        }
      }

      final result = await _authService.getUserProfile(token!.accessToken);

      if (result['success']) {
        _sessionManager.setUser(result['user'] as Account);
      } else if (result['token_expired'] == true) {
        final refreshed = await refreshToken();
        if (refreshed) {
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
        // Optionally update user state here
        await _fetchUserProfile();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Verify email error: $e');
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

          await SharedPrefs.saveJwtToken(token);
          await SharedPrefs.setRememberMe(true);
          await SharedPrefs.setLastActivity();

          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );
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
}
