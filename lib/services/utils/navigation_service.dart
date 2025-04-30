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
  String? _lastNavigationTarget;
  static const _minNavigationInterval =
      Duration(milliseconds: 800); // Increased from 500ms
  static const _generalThrottleInterval =
      Duration(milliseconds: 300); // Increased from 200ms

  // Track navigations in progress to prevent overlapping navigations
  bool _isNavigating = false;

  // Method to reset navigation throttling state - use with caution
  void resetNavigationThrottling() {
    developer.log('⚠️ Navigation throttling flags reset',
        name: 'NavigationService');
    _lastNavigationTime = null;
    _lastNavigationTarget = null;
    _isNavigating = false;
  }

  // Check if we should throttle navigation
  bool _shouldThrottleNavigation([String? targetRoute]) {
    final now = DateTime.now();

    // If we're already in a navigation operation, always throttle
    if (_isNavigating) {
      developer.log('Navigation throttled: Already navigating',
          name: 'NavigationService');
      return true;
    }

    if (_lastNavigationTime != null) {
      final timeSinceLastNav = now.difference(_lastNavigationTime!);

      // If it's the same target route and navigation happened recently, throttle it
      if (targetRoute != null &&
          targetRoute == _lastNavigationTarget &&
          timeSinceLastNav < _minNavigationInterval) {
        developer.log(
            'Navigation throttled: Too many navigation requests to $targetRoute (last navigation was ${timeSinceLastNav.inMilliseconds}ms ago)',
            name: 'NavigationService');
        return true;
      }

      // General throttling for any navigation
      if (timeSinceLastNav < _generalThrottleInterval) {
        developer.log(
            'Navigation throttled: Navigation requests too frequent (${timeSinceLastNav.inMilliseconds}ms since last navigation)',
            name: 'NavigationService');
        return true;
      }
    }

    _lastNavigationTime = now;
    _lastNavigationTarget = targetRoute;
    return false;
  }

  String? _currentRoute; // Store the last route set

  // Getter for the current route name with added debugging
  String? get currentRoute {
    final observerRoute = AppRouteObserver.currentRouteName;
    String? modalRouteName;

    // Attempt to get route from ModalRoute at the time of access
    final currentState = navigatorKey.currentState;
    if (currentState != null && currentState.context.mounted) {
      try {
        modalRouteName = ModalRoute.of(currentState.context)?.settings.name;
      } catch (e) {
        // ModalRoute.of can fail if context is not right, ignore error for logging purpose
      }
    }

    developer.log(
      'NAV SERVICE: currentRoute getter called. Observer reports: "$observerRoute", ModalRoute reports: "$modalRouteName"',
      name: 'NavigationService',
    );

    // Prefer observer, fallback to local cache
    return observerRoute ?? _currentRoute;
  }

  // Add this setter to allow route observer to update the current route
  void setCurrentRoute(String route) {
    developer.log('NAV SERVICE: setCurrentRoute called with "$route"',
        name: 'NavigationService');
    _currentRoute = route;
  }

  // Navigate to a new route
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation(routeName)) return Future.value(null);

    // Check if we're already at this route
    if (_currentRoute == routeName) {
      developer.log('Navigation redundant: Already at $routeName',
          name: 'NavigationService');
      return Future.value(null);
    }

    _isNavigating = true;
    return navigator!
        .pushNamed(
      routeName,
      arguments: arguments,
    )
        .then((value) {
      _isNavigating = false;
      return value as T?;
    }).catchError((e) {
      _isNavigating = false;
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    });
  }

  // Replace current route
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation(routeName)) return Future.value(null);

    // Check if we're already at this route
    if (_currentRoute == routeName) {
      developer.log('Navigation redundant: Already at $routeName',
          name: 'NavigationService');
      return Future.value(null);
    }

    _isNavigating = true;
    return navigator!
        .pushReplacementNamed(
      routeName,
      arguments: arguments,
    )
        .then((value) {
      _isNavigating = false;
      return value as T?;
    }).catchError((e) {
      _isNavigating = false;
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    });
  }

  // Replace all routes
  Future<T?> replaceAllWith<T>(String routeName, {Object? arguments}) {
    // Enhanced throttling check for critical operations
    if (_shouldThrottleNavigation(routeName)) {
      developer.log(
          '⚠️ Critical navigation throttled: replaceAllWith to $routeName',
          name: 'NavigationService');
      return Future.value(null);
    }

    // Extra safety check for duplicate navigation
    if (_currentRoute == routeName) {
      developer.log('⚠️ Navigation redundant: Already at $routeName',
          name: 'NavigationService');
      return Future.value(null);
    }

    try {
      // Set the _lastNavigationTarget before the operation to prevent race conditions
      _lastNavigationTarget = routeName;
      _lastNavigationTime = DateTime.now();
      _isNavigating = true;

      developer.log('✅ Executing replaceAllWith to $routeName',
          name: 'NavigationService');

      return navigator!
          .pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
        arguments: arguments,
      )
          .then((value) {
        _isNavigating = false;
        return value as T?;
      }).catchError((e) {
        _isNavigating = false;
        developer.log('⚠️ Navigation error: $e', name: 'NavigationService');
        return null;
      });
    } catch (e) {
      _isNavigating = false;
      developer.log('⚠️ Navigation error: $e', name: 'NavigationService');
      return Future.value(null);
    }
  }

  // Replace routes until home or a specific route
  Future<T?> replaceUntilHome<T>(String routeName, {Object? arguments}) {
    if (_shouldThrottleNavigation(routeName)) return Future.value(null);

    // Check if we're already at this route
    if (_currentRoute == routeName) {
      developer.log('Navigation redundant: Already at $routeName',
          name: 'NavigationService');
      return Future.value(null);
    }

    _isNavigating = true;
    return navigator!
        .pushNamedAndRemoveUntil(
      routeName,
      (route) => route.isFirst,
      arguments: arguments,
    )
        .then((value) {
      _isNavigating = false;
      return value as T?;
    }).catchError((e) {
      _isNavigating = false;
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    });
  }

  // Go back to previous screen
  void goBack<T>([T? result]) {
    if (_shouldThrottleNavigation()) return;

    _isNavigating = true;
    try {
      navigator!.pop(result);
    } finally {
      _isNavigating = false;
    }
  }

  // Go back to the home screen
  void popUntilHome() {
    if (_shouldThrottleNavigation()) return;

    _isNavigating = true;
    try {
      navigator!.popUntil((route) => route.isFirst);
    } finally {
      _isNavigating = false;
    }
  }
}
