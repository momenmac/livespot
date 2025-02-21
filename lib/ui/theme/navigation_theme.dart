import 'package:flutter/material.dart';
import '../../core/constants/theme_constants.dart';

class NavigationTheme {
  NavigationTheme._();

  static final navigationBarTheme = BottomAppBarTheme(
    color: const Color.fromARGB(233, 220, 220, 220),
    shape: CircularNotchedRectangle(),
    elevation: 8.0,
  );

  static final navigationBarItemTheme = IconThemeData(
    color: ThemeConstants.navigationActiveColor,
    size: 24,
  );

  static final cameraButtonTheme = FloatingActionButtonThemeData(
    backgroundColor: ThemeConstants.navigationCameraColor,
    elevation: 6.0,
    hoverColor: ThemeConstants.navigationHoverColor,
    focusColor: ThemeConstants.navigationPressColor,
  );
}
