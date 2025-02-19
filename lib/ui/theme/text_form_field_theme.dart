import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class TTextFormFieldTheme {
  TTextFormFieldTheme._();

  static InputDecorationTheme lightTextFormFieldTheme = InputDecorationTheme(
      filled: true,
      fillColor: ThemeConstants.textFieldFillColorLight,
      labelStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ThemeConstants.textFieldLabelColorLight),
      errorStyle: TextStyle(color: ThemeConstants.red),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ThemeConstants.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ThemeConstants.red, width: 1.0),
      ));
  static InputDecorationTheme darkTextFormFieldTheme = InputDecorationTheme(
      filled: true,
      fillColor: ThemeConstants.textFieldFillColorDark,
      labelStyle: GoogleFonts.poppins(
          fontSize: 13.83,
          fontWeight: FontWeight.w500,
          color: ThemeConstants.textFieldLabelColorDark),
      errorStyle: TextStyle(color: ThemeConstants.red),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ThemeConstants.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ThemeConstants.red, width: 1.0),
      ));
}
