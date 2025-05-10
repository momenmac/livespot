import 'package:flutter/material.dart';
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class ThemeConstants {
  ThemeConstants._();
  static const Color primaryColor = Color(0xFF004CFF);
  static const Color primaryColorLight = Color(0xffd9e4ff);
  static const Color primaryColorVeryLight = Color(0xffF2F5FE);
  static const Color green = Color.fromARGB(255, 137, 227, 34);
  static const Color orange = Color(0xFFFE7F00);
  static const Color pink = Color(0xFFF34D75);
  static const Color pinkLight = Color(0xFFFFEBEB);
  static const Color red = Color(0xFFF63C3C);
  static const Color yellow = Color(0xFFECA61B);
  static const Color purple = Color(0xFF9C27B0); // Added purple color
  static const Color black = Color(0xff202020);
  static const Color grey = Color.fromARGB(255, 173, 173, 173);
  static const Color greyLight = Color.fromARGB(255, 245, 245, 245);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color lightCardColor = Color.fromARGB(255, 237, 237, 237);
  static const Color lightBackgroundColor = Color.fromARGB(255, 255, 255, 255);

  static const Color navigationPressColor = Color(0xFF004CFF);
  static const Color navigationActiveColor = Color(0xFF004CFF);
  static const Color navigationHoverColor = Color.fromARGB(73, 0, 76, 255);
  static const Color navigationCameraColor = Color(0xFF004CFF);

  static const textFieldFillColorLight = greyLight;
  static const textFieldLabelColorLight = grey;
  static const textFieldFillColorDark = darkCardColor;
  static const textFieldLabelColorDark = grey;

  static const notificationGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      navigationActiveColor, // Darkest
      primaryColor, // Still dark
      navigationHoverColor, // Getting lighter
    ],
    stops: [0.0, 0.15, 1.0], // Adjusted stops to prevent gaps
  );

  // Add this new static constant
  static const Color darkBackground = Color(0xFF121212);
}
