import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../api/notification_api_service.dart';
import '../database/notification_database_service.dart';
import '../auth/token_manager.dart';

/// A dedicated service for managing FCM tokens
/// This handles token registration, deactivation, and syncing between Firebase and Django
class FCMTokenService {
  static final FCMTokenService _instance = FCMTokenService._internal();
  factory FCMTokenService() => _instance;
  FCMTokenService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final TokenManager _tokenManager = TokenManager();

  // Cache the token to avoid unnecessary token retrievals
  String? _cachedToken;

  /// Initialize the FCM token service
  /// This should be called when the app starts or when a user logs in
  Future<void> initialize() async {
    // Set up token refresh listener
    _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Initial token registration
    await registerToken();
  }

  /// Register the FCM token with both Firebase and Django
  Future<bool> registerToken() async {
    try {
      // Only proceed if user is authenticated
      if (!_tokenManager.isAuthenticated) {
        debugPrint(
            '⚠️ FCMTokenService: User not authenticated, skipping token registration');
        return false;
      }

      // Get the FCM token
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCMTokenService: Failed to get FCM token');
        return false;
      }

      // Cache the token
      _cachedToken = token;

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
        return true;
      } else {
        debugPrint(
            '⚠️ FCMTokenService: Failed to register token with Django backend');
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCMTokenService: Error registering token: $e');
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
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (kIsWeb) {
      return 'web';
    } else {
      return 'other';
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    return await _firebaseMessaging.getToken();
  }
}
