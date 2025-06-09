import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, Uint8List, defaultTargetPlatform, kIsWeb;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../models/jwt_token.dart';
import '../../../models/api/auth_response.dart';
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
        // Disable automatic web view presentation for iOS simulators
        signInOption: SignInOption.standard,
      );
    } else {
      return GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  // Helper to check if running on iOS simulator with multiple detection methods
  Future<bool> _isIosSimulator() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        // Method 1: Check device name
        try {
          final String deviceName = await SystemChannels.platform
                  .invokeMethod<String>('getDeviceName') ??
              '';

          if (deviceName.toLowerCase().contains('simulator')) {
            return true;
          }
        } catch (e) {
          // Continue with other methods if this fails
          print('⚠️ First simulator detection method failed: $e');
        }

        // Method 2: Using Platform.isIOS with environment check
        if (Platform.isIOS) {
          try {
            // For iOS, check if we're running on a simulator by checking for simulator-specific environment
            final bool isSimulator = await SystemChannels.platform
                    .invokeMethod<bool>('isPhysicalDevice') ==
                false;
            return isSimulator;
          } catch (e) {
            print('⚠️ Second simulator detection method failed: $e');
          }
        }

        // Method 3: Fallback to synchronous detection
        if (Platform.isIOS) {
          // Return true if the iOS app ID contains 'simulator' (common for simulator builds)
          final String processName = Platform.executable.toLowerCase();
          return processName.contains('simulator');
        }
      } catch (e) {
        print('⚠️ Could not determine iOS simulator status: $e');
        // If all methods fail, provide a user-friendly warning and continue
        print(
            '⚠️ Will continue with normal sign-in flow, but some features may not work properly in simulator');
      }
    }
    return false;
  }

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
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
      print('==== Google Sign In Error ====');
      print('Error details: $error');
      print('============================');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
    } catch (error) {
      print('Sign out error: $error');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account != null) {
      print('User signed in silently:');
      print('Display Name: ${account.displayName}');
      print('Email: ${account.email}');
      print('ID: ${account.id}');
      print('Photo URL: ${account.photoUrl}');
      return account;
    } else {
      print('No user is signed in.');
      return null;
    }
  }

  Future<AuthResponse> _makeAuthRequest({
    required Uri url,
    required String method,
    Map<String, String>? headers,
    Object? body,
    String? token,
  }) async {
    try {
      http.Response response;

      final Map<String, String> requestHeaders = headers ?? {};
      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

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

      print('🌐 ${method.toUpperCase()} request to: ${url.toString()}');
      if (body != null) {
        print('🌐 Request body: $body');
      }
      print('🌐 Response status: ${response.statusCode}');
      print('🌐 Response body: ${response.body}');

      final Map<String, dynamic> responseData =
          json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        responseData['success'] = true;
      } else if (response.statusCode == 401) {
        responseData['token_expired'] = true;
        responseData['success'] = false;
        responseData['error'] =
            responseData['error'] ?? 'Authentication token expired';
      } else {
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

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final url = Uri.parse(ApiUrls.register);

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

      return response.toMap();
    } catch (e) {
      print('🌐 Registration error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

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
        url: Uri.parse(ApiUrls.googleLogin),
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

  Future<Map<String, dynamic>> handleGoogleSignIn() async {
    try {
      final isSimulator = await _isIosSimulator();
      if (isSimulator) {
        print('📱 iOS Simulator detected - using optimized sign-in flow');
      }

      print('🔍 Starting Google Sign-in flow');

      final isAlreadySignedIn = await googleSignIn.isSignedIn();
      GoogleSignInAccount? googleAccount;

      if (isSimulator) {
        try {
          try {
            await googleSignIn.disconnect();
            print('📱 Disconnected from GoogleSignIn in simulator environment');
          } catch (e) {}

          googleAccount = await googleSignIn.signInSilently();
          print(
              '📱 Silent sign-in result: ${googleAccount != null ? "success" : "failed"}');

          if (googleAccount == null) {
            print('📱 Attempting standard sign-in with timeout protection');

            bool signInCompleted = false;

            final signInFuture = Future.microtask(() async {
              try {
                googleAccount = await googleSignIn.signIn();
                signInCompleted = true;
              } catch (e) {
                print('📱 Sign-in exception on simulator: $e');
              }
            });

            await Future.any([
              signInFuture,
              Future.delayed(const Duration(seconds: 15), () {
                if (!signInCompleted) {
                  print('📱 Sign-in timeout on simulator, using fallback');
                }
              })
            ]);

            if (googleAccount == null) {
              googleAccount = await googleSignIn.signInSilently();

              if (googleAccount == null) {
                return {
                  'success': false,
                  'error':
                      'Google sign-in failed on iOS simulator. This is a known issue with simulators. Please try again or test on a real device.',
                  'simulator_error': true
                };
              }
            }
          }
        } catch (simulatorError) {
          print('📱 Simulator-specific sign-in error: $simulatorError');
          return {
            'success': false,
            'error':
                'iOS simulator issue with Google Sign-In. This is expected in the simulator environment. Please try on a real device.',
            'simulator_error': true
          };
        }
      } else {
        if (isAlreadySignedIn) {
          googleAccount =
              googleSignIn.currentUser ?? await googleSignIn.signInSilently();
          print(
              '🔍 Already signed in with Google, using current account: ${googleAccount?.email}');
        } else {
          googleAccount = await googleSignIn.signIn();
        }
      }

      if (googleAccount == null) {
        print('🔍 User cancelled Google Sign-in or no account found');
        return {
          'success': false,
          'error': 'Google sign-in was cancelled or failed',
        };
      }

      print('🔍 Google Sign-in successful: ${googleAccount?.email}');

      String displayName = googleAccount?.displayName ?? '';
      List<String> nameParts = displayName.trim().split(' ');

      // Better handling of name parts
      String firstName = 'User';
      String lastName = '';

      if (nameParts.isNotEmpty) {
        firstName = nameParts.first;
        // If there are at least 2 parts, use the last part as lastName
        if (nameParts.length > 1) {
          lastName = nameParts.last;
        }
        // For cases with 3+ parts, consider handling middle names if needed
      }

      print('🔍 Name parsed as: $firstName $lastName');

      String? photoUrl = googleAccount?.photoUrl;
      if (photoUrl != null) {
        if (photoUrl.contains('=s')) {
          photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s400-c');
        } else if (!photoUrl.contains('=')) {
          photoUrl = '$photoUrl=s400-c';
        }

        print('🔍 Enhanced profile picture URL: $photoUrl');
      } else {
        print('🔍 No profile picture available');
      }

      return await googleLogin(
        googleId: googleAccount!
            .id, // Using null assertion (!) since we've already checked googleAccount isn't null
        email: googleAccount!.email,
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

  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.profile),
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

  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      final jwtToken = JwtToken.fromJson({'access': token, 'refresh': ''});

      if (jwtToken.isAccessTokenExpired) {
        return {
          'success': true,
          'valid': false,
          'expired': true,
        };
      }

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

  Future<Map<String, dynamic>> completeSignOut(String? token) async {
    try {
      await googleSignIn.signOut();

      if (token != null) {
        try {
          await _client.post(
            Uri.parse(ApiUrls.logout),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'refresh': token}),
          );
        } catch (e) {
          print('Backend logout error: ${e.toString()}');
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

  Future<Map<String, dynamic>> verifyEmail(String token, String code) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.verifyEmail),
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

  Future<Map<String, dynamic>> resendVerificationCode(String token) async {
    try {
      final response = await _makeAuthRequest(
        url: Uri.parse(
            '${ApiUrls.baseUrl}/api/accounts/resend-verification-code/'),
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
      final base64Image = base64Encode(imageData);

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

  Future<Map<String, dynamic>> uploadProfileImage(
      String token, Uint8List imageData) async {
    try {
      final uri = Uri.parse(ApiUrls.profileImage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      final multipartFile = http.MultipartFile.fromBytes(
        'profile_image',
        imageData,
        filename: 'profile.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

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

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      print('🔐 Changing password...');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.changePassword),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      return response.toMap();
    } catch (e) {
      print('🔐 Change password error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Change email
  Future<Map<String, dynamic>> changeEmail({
    required String token,
    required String newEmail,
    required String password,
  }) async {
    try {
      print('📧 Changing email to: $newEmail');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.changeEmail),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
        body: json.encode({
          'new_email': newEmail,
          'password': password,
        }),
      );

      return response.toMap();
    } catch (e) {
      print('📧 Change email error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Request data download
  Future<Map<String, dynamic>> requestDataDownload({
    required String token,
  }) async {
    try {
      print('💾 Requesting data download...');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.dataDownloadRequest),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
      );

      return response.toMap();
    } catch (e) {
      print('💾 Data download request error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Deactivate account
  Future<Map<String, dynamic>> deactivateAccount({
    required String token,
  }) async {
    try {
      print('⏸️ Deactivating account...');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.deactivateAccount),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
      );

      return response.toMap();
    } catch (e) {
      print('⏸️ Deactivate account error: ${e.toString()}');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Delete account
  Future<Map<String, dynamic>> deleteAccount({
    required String token,
    required String password,
  }) async {
    try {
      print('🗑️ Deleting account...');

      final response = await _makeAuthRequest(
        url: Uri.parse(ApiUrls.deleteAccount),
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        token: token,
        body: json.encode({
          'password': password,
        }),
      );

      return response.toMap();
    } catch (e) {
      print('🗑️ Delete account error: ${e.toString()}');
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
