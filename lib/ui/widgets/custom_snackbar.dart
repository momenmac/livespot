import 'package:flutter/material.dart';

void showCustomSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;
  final isLargeScreen = screenSize.width > 700;
  final bottomPadding =
      mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom;

  // Calculate bottom margin to avoid FAB and navigation bar
  final bottomMargin = bottomPadding + (isLargeScreen ? 20 : 100);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        left: isLargeScreen ? screenSize.width * 0.5 + 20 : 20,
        right: 20,
        top: 20,
      ),
      width: isLargeScreen ? 400 : null,
      duration: const Duration(seconds: 2),
    ),
  );
}
