import 'package:flutter/material.dart';
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
