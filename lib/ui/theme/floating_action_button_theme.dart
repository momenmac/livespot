import 'package:flutter/material.dart';

class FloatingActionButtonTheme {
  FloatingActionButtonTheme._();

  static final zoomButtonTheme = FloatingActionButtonThemeData(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    hoverColor: const Color(0xFFF4F4F4),
    focusColor: const Color(0xFFF4F4F4),
    // ignore: deprecated_member_use
    splashColor: const Color(0xFFBFBEC2).withOpacity(0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(
        color: Color(0xFFC8C8C8), // Dark gray border
        width: 1.5,
      ),
    ),
  );
}
