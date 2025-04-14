import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/widgets/top_toast.dart';

class ResponsiveSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool isError = false,
  }) {
    // First check if the context is valid and has an overlay
    try {
      // Use safer method to check for overlay availability
      final overlay = Overlay.maybeOf(context);
      if (overlay != null && context.mounted) {
        TopToast.show(
          context: context,
          message: message,
          backgroundColor: backgroundColor,
          duration: duration,
          icon: isError ? Icons.error_outline : null,
        );
      } else {
        // Fallback to regular SnackBar if Overlay is not available
        try {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(message),
                duration: duration,
                backgroundColor: backgroundColor,
                action: action,
              ),
            );
          }
        } catch (e) {
          // If even SnackBar fails, just print to console
          print('📢 Notification fallback: $message');
        }
      }
    } catch (e) {
      print('⚠️ ResponsiveSnackBar: Error showing notification: $e');
      print('📢 Message: $message');
    }
  }

  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: ThemeConstants.red,
      duration: duration,
      action: action,
      isError: true,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: ThemeConstants.orange,
      duration: duration,
      action: action,
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: ThemeConstants.green,
      duration: duration,
      action: action,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: ThemeConstants.primaryColor,
      duration: duration,
      action: action,
    );
  }
}
