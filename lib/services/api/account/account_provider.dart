import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/account.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AccountProvider extends ChangeNotifier {
  Account? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  final AuthService _authService = AuthService();

  Account? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Initialize provider with session management
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        print('💼 Found existing token, checking session validity...');
        // First check if token is still valid
        final tokenValid = await verifyToken();

        if (tokenValid) {
          print('💼 Token is valid, fetching user profile...');
          await _fetchUserProfile();

          // Check session timeout settings
          final rememberMe = prefs.getBool('remember_me') ?? false;
          if (!rememberMe) {
            // Check if session has expired
            final lastActivity = prefs.getString('last_activity');
            if (lastActivity != null) {
              final lastActivityTime = DateTime.parse(lastActivity);
              final currentTime = DateTime.now();
              // Session timeout after 24 hours if not "remember me"
              if (currentTime.difference(lastActivityTime).inHours > 24) {
                print('💼 Session expired, logging out...');
                await logout();
                return;
              }
            }

            // Update last activity time
            await prefs.setString(
                'last_activity', DateTime.now().toIso8601String());
          }
        } else {
          print('💼 Token is invalid, clearing session...');
          await _clearSession();
        }
      }
    } catch (e) {
      print('💼 Error during initialization: ${e.toString()}');
      _error = 'Failed to initialize: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
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
        _token = result['token'];

        // If user object is included in the response, use it
        if (result['user'] != null) {
          _currentUser = result['user'];
        }

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

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

  // Upload profile image
  Future<bool> _uploadProfileImage(Uint8List imageData) async {
    if (_token == null) {
      return false;
    }

    try {
      // Create multipart request for profile image upload
      final url = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', url);

      // Add the authorization header
      request.headers['Authorization'] = 'Token $_token';

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
      } else {
        print('⚠️ Failed to upload image: ${response.body}');

        if (response.statusCode == 401) {
          print('⚠️ Authentication error. Token might be invalid.');
          return false;
        }

        if (response.statusCode == 403 || response.body.contains("CSRF")) {
          print(
              '🔄 CSRF issue detected, attempting alternative upload method...');
          return await _uploadProfileImageAlternative(imageData);
        }

        return false;
      }
    } catch (e) {
      print('⚠️ Image upload error: $e');

      // Try alternative method if there was an error
      print('🔄 Error occurred, attempting alternative upload method...');
      return await _uploadProfileImageAlternative(imageData);
    }
  }

  // Alternative method to upload profile image without CSRF token
  Future<bool> _uploadProfileImageAlternative(Uint8List imageData) async {
    if (_token == null) {
      return false;
    }

    try {
      // Use JSON API instead with base64 encoded image
      final base64Image = base64Encode(imageData);

      final response = await http.post(
        Uri.parse(ApiUrls.updateProfile),
        headers: {
          'Authorization': 'Bearer $_token',
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

  // Register a new user with profile image
  Future<bool> registerWithImage({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    Uint8List? profileImage,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First register the user
      final result = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success']) {
        _token = result['token'];
        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        // If we have a profile image, upload it
        if (profileImage != null) {
          // Upload profile image logic would go here
          // This would typically be a separate API call
          // For now, we'll just fetch the user profile
        }

        // Fetch user profile
        await _fetchUserProfile();
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login with email and password with session management
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
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
        _token = result['token'];

        // If user object is included in the response, use it
        if (result['user'] != null) {
          _currentUser = result['user'] as Account;
          print('👤 User verification status: ${_currentUser?.isVerified}');
        }

        // Save token and session state to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setBool('remember_me', rememberMe);
        await prefs.setString(
            'last_activity', DateTime.now().toIso8601String());

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

  // Google login/signup
  Future<bool> googleLogin({
    required String googleId,
    required String email,
    required String firstName,
    required String lastName,
    String? profilePicture,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.googleLogin(
        googleId: googleId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profilePicture: profilePicture,
      );

      if (result['success']) {
        _token = result['token'];
        _currentUser = result['user'];

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Google login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google and handle backend authentication
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.handleGoogleSignIn();

      if (result['success']) {
        _token = result['token'];
        _currentUser = result['user'];

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Google sign-in failed: ${e.toString()}';
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
      await _authService.completeSignOut(_token);

      // Clear all session data
      await _clearSession();
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify if current token is still valid
  Future<bool> verifyToken() async {
    if (_token == null) return false;

    try {
      final result = await _authService.verifyToken(_token!);

      if (!result['success'] || !result['valid']) {
        // If token is invalid, clear current user data
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      _error = 'Token verification failed: ${e.toString()}';
      return false;
    }
  }

  // Fetch user profile using stored token
  Future<void> _fetchUserProfile() async {
    if (_token == null) return;

    try {
      final result = await _authService.getUserProfile(_token!);

      if (result['success']) {
        _currentUser = result['user'];
      } else {
        _error = result['error'];
        // If getting profile fails, token might be invalid
        await logout();
      }
    } catch (e) {
      _error = 'Failed to fetch profile: ${e.toString()}';
    }
  }

  // Verify email with code
  Future<bool> verifyEmail(String code) async {
    if (_token == null) {
      _error = 'Authentication required';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final result = await _authService.verifyEmail(_token!, code);

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
    if (_token == null) {
      _error = 'Authentication required';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final result = await _authService.resendVerificationCode(_token!);

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
        };
      }
    } catch (e) {
      _error = 'Failed to verify reset code: ${e.toString()}';
      print('🔐 Code verification exception: $_error');
      return {
        'success': false,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password with token
  Future<bool> resetPassword(String resetToken, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.resetPassword(resetToken, newPassword);

      if (result['success']) {
        // If login token is provided, use it
        if (result['token'] != null) {
          _token = result['token'];

          // Save token to persistent storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _token!);

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

  // Helper method to extract error message from response
  String _extractErrorMessage(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data['message'] != null) {
        return data['message'];
      } else if (data['error'] != null) {
        return data['error'];
      }
      return 'Registration failed with status code: ${response.statusCode}';
    } catch (e) {
      return 'Registration failed with status code: ${response.statusCode}';
    }
  }

  // Clear session if remember me is not enabled
  Future<void> clearSessionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!rememberMe) {
      await prefs.remove('auth_token');
      _token = null;
      _currentUser = null;
      notifyListeners();
    }
  }

  // Helper method to clear all session data
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('remember_me');
    await prefs.remove('last_activity');
    _token = null;
    _currentUser = null;
  }

  // Record user activity to maintain session
  Future<void> recordActivity() async {
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (!rememberMe) {
        // Only update activity time for session-based logins
        await prefs.setString(
            'last_activity', DateTime.now().toIso8601String());
      }
    }
  }
}
