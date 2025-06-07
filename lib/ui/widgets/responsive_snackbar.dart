import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';

class ResponsiveSnackBar {
  static void showError({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    GlobalNotificationService().showError(message);
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    GlobalNotificationService().showSuccess(message);
  }

  static void showInfo({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    GlobalNotificationService().showInfo(message);
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    GlobalNotificationService().showWarning(message);
  }
}
