import 'package:flutter/material.dart';

class TCheckboxTheme {
  TCheckboxTheme._();

  static final CheckboxThemeData lightCheckboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.all(Colors.blue),
    checkColor: WidgetStateProperty.all(Colors.white),
    overlayColor: WidgetStateProperty.all(Colors.blue),
    splashRadius: 24,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final darkCheckboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.all(Colors.blue),
    checkColor: WidgetStateProperty.all(Colors.white),
    overlayColor: WidgetStateProperty.all(Colors.blue),
    splashRadius: 24,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
