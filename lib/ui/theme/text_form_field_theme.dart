import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class TTextFormFieldTheme {
  TTextFormFieldTheme._();

  static InputDecorationTheme lightTextFormFieldTheme = InputDecorationTheme(
    filled: true,
    fillColor: ThemeConstants.textFieldFillColorLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    labelStyle: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.textFieldLabelColorLight),
  );
  static InputDecorationTheme darkTextFormFieldTheme = InputDecorationTheme(
    filled: true,
    fillColor: ThemeConstants.textFieldFillColorDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    labelStyle: GoogleFonts.poppins(
        fontSize: 13.83,
        fontWeight: FontWeight.w500,
        color: ThemeConstants.textFieldLabelColorDark),
  );
}
