import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class TTextButtonTheme {
  TTextButtonTheme._();

  static TextButtonThemeData lightTextButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
    textStyle: GoogleFonts.nunitoSans(
        fontSize: 15, fontWeight: FontWeight.w300, color: ThemeConstants.black),
    foregroundColor: ThemeConstants.black,
    backgroundColor: ThemeConstants.lightBackgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
  ));
  static TextButtonThemeData darkTextButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
    textStyle: GoogleFonts.nunitoSans(
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: ThemeConstants.lightBackgroundColor),
    foregroundColor: ThemeConstants.lightBackgroundColor,
    backgroundColor: ThemeConstants.darkBackgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
  ));
}
