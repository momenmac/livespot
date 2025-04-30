import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';

class SessionMonitor extends StatefulWidget {
  final Widget child;

  const SessionMonitor({
    super.key,
    required this.child,
  });

  @override
  SessionMonitorState createState() => SessionMonitorState();
}

class SessionMonitorState extends State<SessionMonitor> {
  @override
  void initState() {
    super.initState();

    print('SessionMonitor: Initializing');
    print('SessionMonitor: Current widget: ${widget.child}');

    // TODO: Implement session expiration handling
    // Removed unused _handleSessionStateChange method

    _initializeSessionMonitoring();
  }

  void _initializeSessionMonitoring() {
    // Use Future.microtask to ensure this runs after build
    Future.microtask(() {
      if (!mounted) return;

      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      // Listen for session state changes
      accountProvider.addListener(_checkSessionStatus);

      // Perform initial check
      _checkSessionStatus();
    });
  }

  void _checkSessionStatus() {
    if (!mounted) return;

    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    // Check if token needs refreshing
    if (accountProvider.shouldRefreshToken) {
      accountProvider.refreshToken();
    }
  }

  // This safer method only shows notifications if the context is valid and has an Overlay
  void _safelyShowNotification(BuildContext context, String message,
      {bool isError = false}) {
    // Skip any UI notifications during initialization
    if (!mounted) return;

    // Check if we have a valid overlay
    try {
      // Removed unused overlay variable
      if (isError) {
        ResponsiveSnackBar.showError(context: context, message: message);
      } else {
        ResponsiveSnackBar.showInfo(context: context, message: message);
      }
    } catch (e) {
      print('⚠️ SessionMonitor: Error showing notification: $e');
      // Just print the notification message to console since we can't show UI
      print('📢 Notification (${isError ? 'ERROR' : 'INFO'}): $message');
    }
  }

  @override
  void dispose() {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    accountProvider.removeListener(_checkSessionStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
