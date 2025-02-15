import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboardingCompleted', true);
  }

  static Future<bool> setLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool('isLoggedIn', true);
  }
}
