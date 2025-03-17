import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/account.dart';
import 'auth_service.dart';

class AccountProvider extends ChangeNotifier {
  Account? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  final AuthService _authService = AuthService();

  Account? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Initialize provider and check for existing token
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        await _fetchUserProfile();
      }
    } catch (e) {
      _error = 'Failed to initialize: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register a new user
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success']) {
        _token = result['token'];

        // If user object is included in the response, use it
        if (result['user'] != null) {
          _currentUser = result['user'];
        }

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        // Fetch user profile if needed
        if (_currentUser == null) {
          await _fetchUserProfile();
        }

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register a new user with profile image
  Future<bool> registerWithImage({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    Uint8List? profileImage,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First register the user
      final result = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success']) {
        _token = result['token'];
        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        // If we have a profile image, upload it
        if (profileImage != null) {
          // Upload profile image logic would go here
          // This would typically be a separate API call
          // For now, we'll just fetch the user profile
        }

        // Fetch user profile
        await _fetchUserProfile();
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        _token = result['token'];
        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        // Fetch user profile
        await _fetchUserProfile();
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Google login/signup
  Future<bool> googleLogin({
    required String googleId,
    required String email,
    required String firstName,
    required String lastName,
    String? profilePicture,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.googleLogin(
        googleId: googleId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profilePicture: profilePicture,
      );

      if (result['success']) {
        _token = result['token'];
        _currentUser = result['user'];

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Google login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google and handle backend authentication
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.handleGoogleSignIn();

      if (result['success']) {
        _token = result['token'];
        _currentUser = result['user'];

        // Save token to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } catch (e) {
      _error = 'Google sign-in failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enhanced logout to handle both Google and backend logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Complete logout from both Google and backend
      await _authService.completeSignOut(_token);

      _currentUser = null;
      _token = null;
      _error = null;

      // Clear token from persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify if current token is still valid
  Future<bool> verifyToken() async {
    if (_token == null) return false;

    try {
      final result = await _authService.verifyToken(_token!);

      if (!result['success'] || !result['valid']) {
        // If token is invalid, clear current user data
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      _error = 'Token verification failed: ${e.toString()}';
      return false;
    }
  }

  // Fetch user profile using stored token
  Future<void> _fetchUserProfile() async {
    if (_token == null) return;

    try {
      final result = await _authService.getUserProfile(_token!);

      if (result['success']) {
        _currentUser = result['user'];
      } else {
        _error = result['error'];
        // If getting profile fails, token might be invalid
        await logout();
      }
    } catch (e) {
      _error = 'Failed to fetch profile: ${e.toString()}';
    }
  }
}
