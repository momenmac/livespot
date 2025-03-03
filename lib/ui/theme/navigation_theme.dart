import 'package:flutter/material.dart';
import '../../constants/theme_constants.dart';

class TNavigationTheme {
  TNavigationTheme._();

  static final navigationBarTheme = BottomAppBarTheme(
    color: ThemeConstants.greyLight,
    shape: const CircularNotchedRectangle(),
    elevation: 0, // Reduced elevation for modern look
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
  );

  static final navigationBarThemeDark = BottomAppBarTheme(
    color: ThemeConstants.darkCardColor,
    shape: const CircularNotchedRectangle(),
    elevation: 0, // Reduced elevation for modern look
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
  );

  static final navigationBarItemThemeLight = IconThemeData(
    color: ThemeConstants.darkCardColor,
    size: 31,
    opacity: 0.95,
  );
  static final navigationBarItemThemeDark = IconThemeData(
    color: ThemeConstants.greyLight,
    size: 31,
    opacity: 0.95,
  );

  static final floatingActionButtonLight = FloatingActionButtonThemeData(
    backgroundColor: ThemeConstants.primaryColor,
    elevation: 2.0,
    foregroundColor: ThemeConstants.lightBackgroundColor,
    splashColor: ThemeConstants.primaryColor.withAlpha(128),
    hoverColor: ThemeConstants.navigationHoverColor,
    focusColor: ThemeConstants.primaryColor,
    shape: const CircleBorder(),
  );

  static FloatingActionButtonThemeData floatingActionButtonDarke =
      FloatingActionButtonThemeData(
    backgroundColor: ThemeConstants.primaryColor,
    elevation: 2.0,
    foregroundColor: ThemeConstants.darkCardColor,
    splashColor: ThemeConstants.primaryColor.withAlpha(128),
    hoverColor: ThemeConstants.navigationHoverColor,
    focusColor: ThemeConstants.navigationPressColor,
    shape: const CircleBorder(),
  );
}
