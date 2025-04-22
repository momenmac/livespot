import 'package:flutter/material.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/auth/session_manager.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
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
    Future.microtask(() async {
      final bool isAuthenticated = await RouteGuard.isAuthenticated();
      final NavigationService nav = NavigationService();

      if (isPublicRoute(routeName)) {
        return;
      }

      if (isProtectedRoute(routeName) && !isAuthenticated) {
        print(
            '🔒 Unauthorized access attempt to $routeName, redirecting to login');

        // Only show warning if the context is still valid and mounted
        if (context.mounted) {
          try {
            // Check if Scaffold is available
            if (ScaffoldMessenger.maybeOf(context) != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Please login to access this feature"),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            print('⚠️ Could not show login required message: $e');
          }
        }
        nav.replaceAllWith(AppRoutes.login);
      } else if (isAuthRoute(routeName) && isAuthenticated) {
        print(
            '🔒 Authenticated user trying to access $routeName, redirecting to home');
        nav.replaceTo(AppRoutes.home);
      }
    });
  }

  /// Get the widget for a route
  static Widget _getRouteWidget(
      String routeName, dynamic args, BuildContext context) {
    final routeBuilder = AppRoutes.routes[routeName];
    if (routeBuilder != null) {
      if (args != null) {
        return routeBuilder(args);
      }
      return routeBuilder({});
    }
    return Scaffold(
      body: Center(
        child: Text("Route not found: $routeName"),
      ),
    );
  }
}
