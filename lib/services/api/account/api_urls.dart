import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiUrls {
  // Base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000'; // For web development
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.3:8000'; // For Android emulator
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

  // Token management for JWT - remove CSRF endpoint
  static String get tokenRefresh => '$baseUrl/accounts/token/refresh/';
  static String get verifyToken => '$baseUrl/accounts/token/verify/';
  static String get tokenValidate =>
      '$baseUrl/accounts/token/validate/'; // New endpoint
  static String get logout => '$baseUrl/accounts/logout/';

  // Profile image upload - updated paths based on server configuration
  static String get profileImage => '$baseUrl/accounts/profile-image/';
  static String get updateProfile => '$baseUrl/accounts/users/profile/update/';

  // Email verification URLs
  static String get verifyEmail => '$baseUrl/accounts/verify-email/';
  static String get resendVerificationCode =>
      '$baseUrl/accounts/resend-verification-code/';

  // Password reset endpoints
  static String get forgotPassword => '$baseUrl/accounts/forgot-password/';
  static String get verifyResetCode => '$baseUrl/accounts/verify-reset-code/';
  static String get resetPassword => '$baseUrl/accounts/reset-password/';

  // Posts endpoints
  static String get posts => '$baseUrl/api/posts/';
  static String get nearbyPosts => '$baseUrl/api/posts/nearby/';
  static String get searchPosts => '$baseUrl/api/posts/search/';
  static String postVote(int postId) => '$baseUrl/api/posts/$postId/vote/';

  // Using the correct endpoint that matches server URL patterns
  // We need to filter threads by post ID in the client side since there's no direct API endpoint
  static String get threads =>
      '$baseUrl/api/threads/'; // Use standard threads endpoint

  // Threads endpoints
  static String get nearbyThreads => '$baseUrl/api/threads/nearby/';
  static String threadDetails(int threadId) =>
      '$baseUrl/api/threads/$threadId/';
  static String addPostToThread(int threadId) =>
      '$baseUrl/api/threads/$threadId/add_post/';
}
