import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart'; // Add this import
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/route_guard.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';

class SessionMonitor extends StatefulWidget {
  final Widget child;

  const SessionMonitor({super.key, required this.child});

  @override
  SessionMonitorState createState() => SessionMonitorState();
}

class SessionMonitorState extends State<SessionMonitor>
    with WidgetsBindingObserver {
  // Add debounce mechanism
  DateTime? _lastNavigationAttempt;
  String? _currentRouteName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Subscribe to session state changes
    SessionManager().onStateChanged.listen(_handleSessionStateChange);

    // Check routes on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCurrentRoute();
    });
  }

  void _checkCurrentRoute() {
    if (!mounted) return;

    final route = ModalRoute.of(context);

    if (route != null && route.settings.name != null) {
      _currentRouteName = route.settings.name;

      // Check if this route should be protected
      if (_currentRouteName != null &&
          RouteGuard.isProtectedRoute(_currentRouteName!)) {
        RouteGuard.handleRouteSecurity(context, _currentRouteName!);
      }
    }
  }

  void _handleSessionStateChange(SessionState state) {
    if (!mounted) return;

    // Prevent rapid navigation attempts
    final now = DateTime.now();
    if (_lastNavigationAttempt != null &&
        now.difference(_lastNavigationAttempt!) <
            const Duration(milliseconds: 500)) {
      print('⚠️ Ignoring rapid session state navigation');
      return;
    }
    _lastNavigationAttempt = now;

    final NavigationService nav = NavigationService();
    _currentRouteName = ModalRoute.of(context)?.settings.name;

    switch (state) {
      case SessionState.expired:
        // Handle expired session - always redirect to login
        if (_currentRouteName != AppRoutes.login) {
          Future.microtask(() {
            if (mounted && context.mounted) {
              ResponsiveSnackBar.showInfo(
                context: context,
                message: "Your session has expired. Please log in again.",
              );
              nav.replaceAllWith(AppRoutes.login);
            }
          });
        }
        break;

      case SessionState.unauthenticated:
        // Only navigate if we're on a protected route
        if (_currentRouteName != null &&
            RouteGuard.isProtectedRoute(_currentRouteName!) &&
            _currentRouteName != AppRoutes.login) {
          Future.microtask(() {
            if (mounted && context.mounted) {
              ResponsiveSnackBar.showWarning(
                context: context,
                message: "Please login to continue.",
              );
              nav.replaceAllWith(AppRoutes.login);
            }
          });
        }
        break;

      case SessionState.authenticated:
        // If we're on an auth route, navigate to home
        if (_currentRouteName != null &&
            RouteGuard.isAuthRoute(_currentRouteName!) &&
            _currentRouteName != AppRoutes.home) {
          Future.microtask(() {
            if (mounted && context.mounted) {
              nav.replaceTo(AppRoutes.home);
            }
          });
        }
        break;

      default:
        // No automatic navigation for other states
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - verify session
      SessionManager().recordActivity();

      // Refresh token if needed when app resumes - using try/catch to handle potential errors
      try {
        // Using a safer approach with error handling
        SessionManager().verifyAndRefreshTokenIfNeeded().catchError((error) {
          print('Error refreshing token: $error');
          return false;
        });
      } catch (e) {
        print('Token refresh error: $e');
      }

      // Re-check current route when app resumes
      Future.microtask(() {
        _checkCurrentRoute();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
