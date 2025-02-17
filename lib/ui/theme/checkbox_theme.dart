import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';

class TCheckboxTheme {
  TCheckboxTheme._();

  static final CheckboxThemeData lightCheckboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    checkColor: WidgetStateProperty.all(ThemeConstants.lightBackgroundColor),
    overlayColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    splashRadius: 24,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final darkCheckboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    checkColor: WidgetStateProperty.all(ThemeConstants.lightBackgroundColor),
    overlayColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    splashRadius: 24,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
