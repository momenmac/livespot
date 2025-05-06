// This file provides web-compatible implementations for Platform
// Used as a conditional import for web platform

import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class Platform {
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isFuchsia = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isWindows = false;
  static const bool isWeb = true;

  // Add any additional platform-specific methods needed for web
  static Future<String> get localeName async => 'en_US';
}
