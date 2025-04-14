import 'package:flutter/material.dart';

class NavigationService {
  // Singleton implementation
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Navigation key for app-wide navigation without context
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Get the navigator state
  NavigatorState? get navigator => navigatorKey.currentState;

  // Add a debounce mechanism to prevent rapid navigation
  DateTime? _lastNavigationTime;
  static const _minNavigationInterval = Duration(milliseconds: 300);

  // Check if we should throttle navigation
  bool _shouldThrottleNavigation() {
    final now = DateTime.now();
    if (_lastNavigationTime != null) {
      final timeSinceLastNav = now.difference(_lastNavigationTime!);
      if (timeSinceLastNav < _minNavigationInterval) {
        print('Navigation throttled: Too many navigation requests');
        return true;
      }
    }
    _lastNavigationTime = now;
    return false;
  }

  // Getter for the current route name
  String? get currentRoute {
    String? currentRouteName;
    // Use the navigatorKey to access the current route settings
    navigatorKey.currentState?.popUntil((route) {
      currentRouteName = route.settings.name;
      return true; // Return true to stop popping
    });
    return currentRouteName;
  }

  // Navigate to a new route
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation()) return Future.value(null);

    return navigator!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  // Replace current route
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation()) return Future.value(null);

    return navigator!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  // Replace all routes
  Future<T?> replaceAllWith<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation()) return Future.value(null);

    return navigator!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  // Replace routes until home or a specific route
  Future<T?> replaceUntilHome<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation()) return Future.value(null);

    return navigator!.pushNamedAndRemoveUntil(
      routeName,
      (route) => route.isFirst,
      arguments: arguments,
    );
  }

  // Go back to previous screen
  void goBack<T>([T? result]) {
    if (_shouldThrottleNavigation()) return;

    navigator!.pop(result);
  }

  // Go back to the home screen
  void popUntilHome() {
    if (_shouldThrottleNavigation()) return;

    navigator!.popUntil((route) => route.isFirst);
  }
}
