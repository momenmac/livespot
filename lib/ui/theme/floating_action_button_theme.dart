import 'package:flutter/material.dart';

class FloatingActionButtonTheme {
  FloatingActionButtonTheme._();

  static const FloatingActionButtonThemeData zoomButtonTheme =
      FloatingActionButtonThemeData(
    smallSizeConstraints: BoxConstraints.tightFor(
      width: 40,
      height: 40,
    ),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
}
