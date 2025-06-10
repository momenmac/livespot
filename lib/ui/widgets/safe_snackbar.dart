import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// A utility class that handles showing SnackBars with unique hero tags to avoid conflicts
class SafeSnackBar {
  static String _generateUniqueKey() => const Uuid().v4();

  /// Shows a standard message SnackBar
  static void show(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
    IconData? icon,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
      icon: icon,
    );
  }

  /// Shows a success message SnackBar with green background and check icon
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      duration: duration,
      action: action,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows an error message SnackBar with red background and error icon
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      duration: duration,
      action: action,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error_outline,
    );
  }

  /// Shows an info message SnackBar with blue background and info icon
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      duration: duration,
      action: action,
      backgroundColor: Colors.blue.shade700,
      icon: Icons.info_outline,
    );
  }

  static void _showSnackBar({
    required BuildContext context,
    required String message,
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
    IconData? icon,
  }) {
    final String uniqueKey = _generateUniqueKey();
    final mediaQuery = MediaQuery.of(context);
    final isLargeScreen = mediaQuery.size.width > 600;

    // Calculate top margin to position at the top
    final topMargin = mediaQuery.padding.top + 16.0;

    // Hide any existing SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show new SnackBar with unique key to avoid Hero tag conflicts
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: ValueKey(uniqueKey),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration ?? const Duration(seconds: 3),
        action: action ??
            SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: topMargin,
          left: isLargeScreen ? 32.0 : 16.0,
          right: isLargeScreen ? 32.0 : 16.0,
          bottom: mediaQuery.size.height - topMargin - 80, // Position at top
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }
}
