import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';

class TAppBarTheme {
  TAppBarTheme._();

  static AppBarTheme lightAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: ThemeConstants.black),
    titleTextStyle: TextStyle(
      color: ThemeConstants.black,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    actionsIconTheme: IconThemeData(color: ThemeConstants.black),
  );

  static AppBarTheme darkAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: ThemeConstants.lightBackgroundColor),
    titleTextStyle: TextStyle(
      color: ThemeConstants.lightBackgroundColor,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    actionsIconTheme: IconThemeData(color: ThemeConstants.lightBackgroundColor),
  );
}
