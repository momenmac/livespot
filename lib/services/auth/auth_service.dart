import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/auth/token_manager.dart'; // Import TokenManager

class AuthService extends ChangeNotifier {
  final TokenManager _tokenManager = TokenManager();
  bool _isLoading = true;
  bool _initialCheckComplete = false;

  bool get isAuthenticated => _tokenManager.isAuthenticated;
  bool get isLoading => _isLoading;
  bool get initialCheckComplete => _initialCheckComplete;
  String? get token => _tokenManager.currentToken?.accessToken;
  Map<String, dynamic>? get user =>
      null; // User data is managed by SessionManager

  // Initialize and validate existing token
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize TokenManager which handles token loading and validation
      await _tokenManager.initialize();
    } catch (e) {
      debugPrint('Error during auth initialization: $e');
    } finally {
      _isLoading = false;
      _initialCheckComplete = true;
      notifyListeners();
    }
  }

  // Validate token with server - delegate to TokenManager
  Future<bool> validateToken() async {
    return await _tokenManager.validateTokenIfNeeded();
  }

  // Refresh token - delegate to TokenManager
  Future<bool> refreshToken() async {
    final accessToken = await _tokenManager.getValidAccessToken();
    if (accessToken != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  // Clear session data - delegate to TokenManager
  Future<void> clearSession() async {
    debugPrint('[LogoutTrace] --- Clear Session Start (AuthService) ---');
    await _tokenManager.clearTokens();
    debugPrint('[LogoutTrace] --- Clear Session End (AuthService) ---');
    notifyListeners();
  }

  // Google sign in method (placeholder - actual implementation is in AccountProvider)
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Attempting to sign in with Google');
      // This method is now handled by AccountProvider and the main AuthService
      // This is kept for compatibility but doesn't actually perform authentication

      notifyListeners();
      return isAuthenticated;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return false;
    }
  }
}
