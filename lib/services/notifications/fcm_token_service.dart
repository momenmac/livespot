import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../api/notification_api_service.dart';
import '../database/notification_database_service.dart';
import '../auth/token_manager.dart';
import '../auth/session_manager.dart'; // Add this import
import 'dart:async'; // Add this import for Future.delayed

/// A dedicated service for managing FCM tokens
/// This handles token registration, deactivation, and syncing between Firebase and Django
class FCMTokenService {
  static final FCMTokenService _instance = FCMTokenService._internal();
  factory FCMTokenService() => _instance;

  FCMTokenService._internal() {
    // Subscribe to session events
    _setupSessionEventListener();
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final TokenManager _tokenManager = TokenManager();
  final SessionManager _sessionManager =
      SessionManager(); // Add session manager
  StreamSubscription? _sessionEventSubscription; // Add subscription for cleanup

  // Cache the token to avoid unnecessary token retrievals
  String? _cachedToken;

  // Track initialization state to avoid multiple attempts
  bool _isInitializing = false;
  bool _registrationAttempted = false;

  /// Set up listener for session events
  void _setupSessionEventListener() {
    _sessionEventSubscription = _sessionManager.onSessionEvent.listen((event) {
      if (event == SessionEvent.sessionAuthenticated) {
        debugPrint(
            '🔐 FCMTokenService: Session authenticated event received, registering token');
        // A slight delay to ensure all auth systems are fully ready
        Future.delayed(const Duration(milliseconds: 500), () {
          registerTokenWithRetry();
        });
      }
    });
  }

  /// Initialize the FCM token service
  /// This should be called when the app starts or when a user logs in
  Future<void> initialize() async {
    // Set up token refresh listener
    _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Initial token registration with retry logic
    await registerTokenWithRetry();
  }

  /// Register the FCM token with both Firebase and Django
  /// Will retry after a delay if authentication check fails on first attempt
  Future<bool> registerToken() async {
    // Prevent multiple simultaneous registration attempts
    if (_isInitializing) {
      debugPrint('⚠️ FCMTokenService: Registration already in progress');
      return false;
    }

    _isInitializing = true;

    try {
      // Get the FCM token first - this doesn't need authentication
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCMTokenService: Failed to get FCM token');
        _isInitializing = false;
        return false;
      }

      // Cache the token regardless of auth state
      _cachedToken = token;

      // Check authentication state
      if (!_tokenManager.isAuthenticated) {
        debugPrint(
            '⚠️ FCMTokenService: User not authenticated, skipping token registration');

        // If this is the first attempt, try again after a short delay
        // This helps when the token manager is still initializing
        if (!_registrationAttempted) {
          _registrationAttempted = true;
          _isInitializing = false;

          // Schedule a retry after 3 seconds to allow auth to complete
          debugPrint(
              '🔄 FCMTokenService: Will retry token registration in 3 seconds');
          await Future.delayed(const Duration(seconds: 3));
          return registerToken();
        }

        _isInitializing = false;
        return false;
      }

      // Save token to Firebase
      await NotificationDatabaseService.saveFCMToken(token);
      debugPrint('✅ FCMTokenService: Token saved to Firebase');

      // Register with Django backend
      final platform = _getPlatformString();
      final success = await NotificationApiService.registerFCMToken(
        token: token,
        platform: platform,
      );

      if (success) {
        debugPrint('✅ FCMTokenService: Token registered with Django backend');
        _isInitializing = false;
        return true;
      } else {
        debugPrint(
            '⚠️ FCMTokenService: Failed to register token with Django backend');
        _isInitializing = false;
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCMTokenService: Error registering token: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// Register the FCM token with improved retry logic
  Future<bool> registerTokenWithRetry({int retryCount = 0, int maxRetries = 3}) async {
    // Prevent multiple simultaneous registration attempts
    if (_isInitializing) {
      debugPrint('⚠️ FCMTokenService: Registration already in progress');
      return false;
    }
    
    _isInitializing = true;
    
    try {
      // Get the FCM token first - this doesn't need authentication
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCMTokenService: Failed to get FCM token');
        _isInitializing = false;
        return false;
      }

      // Cache the token regardless of auth state
      _cachedToken = token;
      
      // Check authentication state
      if (!_tokenManager.isAuthenticated) {
        debugPrint('⚠️ FCMTokenService: User not authenticated on attempt ${retryCount + 1}');
        
        // If we haven't hit the max retries, try again after a delay
        if (retryCount < maxRetries) {
          _isInitializing = false;
          final delay = Duration(seconds: (retryCount + 1) * 2); // Exponential backoff: 2s, 4s, 6s
          debugPrint('🔄 FCMTokenService: Will retry token registration in ${delay.inSeconds} seconds (attempt ${retryCount + 1}/${maxRetries})');
          
          await Future.delayed(delay);
          return registerTokenWithRetry(retryCount: retryCount + 1, maxRetries: maxRetries);
        }
        
        debugPrint('⚠️ FCMTokenService: Maximum retry attempts reached. Token registration failed.');
        _isInitializing = false;
        return false;
      }

      // Save token to Firebase
      await NotificationDatabaseService.saveFCMToken(token);
      debugPrint('✅ FCMTokenService: Token saved to Firebase');

      // Register with Django backend
      final platform = _getPlatformString();
      final success = await NotificationApiService.registerFCMToken(
        token: token,
        platform: platform,
      );

      if (success) {
        debugPrint('✅ FCMTokenService: Token registered with Django backend');
        _isInitializing = false;
        return true;
      } else {
        debugPrint('⚠️ FCMTokenService: Failed to register token with Django backend');
        _isInitializing = false;
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCMTokenService: Error registering token: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// Handle token refresh event
  Future<void> _handleTokenRefresh(String newToken) async {
    debugPrint('🔄 FCMTokenService: Token refreshed');

    // Update cached token
    _cachedToken = newToken;

    // Save to Firebase
    await NotificationDatabaseService.saveFCMToken(newToken);

    // Register with Django
    if (_tokenManager.isAuthenticated) {
      final platform = _getPlatformString();
      await NotificationApiService.registerFCMToken(
        token: newToken,
        platform: platform,
      );
    } else {
      // If not authenticated during a refresh, try again after a delay
      debugPrint(
          '⚠️ FCMTokenService: User not authenticated during token refresh');
      await Future.delayed(const Duration(seconds: 3));

      // Check again after delay
      if (_tokenManager.isAuthenticated) {
        final platform = _getPlatformString();
        await NotificationApiService.registerFCMToken(
          token: newToken,
          platform: platform,
        );
      }
    }
  }

  /// Deactivate the current FCM token
  /// This should be called when a user logs out
  Future<bool> deactivateCurrentToken() async {
    try {
      // If we don't have a cached token, try to get it
      final token = _cachedToken ?? await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCMTokenService: No token to deactivate');
        return false;
      }

      // Only call the API if the user is still authenticated
      if (_tokenManager.isAuthenticated) {
        // Deactivate in Django backend
        final success = await NotificationApiService.deactivateToken(token);
        if (success) {
          debugPrint('✅ FCMTokenService: Token deactivated in Django backend');
        } else {
          debugPrint(
              '⚠️ FCMTokenService: Failed to deactivate token in Django backend');
        }
      }

      // Remove token from Firebase
      await NotificationDatabaseService.removeFCMToken(token);
      debugPrint('✅ FCMTokenService: Token removed from Firebase');

      // Clear cached token
      _cachedToken = null;

      return true;
    } catch (e) {
      debugPrint('❌ FCMTokenService: Error deactivating token: $e');
      return false;
    }
  }

  /// Get the current platform as a string
  String _getPlatformString() {
    if (kIsWeb) {
      return 'web';
    }

    // Use defaultTargetPlatform for better web compatibility
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    return await _firebaseMessaging.getToken();
  }

  /// Clean up resources
  void dispose() {
    _sessionEventSubscription?.cancel();
  }
}
