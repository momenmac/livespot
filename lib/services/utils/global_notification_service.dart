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

  // Keep track of active notifications to prevent duplicates
  final Set<String> _activeNotifications = <String>{};

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

    final navigatorContext = NavigationService().navigatorKey.currentContext;
    if (navigatorContext == null) {
      debugPrint(
          '[GlobalNotificationService] Navigator context is null, cannot show snackbar');
      return;
    }

    // Find the root ScaffoldMessenger
    final scaffoldMessenger = ScaffoldMessenger.of(navigatorContext);

    // Mark this notification as active
    _activeNotifications.add(notificationId);

    // Create the snackbar
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor),
      ),
      duration: duration,
      backgroundColor: backgroundColor,
      behavior: behavior,
      margin: margin,
      dismissDirection:
          isDismissible ? DismissDirection.horizontal : DismissDirection.none,
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onActionPressed,
              textColor: textColor,
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
