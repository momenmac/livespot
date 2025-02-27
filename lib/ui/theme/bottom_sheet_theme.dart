import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';

class TBottomSheetTheme {
  TBottomSheetTheme._();

  static final lightBottomSheetTheme = BottomSheetThemeData(
    backgroundColor: ThemeConstants.lightBackgroundColor,
    modalBackgroundColor: ThemeConstants.lightBackgroundColor,
    elevation: 0,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
  );

  static final darkBottomSheetTheme = BottomSheetThemeData(
    backgroundColor: ThemeConstants.darkBackgroundColor,
    modalBackgroundColor: ThemeConstants.darkCardColor,
    elevation: 0,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
  );
}
