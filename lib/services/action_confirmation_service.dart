import 'package:flutter/material.dart';
import '../widgets/action_confirmation_dialog.dart';
import 'api/notification_api_service.dart';
import 'utils/global_notification_service.dart';

class ActionConfirmationService {
  // Singleton instance
  static final ActionConfirmationService _instance =
      ActionConfirmationService._internal();
  factory ActionConfirmationService() => _instance;
  ActionConfirmationService._internal();

  // Global navigator key for accessing context
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the service with the navigator key
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    debugPrint('🔧 ActionConfirmationService: Initialized with navigator key');
  }

  /// Process notification data and show confirmation dialog if it's a "still there" notification
  static Future<bool> processNotification({
    required Map<String, dynamic> data,
    required String title,
    required String body,
  }) async {
    try {
      debugPrint('🔍 ActionConfirmationService: Processing notification');
      debugPrint('📝 Title: $title');
      debugPrint('💬 Body: $body');
      debugPrint('📊 Data: $data');

      // Check if this is a "still there" notification
      final notificationType = data['type']?.toString().toLowerCase() ?? '';
      final actionType = data['action_type']?.toString().toLowerCase() ?? '';

      final isStillThereNotification = notificationType == 'still_there' ||
          actionType == 'still_there' ||
          title.toLowerCase().contains('still there') ||
          body.toLowerCase().contains('still there');

      if (!isStillThereNotification) {
        debugPrint('❌ Not a "still there" notification, skipping dialog');
        return false;
      }

      debugPrint('✅ Detected "still there" notification, showing dialog');

      // Extract dialog information from notification data
      final dialogTitle =
          data['dialog_title']?.toString() ?? 'Action Confirmation';
      final dialogDescription = data['dialog_description']?.toString() ??
          'Is this action still there?';
      final imageUrl = data['image_url']?.toString();

      // Get the current context
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('❌ No context available, cannot show dialog');
        return false;
      }

      // Show the confirmation dialog
      final result = await ActionConfirmationDialog.show(
        context: context,
        title: dialogTitle,
        description: dialogDescription,
        imageUrl: imageUrl,
      );

      debugPrint('✅ Dialog result: $result');

      // Handle the response
      if (result == true) {
        await _handleYesResponse(data);
      } else if (result == false) {
        await _handleNoResponse(data);
      }

      return result ?? false;
    } catch (e, stackTrace) {
      debugPrint('❌ Error processing notification: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Handle "Yes" response - action is still there
  static Future<void> _handleYesResponse(Map<String, dynamic> data) async {
    try {
      debugPrint('✅ User confirmed action is still there');

      // Send confirmation to Django backend
      final confirmationId = data['confirmation_id']?.toString();
      if (confirmationId != null) {
        debugPrint(
            '📝 Confirmation ID: $confirmationId - confirming as still there');

        final success = await NotificationApiService.respondToEventConfirmation(
          confirmationId: confirmationId,
          isStillThere: true,
          responseMessage: 'User confirmed event is still happening',
        );

        if (success) {
          _showFeedbackSnackBar('Event confirmed as still happening',
              isSuccess: true);
        } else {
          _showFeedbackSnackBar('Failed to send confirmation',
              isSuccess: false);
        }
      } else {
        _showFeedbackSnackBar('Event confirmed locally', isSuccess: true);
      }
    } catch (e) {
      debugPrint('❌ Error handling Yes response: $e');
      _showFeedbackSnackBar('Failed to confirm event', isSuccess: false);
    }
  }

  /// Handle "No" response - action is no longer there
  static Future<void> _handleNoResponse(Map<String, dynamic> data) async {
    try {
      debugPrint('❌ User confirmed action is no longer there');

      // Send removal confirmation to Django backend
      final confirmationId = data['confirmation_id']?.toString();
      if (confirmationId != null) {
        debugPrint(
            '📝 Confirmation ID: $confirmationId - confirming as no longer there');

        final success = await NotificationApiService.respondToEventConfirmation(
          confirmationId: confirmationId,
          isStillThere: false,
          responseMessage: 'User confirmed event is no longer happening',
        );

        if (success) {
          _showFeedbackSnackBar('Event marked as no longer happening',
              isSuccess: true);
        } else {
          _showFeedbackSnackBar('Failed to send response', isSuccess: false);
        }
      } else {
        _showFeedbackSnackBar('Event marked as cancelled locally',
            isSuccess: true);
      }
    } catch (e) {
      debugPrint('❌ Error handling No response: $e');
      _showFeedbackSnackBar('Failed to update event status', isSuccess: false);
    }
  }

  /// Show feedback snackbar
  static void _showFeedbackSnackBar(String message, {required bool isSuccess}) {
    if (isSuccess) {
      GlobalNotificationService().showSuccess(message);
    } else {
      GlobalNotificationService().showError(message);
    }
  }

  /// Check if a notification is a "still there" type
  static bool isStillThereNotification(
      Map<String, dynamic> data, String title, String body) {
    final notificationType = data['type']?.toString().toLowerCase() ?? '';
    final actionType = data['action_type']?.toString().toLowerCase() ?? '';

    return notificationType == 'still_there' ||
        actionType == 'still_there' ||
        title.toLowerCase().contains('still there') ||
        body.toLowerCase().contains('still there');
  }

  /// Test method to simulate a "still there" notification
  static Future<void> testStillThereNotification() async {
    debugPrint('🧪 Testing "still there" notification');

    final testData = {
      'type': 'still_there',
      'action_id': 'test_action_123',
      'dialog_title': 'Action Confirmation',
      'dialog_description': 'Is this action still there?',
      'image_url': 'https://via.placeholder.com/150/0000FF/FFFFFF?text=Action',
    };

    await processNotification(
      data: testData,
      title: 'Still There Check',
      body: 'Please confirm if this action is still available',
    );
  }
}
