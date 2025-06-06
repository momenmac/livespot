import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/theme/appbar_theme.dart';
import 'package:flutter_application_2/ui/theme/bottom_sheet_theme.dart';
import 'package:flutter_application_2/ui/theme/elevated_button_theme.dart';
import 'package:flutter_application_2/ui/theme/notification_theme.dart';
import 'package:flutter_application_2/ui/theme/text_button_theme.dart';
import 'package:flutter_application_2/ui/theme/text_form_field_theme.dart';
import 'package:flutter_application_2/ui/theme/text_theme.dart';
import 'package:flutter_application_2/ui/theme/navigation_theme.dart';

class TAppTheme {
  TAppTheme._();

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: ThemeConstants.primaryColor,
      onPrimary: Colors.white,
      secondary: ThemeConstants.primaryColor,
      onSecondary: Colors.white,
      error: ThemeConstants.red,
      onError: Colors.white,
      surface: ThemeConstants.lightCardColor,
      onSurface: ThemeConstants.black,
    ),
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    primaryColor: ThemeConstants.primaryColor,
    scaffoldBackgroundColor: ThemeConstants.lightBackgroundColor,
    useMaterial3: true,
    textTheme: TTextTheme.lightTextTheme, // Make sure this is correct!
    elevatedButtonTheme: TElevatedButtonTheme.lightElevatedButtonTheme,
    appBarTheme: TAppBarTheme.lightAppBarTheme,
    bottomSheetTheme: TBottomSheetTheme.lightBottomSheetTheme,
    inputDecorationTheme: TTextFormFieldTheme.lightTextFormFieldTheme,
    textButtonTheme: TTextButtonTheme.lightTextButtonTheme,
    bottomAppBarTheme: TNavigationTheme.navigationBarTheme,
    iconTheme: TNavigationTheme.navigationBarItemThemeLight,
    floatingActionButtonTheme: TNavigationTheme.floatingActionButtonLight,
    cardTheme: CardThemeData(
      elevation: TNotificationTheme.notificationCardThemeLight.elevation,
      color: TNotificationTheme.notificationCardThemeLight.color,
      margin: TNotificationTheme.notificationCardThemeLight.margin,
      shape: TNotificationTheme.notificationCardThemeLight.shape,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: ThemeConstants.lightBackgroundColor,
      headerBackgroundColor: ThemeConstants.primaryColor,
      headerForegroundColor: Colors.white,
      todayBackgroundColor:
          WidgetStateProperty.all(ThemeConstants.primaryColor.withAlpha(38)),
      todayForegroundColor:
          WidgetStateProperty.all(ThemeConstants.primaryColor),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ThemeConstants.primaryColor;
        }
        return null;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
    ),
    // Add visualDensity for consistent sizing across platforms
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: ThemeConstants.primaryColor,
      onPrimary: Colors.white,
      secondary: ThemeConstants.primaryColor,
      onSecondary: Colors.white,
      error: ThemeConstants.red,
      onError: Colors.white,
      surface: ThemeConstants.darkCardColor,
      onSurface: Colors.white,
    ),
    fontFamily: 'Poppins',
    primaryColor: ThemeConstants.primaryColor,
    scaffoldBackgroundColor: ThemeConstants.darkBackgroundColor,
    useMaterial3: true,
    textTheme: TTextTheme.darkTextTheme,
    elevatedButtonTheme: TElevatedButtonTheme.darkElevatedButtonTheme,
    appBarTheme: TAppBarTheme.darkAppBarTheme,
    bottomSheetTheme: TBottomSheetTheme.darkBottomSheetTheme,
    cardTheme: CardThemeData(
      elevation: TNotificationTheme.notificationCardThemeDark.elevation,
      color: TNotificationTheme.notificationCardThemeDark.color,
      margin: TNotificationTheme.notificationCardThemeDark.margin,
      shape: TNotificationTheme.notificationCardThemeDark.shape,
    ),
    inputDecorationTheme: TTextFormFieldTheme.darkTextFormFieldTheme,
    textButtonTheme: TTextButtonTheme.darkTextButtonTheme,
    bottomAppBarTheme: TNavigationTheme.navigationBarThemeDark,
    iconTheme: TNavigationTheme.navigationBarItemThemeDark,
    floatingActionButtonTheme: TNavigationTheme.floatingActionButtonDarke,
    datePickerTheme: DatePickerThemeData(
      backgroundColor: ThemeConstants.darkBackgroundColor,
      headerBackgroundColor: ThemeConstants.primaryColor,
      headerForegroundColor: Colors.white,
      todayBackgroundColor:
          WidgetStateProperty.all(ThemeConstants.primaryColor.withAlpha(77)),
      todayForegroundColor:
          WidgetStateProperty.all(ThemeConstants.primaryColor),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ThemeConstants.primaryColor;
        }
        return null;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
