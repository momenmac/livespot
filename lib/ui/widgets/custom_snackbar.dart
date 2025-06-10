import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';

void showCustomSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;
  final isLargeScreen = screenSize.width > 700;

  // Position snackbar at the top instead of bottom to avoid duplication issues
  final topMargin = mediaQuery.padding.top + 16.0; // Below status bar

  // Use the global notification service to prevent duplicates
  GlobalNotificationService().showSnackBar(
    message: message,
    backgroundColor: isError ? Colors.red.shade600 : null,
    textColor: isError ? Colors.white : null,
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.only(
      top: topMargin,
      left: isLargeScreen ? screenSize.width * 0.5 + 20 : 20,
      right: 20,
      bottom: screenSize.height - topMargin - 80, // Position at top
    ),
    duration: const Duration(seconds: 2),
  );
}
