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
    // Ensure the color scheme uses our primary color as the seed for all components
    colorScheme: ColorScheme.fromSeed(
      seedColor: ThemeConstants.primaryColor,
      brightness: Brightness.light,
      primary: ThemeConstants.primaryColor,
      // Explicitly set common colors to ensure consistency
      secondary: ThemeConstants.primaryColor,
      error: ThemeConstants.red,
    ),
    // Set primarySwatch for older components that don't use ColorScheme
    primarySwatch: MaterialColor(ThemeConstants.primaryColor.toARGB32(), {
      50: ThemeConstants.primaryColor.withAlpha(26),
      100: ThemeConstants.primaryColor.withAlpha(51),
      200: ThemeConstants.primaryColor.withAlpha(77),
      300: ThemeConstants.primaryColor.withAlpha(102),
      400: ThemeConstants.primaryColor.withAlpha(128),
      500: ThemeConstants.primaryColor.withAlpha(153),
      600: ThemeConstants.primaryColor.withAlpha(179),
      700: ThemeConstants.primaryColor.withAlpha(204),
      800: ThemeConstants.primaryColor.withAlpha(230),
      900: ThemeConstants.primaryColor,
    }),
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
    bottomAppBarTheme: TNavigationTheme.navigationBarTheme,
    iconTheme: TNavigationTheme.navigationBarItemThemeLight,
    floatingActionButtonTheme: TNavigationTheme.floatingActionButtonLight,
    cardTheme: TNotificationTheme.notificationCardThemeLight,
    // Configure date picker theme to use primary color
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
  );

  static ThemeData darkTheme = ThemeData(
    // Same approach for dark theme
    colorScheme: ColorScheme.fromSeed(
      seedColor: ThemeConstants.primaryColor,
      brightness: Brightness.dark,
      primary: ThemeConstants.primaryColor,
      secondary: ThemeConstants.primaryColor,
      error: ThemeConstants.red,
    ),
    // Set primarySwatch for older components
    primarySwatch: MaterialColor(ThemeConstants.primaryColor.toARGB32(), {
      50: ThemeConstants.primaryColor.withAlpha(25),
      100: ThemeConstants.primaryColor.withAlpha(51),
      200: ThemeConstants.primaryColor.withAlpha(77),
      300: ThemeConstants.primaryColor.withAlpha(102),
      400: ThemeConstants.primaryColor.withAlpha(127),
      500: ThemeConstants.primaryColor.withAlpha(153),
      600: ThemeConstants.primaryColor.withAlpha(179),
      700: ThemeConstants.primaryColor.withAlpha(204),
      800: ThemeConstants.primaryColor.withAlpha(229),
      900: ThemeConstants.primaryColor,
    }),
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
    bottomAppBarTheme: TNavigationTheme.navigationBarThemeDark,
    iconTheme: TNavigationTheme.navigationBarItemThemeDark,
    floatingActionButtonTheme: TNavigationTheme.floatingActionButtonDarke,
    cardTheme: TNotificationTheme.notificationCardThemeDark,

    // Dark mode date picker theme
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
  );
}
