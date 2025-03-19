import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import '../../../models/account.dart';
import '../../../models/jwt_token.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AccountProvider extends ChangeNotifier {
  Account? _currentUser;
  JwtToken? _token;
  bool _isLoading = false;
  String? _error;
  final AuthService _authService = AuthService();

  Account? get currentUser => _currentUser;
  JwtToken? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Check if the token should be refreshed (e.g., if it's close to expiry)
  bool get shouldRefreshToken {
    if (_token == null) return false;

    // Refresh if the access token will expire in the next 5 minutes
    final fiveMinutesFromNow = DateTime.now().add(Duration(minutes: 5));
    return _token!.accessTokenExpiry.isBefore(fiveMinutesFromNow) &&
        !_token!.isRefreshTokenExpired;
  }

  // Initialize provider - improved to honor JWT expiration time
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Remove legacy tokens if they exist
      await SharedPrefs.removeLegacyToken();

      // Get JWT token from SharedPreferences
      _token = await SharedPrefs.getJwtToken();

      if (_token != null) {
        print('💼 Found existing JWT token, checking validity...');

        // Check if tokens are still valid
        if (_token!.isRefreshTokenExpired) {
          print('💼 Refresh token is expired, logging out...');
          await logout();
          return;
        } else if (_token!.isAccessTokenExpired) {
          print('💼 Access token is expired, attempting to refresh...');

          // Check if Remember Me was enabled
          final rememberMe = await SharedPrefs.getRememberMe();

          if (rememberMe) {
            // With Remember Me, we try to refresh the token
            final refreshed = await refreshToken();
            if (!refreshed) {
              print('💼 Token refresh failed, logging out...');
              await logout();
              return;
            }
          } else {
            // Without Remember Me, we don't automatically refresh expired tokens
            print(
                '💼 Access token expired and Remember Me not enabled, logging out...');
            await logout();
            return;
          }
        }

        // Check for session timeout
        if (await SharedPrefs.isSessionTimedOut()) {
          print(
              '💼 Session timeout (24 hours) - User did not select "Remember Me"');
          await logout();
          return;
        }

        // Update last activity time
        await SharedPrefs.setLastActivity();

        print('💼 Token is valid, fetching user profile...');
        await _fetchUserProfile();
      }
    } catch (e) {
      print('💼 Error during initialization: ${e.toString()}');
      _error = 'Failed to initialize: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh JWT token - now stores token in SharedPreferences
  Future<bool> refreshToken() async {
    if (_token == null || _token!.isRefreshTokenExpired) {
      return false;
    }

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

        print('🔄 Token refreshed successfully');
        return true;
      } else {
        print('🔄 Token refresh failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('🔄 Token refresh error: $e');
      return false;
    }
  }

  // Verify token and refresh if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    if (_token == null) return false;

    try {
      if (_token!.isRefreshTokenExpired) {
        print('🔑 Refresh token expired, logging out');
        await logout();
        return false;
      }

      if (_token!.isAccessTokenExpired || shouldRefreshToken) {
        print('🔑 Access token expired or will expire soon, refreshing');
        return await refreshToken();
      }

      return true;
    } catch (e) {
      print('❌ Token verification error: ${e.toString()}');
      // If we encounter an error during verification, try to refresh once
      try {
        return await refreshToken();
      } catch (_) {
        await logout();
        return false;
      }
    }
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
      _error = null;
      notifyListeners();

      // Debug info
      print('🔑 Register with image: ${profileImage != null}');
      if (profileImage != null) {
        print('🔑 Image size: ${profileImage.length} bytes');
      }

      final result = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success']) {
        // Handle JWT token response
        if (result['tokens'] != null) {
          _token = JwtToken.fromJson(result['tokens']);

          // Save token to SharedPreferences
          await SharedPrefs.saveJwtToken(_token!);

          // Save last used email
          await SharedPrefs.setLastUsedEmail(email);
        }

        // If user object is included in the response, use it
        if (result['user'] != null) {
          _currentUser = result['user'];
        }

        // If we have profile image, upload it after registration is successful
        if (profileImage != null) {
          try {
            print('📤 Uploading profile image...');
            await _uploadProfileImage(profileImage);
          } catch (e) {
            print('⚠️ Failed to upload profile image: $e');
            // We'll continue anyway since the user registration was successful
          }
        }

        // Fetch user profile if needed
        if (_currentUser == null) {
          await _fetchUserProfile();
        }

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      print('⚠️ Registration error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload profile image - remove CSRF handling
  Future<bool> _uploadProfileImage(Uint8List imageData) async {
    if (_token == null) {
      return false;
    }

    try {
      // Create multipart request for profile image upload
      final url = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', url);

      // Add the authorization header with JWT
      request.headers['Authorization'] = 'Bearer ${_token!.accessToken}';

      // Add the image file
      final multipartFile = http.MultipartFile.fromBytes(
        'profile_image',
        imageData,
        filename: 'profile.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      print('📤 Sending profile image upload request to ${url.toString()}');
      print('📤 Headers: ${request.headers}');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Handle response
      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh user profile to get updated image URL
        await _fetchUserProfile();
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('⚠️ Authentication error. Token might be invalid or expired.');
        // Try to refresh token and retry
        if (await refreshToken()) {
          return await _uploadProfileImage(imageData);
        }
        return false;
      } else {
        print('⚠️ Failed to upload image: ${response.body}');
        // Fall back to alternative method if needed
        return await _uploadProfileImageAlternative(imageData);
      }
    } catch (e) {
      print('⚠️ Image upload error: $e');
      // Try alternative method if there was an error
      print('🔄 Error occurred, attempting alternative upload method...');
      return await _uploadProfileImageAlternative(imageData);
    }
  }

  // Alternative method to upload profile image - simplified to only handle JWT authentication
  Future<bool> _uploadProfileImageAlternative(Uint8List imageData) async {
    if (_token == null) {
      return false;
    }

    try {
      // Ensure token is valid
      await verifyAndRefreshTokenIfNeeded();

      // Use JSON API instead with base64 encoded image
      final base64Image = base64Encode(imageData);

      final response = await http.post(
        Uri.parse(ApiUrls.updateProfile),
        headers: {
          'Authorization': 'Bearer ${_token!.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'profile_image': base64Image,
        }),
      );

      print('📥 Alternative upload response status: ${response.statusCode}');
      print('📥 Alternative upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh user profile to get updated image URL
        await _fetchUserProfile();
        return true;
      } else {
        print(
            '⚠️ Failed to upload image with alternative method: ${response.body}');
        return false;
      }
    } catch (e) {
      print('⚠️ Alternative image upload error: $e');
      return false;
    }
  }

  // Login method - improved to honor Remember Me with JWT expiration
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false, // Keep this for UX preference only
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        // Handle JWT token response
        if (result['tokens'] != null) {
          _token = JwtToken.fromJson(result['tokens']);

          // Save token and user preferences
          await SharedPrefs.saveJwtToken(_token!);
          await SharedPrefs.setRememberMe(rememberMe);
          await SharedPrefs.setLastUsedEmail(email);
          await SharedPrefs.setLastLoginTime();
          await SharedPrefs.setLastActivity();

          print('🔑 Login successful. Remember Me: $rememberMe');
        }

        // If user object is included in the response, use it
        if (result['user'] != null) {
          _currentUser = result['user'] as Account;
          print('👤 User verification status: ${_currentUser?.isVerified}');
        }

        // Fetch user profile if needed
        if (_currentUser == null) {
          await _fetchUserProfile();
          print(
              '👤 Fetched user verification status: ${_currentUser?.isVerified}');
        }

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      print('🔑 Login error: ${e.toString()}');
      _error = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper getter to check if the current user is verified
  bool get isUserVerified => _currentUser?.isVerified ?? false;

  // Fetch user profile using stored token
  Future<void> _fetchUserProfile() async {
    if (_token == null) return;

    try {
      // First check if the token needs to be refreshed
      if (_token!.isAccessTokenExpired) {
        print('🔄 Access token expired, attempting to refresh...');
        final refreshed = await refreshToken();
        if (!refreshed) {
          _error = 'Failed to refresh token';
          await logout();
          return;
        }
      }

      final result = await _authService.getUserProfile(_token!.accessToken);

      if (result['success']) {
        _currentUser = result['user'];
      } else if (result['token_expired'] == true) {
        // Handle expired token response by trying to refresh
        print('🔄 Server indicates token expired, attempting refresh...');
        final refreshed = await refreshToken();
        if (refreshed) {
          // Try again with the refreshed token
          await _fetchUserProfile();
        } else {
          _error = 'Session expired. Please login again.';
          await logout();
        }
      } else {
        _error = result['error'];
        // If getting profile fails for other reasons, check if we should logout
        if (result['error']?.toString().toLowerCase().contains('auth') ??
            false) {
          await logout();
        }
      }
    } catch (e) {
      print('❌ Profile fetch error: ${e.toString()}');
      _error = 'Failed to fetch profile: ${e.toString()}';
    }
  }

  // Verify email with code
  Future<bool> verifyEmail(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authorizedApiCall(
          (token) => _authService.verifyEmail(token, code));

      if (result['success']) {
        // Update user data if included in response
        if (result['user'] != null) {
          _currentUser = result['user'];
        } else {
          // Ensure we have the latest user data
          await _fetchUserProfile();
        }
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Email verification failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Resend verification code
  Future<bool> resendVerificationCode() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authorizedApiCall(
          (token) => _authService.resendVerificationCode(token));

      if (result['success']) {
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Failed to resend verification code: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enhanced logout to handle both Google and backend logout with session cleanup
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Complete logout from both Google and backend
      if (_token != null) {
        await _authService.completeSignOut(_token!.accessToken);
      }

      // Clear all session data
      await SharedPrefs.clearSession();

      // Reset local state
      _token = null;
      _currentUser = null;
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to clear all session data - expanded for all preferences
  Future<void> _clearSession() async {
    // Use the centralized SharedPrefs helper
    await SharedPrefs.clearSession();

    // Reset state
    _token = null;
    _currentUser = null;
  }

  // Record user activity - simplified to match JWT lifetime
  Future<void> recordActivity() async {
    if (_token != null && !_token!.isRefreshTokenExpired) {
      final rememberMe = await SharedPrefs.getRememberMe();

      // Always update last activity time
      await SharedPrefs.setLastActivity();

      if (rememberMe) {
        // For users with Remember Me, refresh the token if needed
        if (_token!.isAccessTokenExpired || shouldRefreshToken) {
          await refreshToken();
        }
      }
    }
  }

  // Sign in with Google - ensure it uses JWT tokens
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Avoid duplicate requests if user is already authenticated
      if (isAuthenticated &&
          _currentUser != null &&
          _currentUser?.googleId != null) {
        print(
            '🔑 User is already authenticated with Google, returning current user');
        return {
          'success': true,
          'is_new_account': false,
          'account_linked': false,
          'user': _currentUser,
        };
      }

      final result = await _authService.handleGoogleSignIn();

      if (result['success']) {
        // Handle JWT token response
        if (result['tokens'] != null) {
          _token = JwtToken.fromJson(result['tokens']);

          // Save auth data
          await SharedPrefs.saveJwtToken(_token!);
          await SharedPrefs.setRememberMe(
              true); // Social auth always uses Remember Me
          await SharedPrefs.setLastActivity();
        }

        _currentUser = result['user'];

        return {
          'success': true,
          'is_new_account': result['is_new_account'] ?? false,
          'account_linked': result['account_linked'] ?? false,
          'user': _currentUser,
        };
      } else {
        _error = result['error'];
        return {
          'success': false,
          'error': _error,
        };
      }
    } catch (e) {
      _error = 'Google sign-in failed: ${e.toString()}';
      return {
        'success': false,
        'error': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Request password reset with better error handling
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔐 Sending password reset request for: $email');
      final result = await _authService.forgotPassword(email);

      if (result['success']) {
        print('🔐 Reset code request processed');

        // Extract additional information
        final bool emailExists = result['exists'] ?? false;
        final bool emailSent = result['email_sent'] ?? false;

        return {
          'success': true,
          'message': result['message'],
          'email_exists': emailExists,
          'email_sent': emailSent,
        };
      } else {
        _error = result['error'];
        print('🔐 Reset code error: $_error');
        return {
          'success': false,
          'error': _error,
        };
      }
    } catch (e) {
      _error = 'Failed to request password reset: ${e.toString()}';
      print('🔐 Reset code exception: $_error');
      return {
        'success': false,
        'error': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify reset code with improved logging
  Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔐 Verifying reset code for: $email');
      final result = await _authService.verifyResetCode(email, code);

      if (result['success']) {
        print('🔐 Code verification successful');
        return {
          'success': true,
          'reset_token': result['reset_token'],
        };
      } else {
        _error = result['error'];
        print('🔐 Code verification error: $_error');
        return {
          'success': false,
          'error': _error,
        };
      }
    } catch (e) {
      _error = 'Failed to verify reset code: ${e.toString()}';
      print('🔐 Code verification exception: $_error');
      return {
        'success': false,
        'error': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password with token - ensure it handles JWT properly
  Future<bool> resetPassword(String resetToken, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.resetPassword(resetToken, newPassword);

      if (result['success']) {
        // If JWT tokens are provided, use them
        if (result['tokens'] != null) {
          _token = JwtToken.fromJson(result['tokens']);

          // Save token to persistent storage
          await SharedPrefs.saveJwtToken(_token!);

          // Fetch user profile
          await _fetchUserProfile();
        }

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Failed to reset password: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to handle any API calls that require authorization
  Future<Map<String, dynamic>> _authorizedApiCall(
      Future<Map<String, dynamic>> Function(String token) apiCall) async {
    if (_token == null) {
      return {'success': false, 'error': 'Authentication required'};
    }

    try {
      // Ensure token is valid before making the call
      if (!await verifyAndRefreshTokenIfNeeded()) {
        return {'success': false, 'error': 'Authentication failed'};
      }

      final result = await apiCall(_token!.accessToken);

      // Handle token expiration in the response
      if (result['token_expired'] == true) {
        if (await refreshToken()) {
          // Retry the call with new token
          return await apiCall(_token!.accessToken);
        } else {
          await logout();
          return {'success': false, 'error': 'Session expired'};
        }
      }

      return result;
    } catch (e) {
      print('❌ API call error: ${e.toString()}');
      return {'success': false, 'error': e.toString()};
    }
  }
}
