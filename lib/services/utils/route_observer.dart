import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_application_2/services/utils/navigation_service.dart';

class AppRouteObserver extends NavigatorObserver {
  static String? _currentRouteName;

  static String? get currentRouteName => _currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route); // Update with the new route

    // Log details including previous route for context
    developer.log(
      'NAV OBSERVER: Pushed route "${route.settings.name}" (from "${previousRoute?.settings.name}"). Current is now "$_currentRouteName"',
      name: 'RouteObserver',
    );

    // Explicitly set initial route if this is the first push
    if (previousRoute == null && _currentRouteName == null) {
      // If _currentRouteName is still null after _updateRoute, it might be an unnamed initial route.
      // Or, if the initial route IS named (like '/'), _updateRoute should handle it.
      // Let's ensure _updateRoute handles '/' correctly.
      developer.log(
        'NAV OBSERVER: Detected initial push. Route: "${route.settings.name}"',
        name: 'RouteObserver',
      );
      // _updateRoute should already handle setting the name if available.
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateRoute(previousRoute); // Update to the route being returned to
    developer.log(
      'NAV OBSERVER: Popped route "${route.settings.name}". Current is now "$_currentRouteName"',
      name: 'RouteObserver',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateRoute(newRoute);
    developer.log(
      'NAV OBSERVER: Replaced route "${oldRoute?.settings.name}" with "${newRoute?.settings.name}". Current is now "$_currentRouteName"',
      name: 'RouteObserver',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // When removing, the 'previousRoute' might become the current one if it exists
    _updateRoute(previousRoute);
    developer.log(
      'NAV OBSERVER: Removed route "${route.settings.name}". Current might be "$_currentRouteName" (from previous)',
      name: 'RouteObserver',
    );
  }

  void _updateRoute(Route<dynamic>? route) {
    // Only update if the route has settings and a name is provided
    if (route?.settings.name != null) {
      // Handle the root route explicitly if needed, otherwise just assign
      if (route!.settings.name == '/') {
        _currentRouteName = '/'; // Ensure root is captured as '/'
      } else {
        _currentRouteName = route.settings.name;
      }
      
      // Debug the actual widget type to help diagnose routing issues
      developer.log(
        'Route widget type: ${route.settings.name} -> ${route.settings.arguments} -> ${route.navigator?.widget.runtimeType}',
        name: 'RouteObserver',
      );
      
      // Keep NavigationService in sync
      NavigationService().setCurrentRoute(_currentRouteName!);
    } else if (route == null) {
      // Handle cases where the stack might be empty after removal/pop
      _currentRouteName = null;
      developer.log('NAV OBSERVER: Route became null (stack likely empty?)',
          name: 'RouteObserver');
      // Also clear NavigationService route
      NavigationService().setCurrentRoute('/');
    } else {
      // If we have a route but no name, try to infer what it might be
      developer.log('NAV OBSERVER: Encountered route without a name: ${route.runtimeType}', 
          name: 'RouteObserver');
          
      // Attempt to identify the route by widget type when name is missing
      final routeContent = _identifyRouteByContent(route);
      if (routeContent != null) {
        _currentRouteName = routeContent;
        NavigationService().setCurrentRoute(routeContent);
      }
    }
  }
  
  // Helper method to identify routes by their content when the route name is missing
  String? _identifyRouteByContent(Route<dynamic> route) {
    try {
      // Try to extract route info from the route's builder
      final settings = route.settings;
      final content = settings.arguments;
      
      if (content != null) {
        developer.log('Route content: $content', name: 'RouteObserver');
      }
      
      // Use runtimeType to help identify what screen we're on
      developer.log('Route runtime type: ${route.runtimeType}', name: 'RouteObserver');
      
      // If this is a MaterialPageRoute, try to identify the page
      if (route is MaterialPageRoute) {
        final pageWidget = route.builder(route.navigator!.context);
        developer.log('Page widget: ${pageWidget.runtimeType}', name: 'RouteObserver');
        
        // Check for specific page types
        if (pageWidget.toString().contains('LoginScreen')) {
          return '/login';
        } else if (pageWidget.toString().contains('GetStartedScreen')) {
          return '/';
        }
      }
      
      return null;
    } catch (e) {
      developer.log('Error identifying route: $e', name: 'RouteObserver');
      return null;
    }
  }
}
