import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'dart:developer' as developer; // Import developer for logging
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class SharedPrefs {
  // Keys for SharedPreferences
  static const String onboardingCompletedKey = 'isOnboardingCompleted';
  static const String loggedInKey = 'isLoggedIn';
  static const String jwtTokenKey = 'jwt_token';
  static const String rememberMeKey = 'remember_me';
  static const String lastActivityKey = 'last_activity';
  static const String lastTokenRefreshKey = 'last_token_refresh';
  static const String lastUsedEmailKey = 'last_used_email';
  static const String lastLoginTimeKey = 'last_login_time';

  // Onboarding
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
  }

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  // Login status
  static Future<bool> setLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(loggedInKey, true);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(loggedInKey) ?? false;
  }

  // JWT Token management
  static Future<void> saveJwtToken(JwtToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(jwtTokenKey, jsonEncode(token.toJson()));

    // Update last token refresh time
    await setLastTokenRefresh();
  }

  static Future<JwtToken?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString(jwtTokenKey);

    if (tokenJson != null) {
      try {
        return JwtToken.fromJson(jsonDecode(tokenJson));
      } catch (e) {
        print('❌ Error parsing JWT token: $e');
        return null;
      }
    }
    return null;
  }

  static Future<void> clearJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(jwtTokenKey);
  }

  // Remember Me
  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, value);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(rememberMeKey) ?? false;
  }

  // Activity tracking
  static Future<void> setLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastActivityKey, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getString(lastActivityKey);

    if (lastActivity != null) {
      try {
        return DateTime.parse(lastActivity);
      } catch (e) {
        print('❌ Error parsing last activity time: $e');
        return null;
      }
    }
    return null;
  }

  // Token refresh tracking
  static Future<void> setLastTokenRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        lastTokenRefreshKey, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getLastTokenRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefresh = prefs.getString(lastTokenRefreshKey);

    if (lastRefresh != null) {
      try {
        return DateTime.parse(lastRefresh);
      } catch (e) {
        print('❌ Error parsing last token refresh time: $e');
        return null;
      }
    }
    return null;
  }

  // Email convenience
  static Future<void> setLastUsedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastUsedEmailKey, email);
  }

  static Future<String?> getLastUsedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastUsedEmailKey);
  }

  // Login time tracking
  static Future<void> setLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastLoginTimeKey, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getString(lastLoginTimeKey);

    if (lastLogin != null) {
      try {
        return DateTime.parse(lastLogin);
      } catch (e) {
        print('❌ Error parsing last login time: $e');
        return null;
      }
    }
    return null;
  }

  // Clean up operations
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> clearSession() async {
    developer.log('--- Clear Session Start (SharedPrefs) ---',
        name: 'LogoutTrace');
    final prefs = await SharedPreferences.getInstance();

    // Remove JWT token - MOST IMPORTANT for logout
    developer.log('Removing $jwtTokenKey...', name: 'LogoutTrace');
    await prefs.remove(jwtTokenKey);
    developer.log('$jwtTokenKey removed.', name: 'LogoutTrace');

    // Remove login status flag
    developer.log('Removing $loggedInKey...', name: 'LogoutTrace');
    await prefs.remove(loggedInKey);
    developer.log('$loggedInKey removed.', name: 'LogoutTrace');

    // Keep remember me setting for UX, but remove session data
    developer.log('Removing $lastActivityKey...', name: 'LogoutTrace');
    await prefs.remove(lastActivityKey);
    developer.log('Removing $lastTokenRefreshKey...', name: 'LogoutTrace');
    await prefs.remove(lastTokenRefreshKey);
    developer.log('Removing $lastLoginTimeKey...', name: 'LogoutTrace');
    await prefs.remove(lastLoginTimeKey);

    // Optional: clear any sensitive account data when logging out
    // developer.log('Removing $lastUsedEmailKey...', name: 'LogoutTrace');
    // await prefs.remove(lastUsedEmailKey);

    developer.log('--- Clear Session End (SharedPrefs) ---',
        name: 'LogoutTrace');
  }

  // Remove legacy token if it exists
  static Future<void> removeLegacyToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('token')) {
      await prefs.remove('token');
    }
  }

  // Helper for checking session timeout
  static Future<bool> isSessionTimedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(rememberMeKey) ?? false;

    // If remember me is enabled, session doesn't time out
    if (rememberMe) return false;

    final lastActivity = await getLastActivity();
    if (lastActivity == null) return false;

    final currentTime = DateTime.now();
    final sessionTimeout = const Duration(hours: 24);

    return currentTime.difference(lastActivity) > sessionTimeout;
  }
}
