import 'package:flutter/material.dart';
import 'dart:developer' as developer;

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
    } else if (route == null) {
      // Handle cases where the stack might be empty after removal/pop
      _currentRouteName = null;
      developer.log('NAV OBSERVER: Route became null (stack likely empty?)',
          name: 'RouteObserver');
    } else {
      // Optional: Log if a route without a name is encountered after the initial one
      // developer.log('NAV OBSERVER: Encountered route without a name: ${route.runtimeType}', name: 'RouteObserver');
    }
  }
}
