import 'package:flutter/material.dart';

/// Utility class to handle keyboard-related operations
class KeyboardUtils {
  /// Dismisses the keyboard if it is currently shown
  static void dismissKeyboard(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Wrap a widget with a GestureDetector that dismisses keyboard on tap
  static Widget dismissKeyboardOnTap(
      {required Widget child, BuildContext? context}) {
    return GestureDetector(
      onTap: () {
        if (context != null) {
          dismissKeyboard(context);
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: child,
    );
  }
}
