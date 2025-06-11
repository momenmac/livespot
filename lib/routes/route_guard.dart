import 'package:flutter/material.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

/// Route Guard to protect routes based on authentication status
class RouteGuard {
  static final List<String> _protectedRoutes = [
    AppRoutes.home,
    AppRoutes.messages,
    AppRoutes.camera,
    AppRoutes.map,
  ];

  static final List<String> _authRoutes = [
    AppRoutes.login,
    AppRoutes.createAccount,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.initial,
  ];

  static final List<String> _publicRoutes = [
    AppRoutes.networkTest,
  ];

  // Navigation debounce mechanism
  static String? _lastProcessedRoute;
  static DateTime? _lastNavigationTime;
  static const Duration _navigationDebounceDelay = Duration(milliseconds: 100);

  /// Reset the navigation debounce - call this when navigation completes successfully
  static void resetNavigationDebounce() {
    _lastProcessedRoute = null;
    _lastNavigationTime = null;
  }

  static bool isProtectedRoute(String routeName) {
    return _protectedRoutes.contains(routeName);
  }

  static bool isAuthRoute(String routeName) {
    return _authRoutes.contains(routeName);
  }

  static bool isPublicRoute(String routeName) {
    return _publicRoutes.contains(routeName);
  }

  static Future<bool> isAuthenticated() async {
    final sessionManager = SessionManager();

    // If session manager is already initialized, use its state
    if (sessionManager.isInitialized) {
      return sessionManager.isAuthenticated;
    }

    // Wait for session manager to initialize (with a timeout)
    int attempts = 0;
    while (!sessionManager.isInitialized && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // After waiting, check authentication status
    return sessionManager.isAuthenticated;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final String? routeName = settings.name;
    final args = settings.arguments;

    if (routeName == null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AppRoutes.routes[AppRoutes.initial]!({}),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (BuildContext context) {
        handleRouteSecurity(context, routeName);
        return _getRouteWidget(routeName, args, context);
      },
    );
  }

  static void handleRouteSecurity(BuildContext context, String routeName) {
    // CRITICAL FIX: If we're accessing the verification screen, don't process security checks at all
    // This prevents endless redirects when users are already on the verification screen
    if (routeName == AppRoutes.verifyEmail) {
      return;
    }

    // More aggressive debouncing to prevent rapid navigation cycles
    final now = DateTime.now();
    if (_lastNavigationTime != null &&
        now.difference(_lastNavigationTime!) <
            const Duration(milliseconds: 1000)) {
      return;
    }

    // Check if we're already processing this same route
    if (_lastProcessedRoute == routeName) {
      return;
    }

    _lastNavigationTime = now;

    // Use a longer delay to allow route transitions to fully complete
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!context.mounted) {
        _lastProcessedRoute = null;
        return;
      }

      try {
        final bool isAuthenticated = await RouteGuard.isAuthenticated();
        final NavigationService nav = NavigationService();
        final sessionManager = SessionManager();

        // Get current route more reliably
        String? currentRoute;
        try {
          final currentContext = nav.navigatorKey.currentContext;
          if (currentContext != null) {
            final modalRoute = ModalRoute.of(currentContext);
            currentRoute = modalRoute?.settings.name;
          }
          // Fallback to navigation service if modal route is null
          currentRoute ??= nav.currentRoute;
        } catch (e) {
          print('🔒 RouteGuard: Error getting current route: $e');
          currentRoute = nav.currentRoute;
        }

        print(
            '🔒 RouteGuard: Checking route $routeName (current: $currentRoute, authenticated: $isAuthenticated)');

        // CRITICAL: If current route is verification screen, don't redirect again
        if (currentRoute == AppRoutes.verifyEmail) {
          print(
              '🔒 RouteGuard: Currently on verification screen, avoiding redirect loops');
          _lastProcessedRoute = routeName;
          return;
        }

        // Update processed route to prevent repeated processing
        _lastProcessedRoute = routeName;

        // Exit early if already at the target route
        if (currentRoute == routeName) {
          print(
              '🔒 RouteGuard: Already at target route $routeName, no action needed');
          return;
        }

        // Handle public routes first
        if (isPublicRoute(routeName)) {
          print('🔒 RouteGuard: Public route $routeName, allowing access');
          return;
        }

        // Handle different authentication scenarios
        if (!isAuthenticated) {
          // User not authenticated
          if (isProtectedRoute(routeName)) {
            print(
                '🔒 RouteGuard: Unauthorized access to $routeName, redirecting to login');
            if (context.mounted) {
              try {
                GlobalNotificationService()
                    .showWarning("Please login to access this feature");
              } catch (e) {
                print('⚠️ Could not show login required message: $e');
              }
            }
            _performNavigation(() => nav.replaceAllWith(AppRoutes.login));
          }
          // For unauthenticated users accessing auth routes, allow it
          return;
        }

        // User is authenticated
        if (isAuthRoute(routeName)) {
          // Allow authenticated users to access forgot password and reset password routes
          if (routeName == AppRoutes.forgotPassword ||
              routeName == AppRoutes.resetPassword) {
            print(
                '🔒 RouteGuard: Authenticated user accessing password reset route $routeName, allowing access');
            return;
          }

          // For other auth routes, redirect to home if email is verified
          if (sessionManager.isEmailVerified) {
            print(
                '🔒 RouteGuard: Verified user accessing auth route $routeName, redirecting to home');
            if (currentRoute != AppRoutes.home) {
              _performNavigation(() => nav.replaceTo(AppRoutes.home));
            }
          } else {
            // Unverified user accessing auth routes (except verify email) - redirect to verification
            // ONLY redirect if not already on verification screen
            if (routeName != AppRoutes.verifyEmail) {
              print(
                  '🔒 RouteGuard: Unverified user accessing auth route $routeName, redirecting to verification');
              _performNavigation(() => nav.replaceTo(AppRoutes.verifyEmail));
            }
          }
        } else if (isProtectedRoute(routeName)) {
          // Authenticated user accessing protected routes
          if (sessionManager.isEmailVerified) {
            // Email verified, allow access to protected routes
            print(
                '🔒 RouteGuard: Verified user accessing protected route $routeName, allowing access');
          } else {
            // Email not verified, redirect to verification
            print(
                '🔒 RouteGuard: Unverified user accessing protected route $routeName, redirecting to verification');
            _performNavigation(() => nav.replaceTo(AppRoutes.verifyEmail));
          }
        } else {
          // Authenticated user accessing other routes - check email verification
          if (!sessionManager.isEmailVerified) {
            print(
                '🔒 RouteGuard: Unverified user, redirecting to email verification');
            _performNavigation(() => nav.replaceTo(AppRoutes.verifyEmail));
          }
        }
      } catch (e) {
        print('🔒 RouteGuard: Error in security check: $e');
        _lastProcessedRoute = null;
      }
    });
  }

  /// Perform navigation with proper cleanup
  static void _performNavigation(VoidCallback navigationAction) {
    // Reset processed route before navigation to allow new route to be processed
    _lastProcessedRoute = null;
    try {
      navigationAction();
    } catch (e) {
      print('🔒 RouteGuard: Error during navigation: $e');
    }
  }

  /// Get the widget for a route
  static Widget _getRouteWidget(
      String routeName, dynamic args, BuildContext context) {
    // Check for exact route match first
    final routeBuilder = AppRoutes.routes[routeName];
    if (routeBuilder != null) {
      if (args != null) {
        return routeBuilder(args);
      }
      return routeBuilder({});
    }

    // Handle dynamic routes that don't have exact matches
    if (routeName.startsWith('/messages/') &&
        routeName.length > '/messages/'.length) {
      // This is a dynamic conversation route like /messages/{conversationId}
      // Extract the conversation ID and navigate to the messages page
      final conversationId = routeName.substring('/messages/'.length);
      print(
          '🔗 Handling dynamic message route: $routeName, conversationId: $conversationId');

      // Return the MessagesPage (the key in the routes map is '/messages' with the slash)
      final messagesBuilder = AppRoutes.routes['/messages'];
      if (messagesBuilder != null) {
        print(
            '🔗 Successfully found messages route builder, creating MessagesPage with conversationId: $conversationId');
        return messagesBuilder({'conversationId': conversationId});
      } else {
        print('❌ Could not find messages route builder in AppRoutes.routes');
        print('Available routes: ${AppRoutes.routes.keys.toList()}');
      }
    }

    return Scaffold(
      body: Center(
        child: Text("Route not found: $routeName"),
      ),
    );
  }
}
