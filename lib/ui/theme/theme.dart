import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/theme/appbar_theme.dart';
import 'package:flutter_application_2/ui/theme/bottom_sheet_theme.dart';
import 'package:flutter_application_2/ui/theme/elevated_button_theme.dart';
import 'package:flutter_application_2/ui/theme/text_button_theme.dart';
import 'package:flutter_application_2/ui/theme/text_form_field_theme.dart';
import 'package:flutter_application_2/ui/theme/text_theme.dart';

class TAppTheme {
  TAppTheme._();

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: ThemeConstants.primaryColor, brightness: Brightness.light),
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    primaryColor: ThemeConstants.primaryColor,
    scaffoldBackgroundColor: ThemeConstants.lightBackgroundColor,
    useMaterial3: true,
    textTheme: TTextTheme.lightTextTheme,
    elevatedButtonTheme: TElevatedButtonTheme.lightElevatedButtonTheme,
    appBarTheme: TAppBarTheme.lightAppBarTheme,
    bottomSheetTheme: TBottomSheetTheme.lightBottomSheetTheme,
    inputDecorationTheme: TTextFormFieldTheme.lightTextFormFieldTheme,
    textButtonTheme: TTextButtonTheme.lightTextButtonTheme,
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: ThemeConstants.primaryColor, brightness: Brightness.dark),
    fontFamily: 'Poppins',
    primaryColor: ThemeConstants.primaryColor,
    scaffoldBackgroundColor: ThemeConstants.darkBackgroundColor,
    useMaterial3: true,
    textTheme: TTextTheme.darkTextTheme,
    elevatedButtonTheme: TElevatedButtonTheme.darkElevatedButtonTheme,
    appBarTheme: TAppBarTheme.darkAppBarTheme,
    bottomSheetTheme: TBottomSheetTheme.darkBottomSheetTheme,
    inputDecorationTheme: TTextFormFieldTheme.darkTextFormFieldTheme,
    textButtonTheme: TTextButtonTheme.darkTextButtonTheme,
  );
}
