import 'package:flutter/material.dart';
import 'route_observer.dart';
import 'dart:developer' as developer;

/// A simplified navigation service that prioritizes reliability over complexity
class NavigationService {
  // Singleton pattern
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Navigation key for app-wide navigation
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Navigator state accessor
  NavigatorState? get navigator => navigatorKey.currentState;
  
  // Simple route tracking
  String? _currentRoute;
  
  // Store last navigation time for basic throttling
  DateTime? _lastNavigationTime;
  
  // No more navigating flag - we'll use a simpler approach
  
  // Getter for the current route name - keep it simple
  String? get currentRoute {
    final observerRoute = AppRouteObserver.currentRouteName;
    String? modalRouteName;
    
    try {
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null) {
        modalRouteName = ModalRoute.of(currentContext)?.settings.name;
      }
    } catch (e) {
      // Silently handle error
    }
    
    developer.log(
      'Current route: observer=$observerRoute, modal=$modalRouteName, cached=$_currentRoute',
      name: 'NavigationService',
    );
    
    return modalRouteName ?? observerRoute ?? _currentRoute;
  }
  
  // Method to allow route observer to update the current route
  void setCurrentRoute(String route) {
    _currentRoute = route;
    developer.log('Route set to: $route', name: 'NavigationService');
  }
  
  // Simple direct navigation methods
  
  // Navigate to a new route (push)
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) async {
    if (_shouldThrottle()) {
      developer.log('Navigation throttled for $routeName', name: 'NavigationService');
      return null;
    }
    
    developer.log('Navigating to $routeName', name: 'NavigationService');
    
    try {
      return await navigator?.pushNamed(routeName, arguments: arguments) as T?;
    } catch (e) {
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    } finally {
      _updateNavigationTime();
    }
  }
  
  // Replace current route
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) async {
    if (_shouldThrottle()) {
      developer.log('Navigation throttled for $routeName', name: 'NavigationService');
      return null;
    }
    
    developer.log('Replacing route with $routeName', name: 'NavigationService');
    
    try {
      return await navigator?.pushReplacementNamed(routeName, arguments: arguments) as T?;
    } catch (e) {
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    } finally {
      _updateNavigationTime();
    }
  }
  
  // Replace all routes
  Future<T?> replaceAllWith<T>(String routeName, {Object? arguments}) async {
    if (_shouldThrottle()) {
      developer.log('Navigation throttled for $routeName', name: 'NavigationService');
      return null;
    }
    
    developer.log('Replacing all routes with $routeName', name: 'NavigationService');
    
    try {
      return await navigator?.pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
        arguments: arguments,
      ) as T?;
    } catch (e) {
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    } finally {
      _updateNavigationTime();
    }
  }
  
  // Replace until home
  Future<T?> replaceUntilHome<T>(String routeName, {Object? arguments}) async {
    if (_shouldThrottle()) {
      developer.log('Navigation throttled for $routeName', name: 'NavigationService');
      return null;
    }
    
    developer.log('Replacing routes until home with $routeName', name: 'NavigationService');
    
    try {
      return await navigator?.pushNamedAndRemoveUntil(
        routeName,
        (route) => route.isFirst,
        arguments: arguments,
      ) as T?;
    } catch (e) {
      developer.log('Navigation error: $e', name: 'NavigationService');
      return null;
    } finally {
      _updateNavigationTime();
    }
  }
  
  // Go back (pop) - simplified and robust
  void goBack<T>([T? result]) {
    developer.log('Going back', name: 'NavigationService');
    
    try {
      // Direct navigation without flags
      navigator?.pop(result);
      developer.log('Back navigation executed', name: 'NavigationService');
    } catch (e) {
      developer.log('Back navigation error: $e', name: 'NavigationService');
    }
  }
  
  // Pop until home
  void popUntilHome() {
    developer.log('Popping until home', name: 'NavigationService');
    
    try {
      navigator?.popUntil((route) => route.isFirst);
    } catch (e) {
      developer.log('Pop until home error: $e', name: 'NavigationService');
    }
  }
  
  // Helper methods
  
  // Simple throttling check - prevent navigation faster than 300ms
  bool _shouldThrottle() {
    if (_lastNavigationTime == null) return false;
    
    final now = DateTime.now();
    final diff = now.difference(_lastNavigationTime!);
    return diff.inMilliseconds < 300;
  }
  
  // Update navigation time
  void _updateNavigationTime() {
    _lastNavigationTime = DateTime.now();
  }
  
  // Reset all internal state - can be used as emergency fix
  void reset() {
    developer.log('Navigation service reset', name: 'NavigationService');
    _lastNavigationTime = null;
    // We keep _currentRoute as it may be needed
  }
}
