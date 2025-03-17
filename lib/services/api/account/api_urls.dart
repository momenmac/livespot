import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiUrls {
  // Base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000'; // For web development
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // For Android emulator
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:8000'; // For iOS simulator
    } else {
      return 'http://localhost:8000'; // Default for other platforms
    }
  }

  // Base API URL
  static String get baseApiUrl => baseUrl;

  // Authentication URLs
  static String get register => '$baseUrl/accounts/register/';
  static String get login => '$baseUrl/accounts/login/';
  static String get googleLogin => '$baseUrl/accounts/google-login/';
  static String get profile => '$baseUrl/accounts/profile/';
  static String get verifyToken => '$baseUrl/accounts/verify-token/';
  static String get logout => '$baseUrl/accounts/logout/';

  // Profile image upload - updated paths based on server configuration
  static String get profileImage => '$baseUrl/accounts/profile-image/';
  static String get updateProfile => '$baseUrl/accounts/update-profile/';
  static String get getCsrfToken => '$baseUrl/get-csrf-token/';

  // Email verification URLs
  static String get verifyEmail => '$baseUrl/accounts/verify-email/';
  static String get resendVerificationCode =>
      '$baseUrl/accounts/resend-verification-code/';
}
