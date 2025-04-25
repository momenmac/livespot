import 'package:flutter/material.dart';
import 'route_observer.dart'; // Import the new observer
import 'dart:developer' as developer; // Import developer for logging

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

  // Getter for the current route name with added debugging
  String? get currentRoute {
    final observerRoute = AppRouteObserver.currentRouteName;
    String? modalRouteName;

    // Attempt to get route from ModalRoute at the time of access
    final currentState = navigatorKey.currentState;
    if (currentState != null &&
        currentState.context != null &&
        currentState.context.mounted) {
      try {
        modalRouteName = ModalRoute.of(currentState.context)?.settings.name;
      } catch (e) {
        // ModalRoute.of can fail if context is not right, ignore error for logging purpose
      }
    }

    // Log both values for comparison
    developer.log(
      'NAV SERVICE: currentRoute getter called. Observer reports: "$observerRoute", ModalRoute reports: "$modalRouteName"',
      name: 'NavigationService',
    );

    // Primarily trust the observer, but logs will show differences
    return observerRoute;
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
