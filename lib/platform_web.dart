// This is a stub implementation of Platform class for web platform
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;

  // Add any other Platform properties you're using
  static String get operatingSystem => 'web';
  static String get localeName => 'en_US';

  // Add other platform properties as needed
}
