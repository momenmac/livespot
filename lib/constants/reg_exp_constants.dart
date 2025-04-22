import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class RegExpConstants {
  RegExpConstants._();

  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  static final RegExp uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp numberRegex = RegExp(r'[0-9]');
}
