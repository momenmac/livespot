import 'package:flutter/material.dart';

/// A service that shows toast messages at the top of the screen
/// This avoids all the issues with SnackBar positioning
class TopToast {
  static OverlayEntry? _currentToast;
  static bool _isVisible = false;
  static const Duration _defaultDuration = Duration(seconds: 3);

  /// Show a toast message at the top of the screen
  static void show({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    Duration duration = _defaultDuration,
    IconData? icon,
  }) {
    // Remove any existing toast first
    _hideToast();

    // Create new toast
    _currentToast = _createToastEntry(
      context: context,
      message: message,
      backgroundColor: backgroundColor ?? Colors.black.withOpacity(0.7),
      icon: icon,
    );

    // Show the toast
    Overlay.of(context).insert(_currentToast!);
    _isVisible = true;

    // Automatically hide the toast after specified duration
    Future.delayed(duration, () {
      if (_isVisible) {
        _hideToast();
      }
    });
  }

  /// Create a toast overlay entry
  static OverlayEntry _createToastEntry({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    IconData? icon,
  }) {
    final screenSize = MediaQuery.of(context).size;
    // Position the toast slightly lower if it's a success message
    final topPadding = MediaQuery.of(context).padding.top +
        (backgroundColor.value == Colors.green.shade700.value ? 60.0 : 10.0);

    return OverlayEntry(
      builder: (context) => Positioned(
        top: topPadding,
        left: screenSize.width * 0.1,
        width: screenSize.width * 0.8,
        child: Material(
          color: Colors.transparent,
          // Increasing elevation to ensure it shows above other UI elements
          elevation: 10,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            // Slow down the animation slightly
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(
                      0, (1 - value) * -30), // Increased animation distance
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14), // Slightly larger padding
              decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 24), // Larger icon
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15, // Slightly larger font
                        fontWeight: FontWeight.w500, // Semibold text
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _hideToast,
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.9),
                      size: 18, // Larger close icon
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hide the current toast if it exists
  static void _hideToast() {
    if (_currentToast != null) {
      _currentToast!.remove();
      _currentToast = null;
      _isVisible = false;
    }
  }
}
