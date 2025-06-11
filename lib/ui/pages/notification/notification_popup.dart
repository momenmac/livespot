import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';

/// A global set to track active notification popups and prevent duplicates
final Set<String> _activePopups = <String>{};

class NotificationPopup extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Color backgroundColor;
  final Color textColor;

  const NotificationPopup({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.onTap,
    this.onDismiss,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Dismiss button
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              color: textColor.withOpacity(0.6)),
                          onPressed: onDismiss,
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
                        child: Row(
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                color: textColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress indicator
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 4),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.transparent,
                              color: textColor.withOpacity(0.2),
                              minHeight: 2,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Static method to show notification popup
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
    Map<String, dynamic>? data,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
    Duration duration = const Duration(seconds: 4),
  }) {
    try {
      // Create unique identifier to prevent duplicates
      final popupId = '${title}_${message}';

      // Prevent duplicate popups
      if (_activePopups.contains(popupId)) {
        debugPrint('Duplicate notification popup prevented: $popupId');
        return;
      }

      // Try to find an overlay. If not available, fall back to ScaffoldMessenger
      OverlayState? overlayState;
      try {
        overlayState = Overlay.of(context);
      } catch (e) {
        debugPrint(
            'No Overlay widget found. Falling back to ScaffoldMessenger: $e');
        // Fall back to SnackBar when Overlay is not available
        try {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final mediaQuery = MediaQuery.of(context);

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: duration,
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  scaffoldMessenger.hideCurrentSnackBar();
                  onDismiss?.call();
                },
              ),
              margin: EdgeInsets.only(
                left: 16.0,
                top: 16.0 + mediaQuery.padding.top, // Position from top
                right: 16.0,
                bottom: 0.0, // Set to 0 to position at top
              ),
            ),
          );
        } catch (snackbarError) {
          debugPrint('Also failed to show SnackBar: $snackbarError');
          // Final fallback - try GlobalNotificationService directly
          try {
            GlobalNotificationService().showInfo(message);
          } catch (finalError) {
            debugPrint('All notification methods failed: $finalError');
          }
        }
        return;
      }

      OverlayEntry? entry;

      // Mark popup as active
      _activePopups.add(popupId);

      entry = OverlayEntry(
        builder: (context) {
          return NotificationPopup(
            title: title,
            message: message,
            icon: icon,
            backgroundColor: Theme.of(context).cardColor,
            textColor:
                Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            onTap: () {
              entry?.remove();
              _activePopups.remove(popupId);
              onTap?.call();
            },
            onDismiss: () {
              entry?.remove();
              _activePopups.remove(popupId);
              onDismiss?.call();
            },
          );
        },
      );

      // Insert the entry into the overlay
      overlayState.insert(entry);

      // Auto dismiss after specified duration
      Future.delayed(duration, () {
        try {
          entry?.remove();
          _activePopups.remove(popupId);
        } catch (e) {
          debugPrint('Error removing overlay entry: $e');
        }
      });
    } catch (e) {
      debugPrint('Error showing notification popup: $e');
      // Last resort - directly use GlobalNotificationService
      try {
        // Show a fallback notification
        GlobalNotificationService().showInfo(message);
      } catch (finalError) {
        debugPrint(
            'Failed to show notification through any method: $finalError');
      }
    }
  }
}
