import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, Uint8List, defaultTargetPlatform, kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../models/account.dart';
import '../../../models/jwt_token.dart';
import '../../../models/api/auth_response.dart';
import '../../../models/api/api_response.dart';
import 'api_urls.dart';

class AuthService {
  final GoogleSignIn googleSignIn = _getGoogleSignIn();
  final String baseUrl;
  final http.Client _client = http.Client();

  // Base URL should match your Django server - adjust as needed
  AuthService({String? baseUrl}) : baseUrl = baseUrl ?? ApiUrls.baseUrl;

  static GoogleSignIn _getGoogleSignIn() {
    if (kIsWeb) {
      //web
      return GoogleSignIn(
        clientId:
            '160030236932-i37bjgcbpobam70f24d0a8f2hf5124tl.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      //ios
      return GoogleSignIn(
        clientId:
            '160030236932-v1fqu2qitgnlivemngb5h1uq92fgr8mq.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else {
      return GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        // TODO: Verify Google token with backend
        // TODO: Check if user exists in database
        // TODO: If new user, create user record with Google data
        // TODO: Generate and store JWT token
        // TODO: Store user preferences and settings
        // TODO: Log sign in attempt for security

        print('==== Google Sign In Success ====');
        print('Email: ${account.email}');
        print('Display Name: ${account.displayName}');
        print('Photo URL: ${account.photoUrl}');
        print('ID: ${account.id}');
        print('Server Auth Code: ${account.serverAuthCode}');
        print('============================');
      } else {
        print('Sign in failed - account is null');
      }
      return account;
    } catch (error) {
      // TODO: Log authentication errors to backend
      // TODO: Implement proper error handling and user feedback
      print('==== Google Sign In Error ====');
      print('Error details: $error');
      print('============================');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      // TODO: Invalidate JWT token
      // TODO: Clear user session in backend
      // TODO: Log sign out event
      // TODO: Clear local secure storage
      await googleSignIn.signOut();
    } catch (error) {
      // TODO: Handle sign out errors properly
      print('Sign out error: $error');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account != null) {
      // TODO: Verify session is still valid in backend
      // TODO: Refresh JWT token if needed
      // TODO: Update last active timestamp
      // TODO: Sync user data with backend
      print('User signed in silently:');
      print('Display Name: ${account.displayName}');
      print('Email: ${account.email}');
      print('ID: ${account.id}');
      print('Photo URL: ${account.photoUrl}');
      return account;
    } else {
      // TODO: Clear any stale local data
      print('No user is signed in.');
      return null;
    }
  }

  // Common method to handle HTTP requests and parse responses
  Future<AuthResponse> _makeAuthRequest({
    required Uri url,
    required String method,
    Map<String, String>? headers,
    Object? body,
    String? token,
  }) async {
    try {
      http.Response response;

      // Add authorization header if token is provided
      final Map<String, String> requestHeaders = headers ?? {};
      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // Make the appropriate HTTP request based on the method
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(url, headers: requestHeaders);
          break;
        case 'POST':
          response =
              await _client.post(url, headers: requestHeaders, body: body);
          break;
        case 'PUT':
          response =
              await _client.put(url, headers: requestHeaders, body: body);
          break;
        case 'DELETE':
          response = await _client.delete(url, headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Debug logging
      print('🌐 ${method.toUpperCase()} request to: ${url.toString()}');
      if (body != null) {
        print('🌐 Request body: $body');
      }
      print('🌐 Response status: ${response.statusCode}');
      print('🌐 Response body: ${response.body}');

      // Parse the response
      final Map<String, dynamic> responseData =
          json.decode(response.body) as Map<String, dynamic>;

      // Handle common status codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success
        responseData['success'] = true;
      } else if (response.statusCode == 401) {
        // Unauthorized - token expired
        responseData['token_expired'] = true;
        responseData['success'] = false;
        responseData['error'] =
            responseData['error'] ?? 'Authentication token expired';
      } else {
        // Other errors
        responseData['success'] = false;
      }

      return AuthResponse.fromJson(responseData);
    } catch (e) {
      print('🌐 Request error: $e');
      return AuthResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/accounts/register/');

      final body = jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      });

      final response = await _makeAuthRequest(
        url: url,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // Convert to standard response format for backward compatibility
      return response.toMap();
    } catch (e) {
      print('🌐 Registration error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Login attempt for: $email');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.login),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.user != null) {
        print(
            '🔑 User verification status from API: ${response.user!.isVerified}');
      } else {
        print('🔑 No user data in login response, will fetch separately');
      }

      return response.toMap();
    } catch (e) {
      print('🔑 Login error: ${e.toString()}');
      return {
        'success': false,
        'error':
            'An error occurred during login. Please check your internet connection.',
      };
    }
  }

  // Google login/signup
  Future<Map<String, dynamic>> googleLogin({
    required String googleId,
    required String email,
    required String firstName,
    required String lastName,
    String? profilePicture,
  }) async {
    try {
      print('🔑 Sending Google auth data to backend for: $email');

      final response = await _makeAuthRequest(
        url: Uri.parse('$baseUrl/accounts/google-login/'),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'google_id': googleId,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'profile_picture': profilePicture,
        }),
      );

      if (response.success) {
        print('🔑 Is new account: ${response.isNewAccount}');
        print('🔑 Existing account linked: ${response.accountLinked}');
      } else {
        print('❌ Google auth failed: ${response.error}');
      }

      return response.toMap();
    } catch (e) {
      print('❌ Google auth network error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Handle complete Google sign-in flow
  Future<Map<String, dynamic>> handleGoogleSignIn() async {
    try {
      // First perform the Google sign-in
      print('🔍 Starting Google Sign-in flow');

      // Check if already signed in to prevent duplicate sign-ins
      final isAlreadySignedIn = await googleSignIn.isSignedIn();
      GoogleSignInAccount? googleAccount;

      if (isAlreadySignedIn) {
        // Get the current account
        googleAccount =
            googleSignIn.currentUser ?? await googleSignIn.signInSilently();
        print(
            '🔍 Already signed in with Google, using current account: ${googleAccount?.email}');
      } else {
        // Start a new sign in flow
        googleAccount = await googleSignIn.signIn();
      }

      if (googleAccount == null) {
        print('🔍 User cancelled Google Sign-in or no account found');
        return {
          'success': false,
          'error': 'Google sign-in was cancelled or failed',
        };
      }

      print('🔍 Google Sign-in successful: ${googleAccount.email}');

      // Split name into first and last name
      String displayName = googleAccount.displayName ?? '';
      List<String> nameParts = displayName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : 'User';
      String lastName = nameParts.length > 1 ? nameParts.last : '';

      print('🔍 Name parsed as: $firstName $lastName');

      // Properly format the profile picture URL
      String? photoUrl = googleAccount.photoUrl;
      if (photoUrl != null) {
        // Google photos usually come with a small size parameter, let's improve it
        if (photoUrl.contains('=s')) {
          // Replace the size parameter with larger one (s400-c for 400px cropped)
          photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s400-c');
        } else if (!photoUrl.contains('=')) {
          // If there's no size parameter, add one
          photoUrl = '$photoUrl=s400-c';
        }

        print('🔍 Enhanced profile picture URL: $photoUrl');
      } else {
        print('🔍 No profile picture available');
      }

      // Now authenticate with our backend
      return await googleLogin(
        googleId: googleAccount.id,
        email: googleAccount.email,
        firstName: firstName,
        lastName: lastName,
        profilePicture: photoUrl,
      );
    } catch (e) {
      print('❌ Google authentication error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Google authentication error: ${e.toString()}',
      };
    }
  }

  // Get user profile with JWT token
  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse('$baseUrl/accounts/profile/'),
        method: 'GET',
        headers: {'Content-Type': 'application/json'},
        token: token,
      );

      if (response.success) {
        return {
          'success': true,
          'user': response.user,
        };
      } else {
        return {
          'success': false,
          'error': response.error ?? 'Failed to get user profile',
          'token_expired': response.tokenExpired,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Refresh JWT token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.tokenRefresh),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      return response.toMap();
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Token verification not needed for JWT as it's self-contained, but keeping for compatibility
  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      // For JWT, check if token is expired by decoding it
      final jwtToken = JwtToken.fromJson({'access': token, 'refresh': ''});

      if (jwtToken.isAccessTokenExpired) {
        return {
          'success': true,
          'valid': false,
          'expired': true,
        };
      }

      // We could make an API call to a protected endpoint to verify with server
      // but it's optional since JWT tokens are self-contained
      return {
        'success': true,
        'valid': true,
      };
    } catch (e) {
      print('Token verification error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Error during token verification: ${e.toString()}',
        'valid': false,
      };
    }
  }

  // Sign out from both Google and our backend - clean up legacy references
  Future<Map<String, dynamic>> completeSignOut(String? token) async {
    try {
      // Sign out from Google
      await googleSignIn.signOut();

      // Sign out from our backend if we have a token
      if (token != null) {
        try {
          // For JWT, blacklist the token on the server
          await _client.post(
            Uri.parse('${ApiUrls.baseUrl}/accounts/logout/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token', // Ensure Bearer prefix is used
            },
            // Pass refresh token in the body for blacklisting
            body: jsonEncode({'refresh': token}),
          );
        } catch (e) {
          print('Backend logout error: ${e.toString()}');
          // Continue with local logout even if backend logout fails
        }
      }

      return {
        'success': true,
        'message': 'Successfully signed out',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Sign out error: ${e.toString()}',
      };
    }
  }

  // Verify email with code (JWT version)
  Future<Map<String, dynamic>> verifyEmail(String token, String code) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse('${ApiUrls.baseUrl}/accounts/verify-email/'),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
        body: jsonEncode({'code': code}),
      );

      return response.toMap();
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Resend verification code (JWT version)
  Future<Map<String, dynamic>> resendVerificationCode(String token) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse('${ApiUrls.baseUrl}/accounts/resend-verification-code/'),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
      );

      return response.toMap();
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfileImage(
      String token, Uint8List imageData) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageData);

      // Send request to update profile with image
      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.updateProfile),
        method: 'PUT',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'profile_image': base64Image,
        }),
      );

      return response.toMap();
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Upload profile image with JWT authentication - remove CSRF references
  Future<Map<String, dynamic>> uploadProfileImage(
      String token, Uint8List imageData) async {
    try {
      // Create multipart request
      final uri = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header with Bearer token for JWT
      request.headers['Authorization'] = 'Bearer $token';

      // Add profile image
      final multipartFile = http.MultipartFile.fromBytes(
        'profile_image',
        imageData,
        filename: 'profile.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Profile image updated',
          'profile_picture_url': responseData['profile_picture_url']
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to upload image with status: ${response.statusCode}',
          'token_expired': response.statusCode == 401,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Image upload error: ${e.toString()}',
      };
    }
  }

  // Request password reset with improved debugging
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      print('📧 Sending password reset request to API for: $email');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.forgotPassword),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      return response.toMap();
    } catch (e) {
      print('📧 Forgot password network error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Verify reset code with better logging
  Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    try {
      print('🔎 Verifying reset code for email: $email');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.verifyResetCode),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'code': code,
        }),
      );

      return response.toMap();
    } catch (e) {
      print('🔎 Verify code error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Reset password - remove any legacy token references
  Future<Map<String, dynamic>> resetPassword(
      String resetToken, String newPassword) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.resetPassword),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'reset_token': resetToken,
          'new_password': newPassword,
        }),
      );

      return response.toMap();
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
