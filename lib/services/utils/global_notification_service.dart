import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';

/// A global notification service that ensures snackbars and notifications
/// are shown only once across the entire app, regardless of split layout
/// or multiple Navigator contexts.
class GlobalNotificationService {
  // Singleton instance
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  // Global key for ScaffoldMessenger - this is an alternative way to access ScaffoldMessenger
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Keep track of active notifications to prevent duplicates
  final Set<String> _activeNotifications = <String>{};

  // Access the current ScaffoldMessenger through the key if NavigationService fails
  ScaffoldMessengerState? get _fallbackScaffoldMessenger =>
      scaffoldMessengerKey.currentState;

  /// Shows a snackbar using the root navigator context to avoid duplicates
  /// in split-screen layouts with multiple Navigator widgets.
  void showSnackBar({
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? textColor,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    EdgeInsets? margin,
    bool isDismissible = true,
  }) {
    // Create a unique identifier for this notification
    final notificationId = '${message}_${actionLabel ?? ''}';

    // Prevent duplicate notifications
    if (_activeNotifications.contains(notificationId)) {
      return;
    }

    // Try to get a valid context for showing the SnackBar
    final navigatorContext = NavigationService().navigatorKey.currentContext;
    ScaffoldMessengerState? scaffoldMessenger;

    // Try to find a valid ScaffoldMessenger
    if (navigatorContext != null) {
      try {
        scaffoldMessenger = ScaffoldMessenger.of(navigatorContext);
      } catch (e) {
        debugPrint(
            '[GlobalNotificationService] Failed to get ScaffoldMessenger from context: $e');
      }
    }

    // If no scaffoldMessenger from navigatorContext, try the fallback key
    if (scaffoldMessenger == null) {
      scaffoldMessenger = scaffoldMessengerKey.currentState;
      if (scaffoldMessenger != null) {
        debugPrint(
            '[GlobalNotificationService] Using fallback ScaffoldMessenger');
      }
    }

    // If still no scaffoldMessenger, log error and exit
    if (scaffoldMessenger == null) {
      debugPrint(
          '[GlobalNotificationService] No ScaffoldMessenger available, cannot show snackbar');
      return;
    }

    // Mark this notification as active
    _activeNotifications.add(notificationId);

    // Calculate proper margins to ensure the SnackBar is visible on screen
    final horizontalMargin = 16.0;

    // Create the snackbar with proper margins (CANNOT use both margin and width together)
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor ?? Colors.white),
      ),
      duration: duration,
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      // Position at top of screen
      margin: margin ??
          EdgeInsets.only(
            left: horizontalMargin,
            top: 16.0 +
                (navigatorContext != null
                    ? MediaQuery.of(navigatorContext).padding.top
                    : 0),
            right: horizontalMargin,
          ),
      dismissDirection:
          isDismissible ? DismissDirection.horizontal : DismissDirection.none,
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onActionPressed,
              textColor: textColor ?? Colors.blue,
            )
          : null,
    );

    // Show the snackbar and handle cleanup
    scaffoldMessenger.showSnackBar(snackBar).closed.then((_) {
      // Remove from active notifications when it's dismissed
      _activeNotifications.remove(notificationId);
    });
  }

  /// Shows a success snackbar with green background
  void showSuccess(String message,
      {String? actionLabel, VoidCallback? onActionPressed}) {
    showSnackBar(
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: Colors.green.shade600,
      textColor: Colors.white,
    );
  }

  /// Shows an error snackbar with red background
  void showError(String message,
      {String? actionLabel, VoidCallback? onActionPressed}) {
    showSnackBar(
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
      duration: const Duration(seconds: 6),
    );
  }

  /// Shows an info snackbar with blue background
  void showInfo(String message,
      {String? actionLabel, VoidCallback? onActionPressed}) {
    showSnackBar(
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
    );
  }

  /// Shows a warning snackbar with orange background
  void showWarning(String message,
      {String? actionLabel, VoidCallback? onActionPressed}) {
    showSnackBar(
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: Colors.orange.shade600,
      textColor: Colors.white,
    );
  }

  /// Clears all active notifications
  void clearAll() {
    final navigatorContext = NavigationService().navigatorKey.currentContext;
    if (navigatorContext != null) {
      ScaffoldMessenger.of(navigatorContext).clearSnackBars();
    }
    _activeNotifications.clear();
  }

  /// Removes a specific notification from tracking (useful for programmatic dismissal)
  void removeNotification(String message, {String? actionLabel}) {
    final notificationId = '${message}_${actionLabel ?? ''}';
    _activeNotifications.remove(notificationId);
  }
}
