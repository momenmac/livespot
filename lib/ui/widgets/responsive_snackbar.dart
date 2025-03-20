import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/widgets/top_toast.dart';

/// A responsive SnackBar helper that uses TopToast to avoid positioning issues
class ResponsiveSnackBar {
  /// Show a responsive notification message
  /// This implementation uses TopToast instead of SnackBar to avoid positioning issues
  static void show({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) {
    // Use our custom TopToast instead of the problematic SnackBar
    TopToast.show(
      context: context,
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
      icon: icon,
    );
  }

  /// Shows an error message
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.red.shade700,
      duration: duration,
      icon: Icons.error_outline,
    );
  }

  /// Shows a success message
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green.shade700,
      duration: duration,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows an info message
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.blue.shade700,
      duration: duration,
      icon: Icons.info_outline,
    );
  }

  /// Show a warning SnackBar
  static void showWarning({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
