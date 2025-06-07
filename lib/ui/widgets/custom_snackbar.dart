import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';

void showCustomSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;
  final isLargeScreen = screenSize.width > 700;

  // Calculate bottom margin to avoid FAB and navigation bar
  final bottomMargin =
      (isLargeScreen ? 20.0 : 100.0) + 16.0; // Added base padding

  // Use the global notification service to prevent duplicates
  GlobalNotificationService().showSnackBar(
    message: message,
    backgroundColor: isError ? Colors.red.shade600 : null,
    textColor: isError ? Colors.white : null,
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.only(
      bottom: bottomMargin,
      left: isLargeScreen ? screenSize.width * 0.5 + 20 : 20,
      right: 20,
      top: 20,
    ),
    duration: const Duration(seconds: 2),
  );
}
