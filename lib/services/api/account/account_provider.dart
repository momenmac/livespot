import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart'; // Add this import
import '../../../models/account.dart';
import '../../../models/jwt_token.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AccountProvider extends ChangeNotifier {
  final SessionManager _sessionManager = SessionManager();
  bool _isLoading = false;

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

  final AuthService _authService = AuthService();

  // Constructor that listens for session state changes
  AccountProvider() {
    _sessionManager.onStateChanged.listen((_) {
      // Notify UI to rebuild whenever session state changes
      notifyListeners();
    });
  }

  // Initialize provider
  Future<void> initialize() async {
    // Session initialization happens automatically in the SessionManager constructor
    notifyListeners();
  }

  // Login method
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

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
          await SharedPrefs.saveJwtToken(token);
          await SharedPrefs.setRememberMe(rememberMe);
          await SharedPrefs.setLastUsedEmail(email);
          await SharedPrefs.setLastLoginTime();
          await SharedPrefs.setLastActivity();

          // Update SessionManager
          _sessionManager.setSession(
            token: token,
            user: result['user'] as Account,
          );
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('🔑 Login error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout method
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Complete logout from both Google and backend
      if (token != null) {
        await _authService.completeSignOut(token!.accessToken);
      }

      // Clear session
      await _sessionManager.clearSession();
    } catch (e) {
      print('Logout error: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Record activity
  Future<void> recordActivity() async {
    await _sessionManager.recordActivity();
    notifyListeners();
  }

  // Verify and refresh token if needed
  Future<bool> verifyAndRefreshTokenIfNeeded() async {
    final result = await _sessionManager.verifyAndRefreshTokenIfNeeded();
    notifyListeners();
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
      notifyListeners();

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
      notifyListeners();
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
    notifyListeners();

    try {
      final result = await _authorizedApiCall(
          (token) => _authService.verifyEmail(token, code));

      if (result['success']) {
        if (result['user'] != null) {
          _sessionManager.setUser(result['user'] as Account);
        } else {
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
        return false;
      }
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  // Request password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  // Verify reset code
  Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    _isLoading = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String resetToken, String newPassword) async {
    _isLoading = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  // Method to handle any API calls that require authorization
  Future<Map<String, dynamic>> _authorizedApiCall(
      Future<Map<String, dynamic>> Function(String token) apiCall) async {
    if (token == null) {
      return {'success': false, 'error': 'Authentication required'};
    }

    try {
      if (!await verifyAndRefreshTokenIfNeeded()) {
        return {'success': false, 'error': 'Authentication failed'};
      }

      final result = await apiCall(token!.accessToken);

      if (result['token_expired'] == true) {
        if (await refreshToken()) {
          return await apiCall(token!.accessToken);
        } else {
          await logout();
          return {'success': false, 'error': 'Session expired'};
        }
      }

      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
