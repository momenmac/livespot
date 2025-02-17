import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class TTextTheme {
  TTextTheme._();

  static TextTheme lightTextTheme = TextTheme(
    labelSmall: GoogleFonts.nunitoSans(
        fontSize: 15.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.black),
    labelLarge: GoogleFonts.nunitoSans(
        fontSize: 22.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.black),
    labelMedium: GoogleFonts.poppins(
        fontSize: 13.83,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.black),
    // headlineLarge: TextStyle().copyWith(
    //     fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.black),
    // headlineMedium: TextStyle().copyWith(
    //     fontSize: 24.0, fontWeight: FontWeight.w600, color: Colors.black),
    // headlineSmall: TextStyle().copyWith(
    //     fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.black),

    bodySmall: GoogleFonts.nunitoSans(
        fontSize: 10.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.black),

    bodyMedium: GoogleFonts.nunitoSans(
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.black),

    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 19.0,
      fontWeight: FontWeight.w300,
      color: ThemeConstants.black,
    ),

    titleSmall: GoogleFonts.raleway(
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.black,
        letterSpacing: -0.16),

    titleMedium: GoogleFonts.raleway(
        fontSize: 21.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.black,
        letterSpacing: -0.16),

    titleLarge: GoogleFonts.raleway(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.black,
        letterSpacing: -0.28),

    displayLarge: GoogleFonts.raleway(
        fontSize: 52.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.black,
        letterSpacing: -0.52),
  );
  // Dark Theme
  static TextTheme darkTextTheme = TextTheme(
    labelSmall: GoogleFonts.nunitoSans(
        fontSize: 15.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.lightBackgroundColor),
    labelLarge: GoogleFonts.nunitoSans(
        fontSize: 22.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.lightBackgroundColor),
    labelMedium: GoogleFonts.poppins(
        fontSize: 13.83,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.lightBackgroundColor),
    bodySmall: GoogleFonts.nunitoSans(
        fontSize: 10.0,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.lightBackgroundColor),
    bodyMedium: GoogleFonts.nunitoSans(
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.lightBackgroundColor),
    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 19.0,
      fontWeight: FontWeight.w300,
      color: ThemeConstants.lightBackgroundColor,
    ),
    titleSmall: GoogleFonts.raleway(
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.lightBackgroundColor,
        letterSpacing: -0.16),
    titleMedium: GoogleFonts.raleway(
        fontSize: 21.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.lightBackgroundColor,
        letterSpacing: -0.16),
    titleLarge: GoogleFonts.raleway(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.lightBackgroundColor,
        letterSpacing: -0.28),
    displayLarge: GoogleFonts.raleway(
        fontSize: 52.0,
        fontWeight: FontWeight.bold,
        color: ThemeConstants.lightBackgroundColor,
        letterSpacing: -0.52),
  );
}
