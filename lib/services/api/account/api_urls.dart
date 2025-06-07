import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiUrls {
  // Base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000'; // For web development
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.13:8000'; // For Android emulator
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:8000'; // For iOS simulator
    } else {
      return 'http://localhost:8000'; // Default for other platforms
    }
  }

  // Base API URL
  static String get baseApiUrl => baseUrl;

  // Authentication URLs
  static String get register => '$baseUrl/api/accounts/register/';
  static String get login => '$baseUrl/api/accounts/login/';
  static String get googleLogin => '$baseUrl/api/accounts/google-login/';
  static String get profile => '$baseUrl/api/accounts/profile/';

  // Token management for JWT - remove CSRF endpoint
  static String get tokenRefresh => '$baseUrl/api/accounts/token/refresh/';
  static String get token => '$baseUrl/api/accounts/token/';
  static String get tokenValidate =>
      '$baseUrl/api/accounts/token/validate/'; // New endpoint
  static String get logout => '$baseUrl/api/accounts/logout/';

  // Profile image upload - updated paths based on server configuration
  static String get profileImage => '$baseUrl/api/accounts/profile-image/';
  static String get updateProfile =>
      '$baseUrl/api/accounts/users/profile/update/';

  // Email verification URLs
  static String get verifyEmail => '$baseUrl/api/accounts/verify-email/';
  static String get resendVerificationCode =>
      '$baseUrl/api/accounts/resend-verification-code/';

  // Password reset endpoints
  static String get forgotPassword => '$baseUrl/api/accounts/forgot-password/';
  static String get verifyResetCode =>
      '$baseUrl/api/accounts/verify-reset-code/';
  static String get resetPassword => '$baseUrl/api/accounts/reset-password/';

  // Posts endpoints
  static String get posts => '$baseUrl/api/posts/';
  static String get nearbyPosts => '$baseUrl/api/posts/nearby/';
  static String get searchPosts => '$baseUrl/api/posts/search/';
  static String postVote(int postId) => '$baseUrl/api/posts/$postId/vote/';

  // Notification endpoints
  static String get notifications => '$baseUrl/api/notifications/';
  static String get fcmTokens => '$baseUrl/api/notifications/fcm-tokens/';
  static String get registerFcmToken =>
      '$baseUrl/api/notifications/fcm-tokens/register_token/';
  static String get deactivateFcmToken =>
      '$baseUrl/api/notifications/fcm-tokens/deactivate_token/';
  static String get notificationSettings =>
      '$baseUrl/api/notifications/settings/';

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

  // Maps endpoints
  static String get openStreetMapTiles => 'https://tile.openstreetmap.org';
  static String get osrmRouting => 'http://router.project-osrm.org';
  static String get nominatimSearch => 'https://nominatim.openstreetmap.org';
}
