import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/account.dart';
import 'auth_service.dart';
import 'dart:typed_data';
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

  // Initialize provider and check for existing token
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        await _fetchUserProfile();
      }
    } catch (e) {
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

  // Login with email and password
  Future<bool> login({
    required String email,
    required String password,
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
        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        // Fetch user profile
        await _fetchUserProfile();
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

  // Enhanced logout to handle both Google and backend logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Complete logout from both Google and backend
      await _authService.completeSignOut(_token);

      _currentUser = null;
      _token = null;
      _error = null;

      // Clear token from persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
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
}
