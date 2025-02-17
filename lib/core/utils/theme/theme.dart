import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/utils/theme/appbar_theme.dart';
import 'package:flutter_application_2/core/utils/theme/bottom_sheet_theme.dart';
import 'package:flutter_application_2/core/utils/theme/elevated_button_theme.dart';
import 'package:flutter_application_2/core/utils/theme/text_theme.dart';

class TAppTheme {
  TAppTheme._();

  static ThemeData lightTheme = ThemeData(
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    useMaterial3: true,
    textTheme: TTextTheme.lightTextTheme,
    elevatedButtonTheme: TElevatedButtonTheme.lightElevatedButtonTheme,
    appBarTheme: TAppBarTheme.lightAppBarTheme,
    bottomSheetTheme: TBottomSheetTheme.lightBottomSheetTheme,
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme:
        ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 180, 216)),
    useMaterial3: true,
  );
}
