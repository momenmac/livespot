import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, Uint8List, defaultTargetPlatform, kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../models/account.dart';
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

  // Register a new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/accounts/register/');
      print('🌐 API Request to: ${url.toString()}');
      print('🌐 Request body: ${jsonEncode({
            'email': email,
            'password': password,
            'first_name': firstName,
            'last_name': lastName,
          })}');

      final response = await _client
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        }),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('🌐 Request timeout');
          return http.Response('{"error": "Request timed out"}', 408);
        },
      );

      print('🌐 Response status: ${response.statusCode}');
      print('🌐 Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = {
          'success': true,
          'token': responseData['token'],
          'message': responseData['message'] ?? 'Registration successful',
        };

        // Include user data if available
        if (responseData['user'] != null) {
          result['user'] = Account.fromJson(responseData['user']);
        }

        return result;
      } else {
        return {
          'success': false,
          'error': responseData['error'] ??
              'Registration failed with status code: ${response.statusCode}',
        };
      }
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
      final response = await _client.post(
        Uri.parse('$baseUrl/accounts/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': responseData['token'],
          'message': responseData['message'] ?? 'Login successful',
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Invalid credentials',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
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
      final response = await _client.post(
        Uri.parse('$baseUrl/accounts/google-login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'google_id': googleId,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'profile_picture': profilePicture,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': responseData['token'],
          'user': responseData['user'] != null
              ? Account.fromJson(responseData['user'])
              : null,
          'message': responseData['message'] ?? 'Google login successful',
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Google login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get user profile with token
  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/accounts/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': Account.fromJson(responseData),
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to get user profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Handle complete Google sign-in flow including backend authentication
  Future<Map<String, dynamic>> handleGoogleSignIn() async {
    try {
      // First perform the Google sign-in
      GoogleSignInAccount? googleAccount = await signInWithGoogle();

      if (googleAccount == null) {
        return {
          'success': false,
          'error': 'Google sign-in was cancelled or failed',
        };
      }

      // Split name into first and last name
      String displayName = googleAccount.displayName ?? '';
      List<String> nameParts = displayName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : 'User';
      String lastName = nameParts.length > 1 ? nameParts.last : '';

      // Now authenticate with our backend
      return await googleLogin(
        googleId: googleAccount.id,
        email: googleAccount.email,
        firstName: firstName,
        lastName: lastName,
        profilePicture: googleAccount.photoUrl,
      );
    } catch (e) {
      return {
        'success': false,
        'error': 'Google authentication error: ${e.toString()}',
      };
    }
  }

  // Verify token with backend
  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiUrls.baseUrl}/accounts/verify-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'valid': true,
        };
      } else {
        return {
          'success': true,
          'valid': false,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error during token verification: ${e.toString()}',
        'valid': false,
      };
    }
  }

  // Sign out from both Google and our backend
  Future<Map<String, dynamic>> completeSignOut(String? token) async {
    try {
      // Sign out from Google
      await googleSignIn.signOut();

      // Sign out from our backend if we have a token
      if (token != null) {
        try {
          await _client.post(
            Uri.parse('${ApiUrls.baseUrl}/accounts/logout/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
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

  Future<Map<String, dynamic>> updateProfileImage(
      String token, Uint8List imageData) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageData);

      // Send request to update profile with image
      final response = await http.put(
        Uri.parse(ApiUrls.updateProfile),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'profile_image': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'user': Account.fromJson(data),
        };
      } else {
        return {
          'success': false,
          'error':
              'Failed to update profile with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Upload profile image
  Future<Map<String, dynamic>> uploadProfileImage(
      String token, Uint8List imageData) async {
    try {
      // Create multipart request
      final uri = Uri.parse('${ApiUrls.profileImage}');
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Profile image updated',
          'profile_picture_url': data['profile_picture_url']
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to upload image with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Image upload error: ${e.toString()}',
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
