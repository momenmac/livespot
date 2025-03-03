import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class TElevatedButtonTheme {
  TElevatedButtonTheme._();

  static final lightElevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 0,
    foregroundColor: ThemeConstants.lightBackgroundColor,
    backgroundColor: ThemeConstants.primaryColor,
    disabledBackgroundColor: ThemeConstants.greyLight,
    disabledForegroundColor: ThemeConstants.grey,
    padding: EdgeInsets.symmetric(vertical: 16),
    side: BorderSide(
      color: ThemeConstants.primaryColor,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ));

  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 0,
    foregroundColor: ThemeConstants.lightBackgroundColor,
    backgroundColor: ThemeConstants.primaryColor,
    disabledBackgroundColor: ThemeConstants.greyLight,
    disabledForegroundColor: ThemeConstants.grey,
    padding: EdgeInsets.symmetric(vertical: 16),
    side: BorderSide(
      color: ThemeConstants.primaryColor,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ));
}
