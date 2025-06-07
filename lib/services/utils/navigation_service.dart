import 'package:flutter/material.dart';

/// A simplified navigation service that prioritizes reliability over complexity
class NavigationService {
  // Singleton instance
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Variables to track navigation state
  String? _currentRoute;
  String? _currentModalRoute;
  String? _cachedRoute;
  String? _activeChatId; // Track the active chat conversation

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Method to check if a chat is active by ID
  bool isChatActive(String conversationId) {
    return _activeChatId == conversationId;
  }

  // Method to set active chat ID
  void setActiveChatId(String? chatId) {
    debugPrint(
        "[NavigationService] Active chat ID changed: $_activeChatId -> $chatId");
    _activeChatId = chatId;
  }

  // Get active chat ID
  String? get activeChatId => _activeChatId;

  // Set the current route from the route observer
  void setRoute(String route) {
    debugPrint("[NavigationService] Route set to: $route");
    _currentRoute = route;
  }

  // Alias for setRoute to support legacy code
  void setCurrentRoute(String route) {
    setRoute(route);
  }

  // Set the current modal route (for bottom sheets, dialogs)
  void setModalRoute(String? route) {
    _currentModalRoute = route;
    debugPrint("[NavigationService] Modal route set to: $route");
  }

  // Remember a route for later
  void cacheRoute(String route) {
    _cachedRoute = route;
  }

  // Get the current route
  String? get currentRoute {
    final result = _currentModalRoute ?? _currentRoute ?? _cachedRoute;
    debugPrint(
        "[NavigationService] Current route: observer=$_currentRoute, modal=$_currentModalRoute, cached=$_cachedRoute");
    return result;
  }

  // Push a new route onto the navigation stack
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    debugPrint("[NavigationService] 🔥 NAVIGATION REQUEST: $routeName");
    debugPrint("[NavigationService] 🔥 Arguments: $arguments");
    debugPrint(
        "[NavigationService] 🔥 Navigator state exists: ${navigatorKey.currentState != null}");
    debugPrint("[NavigationService] 🔥 Current route: $_currentRoute");

    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] ❌ WARNING: navigatorKey.currentState is null, cannot navigate to $routeName');
      return Future.value(null);
    }

    debugPrint("[NavigationService] ✅ Executing pushNamed for: $routeName");
    return navigatorKey.currentState!
        .pushNamed(routeName, arguments: arguments);
  }

  // Replace the current route with a new one
  Future<dynamic> replaceTo(String routeName, {Object? arguments}) {
    debugPrint("[NavigationService] Replacing with: $routeName");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot replaceTo $routeName');
      return Future.value(null);
    }
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  // Replace the entire stack with a single new route
  Future<dynamic> replaceAllWith(String routeName, {Object? arguments}) {
    debugPrint("[NavigationService] Replacing all routes with $routeName");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot replaceAllWith $routeName');
      return Future.value(null);
    }
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (_) => false, // Remove all previous routes
      arguments: arguments,
    );
  }

  // Navigate to a route, removing all routes until home
  Future<dynamic> replaceUntilHome(String routeName, {Object? arguments}) {
    debugPrint("[NavigationService] Replacing until home with: $routeName");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot replaceUntilHome $routeName');
      return Future.value(null);
    }
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => route.settings.name == '/home', // Keep routes until home
      arguments: arguments,
    );
  }

  // Reset navigation stack to initial route
  void reset() {
    debugPrint("[NavigationService] Resetting navigation stack");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot reset navigation stack');
      return;
    }
    navigatorKey.currentState!.popUntil((route) => route.isFirst);
    _currentRoute = '/';
    _currentModalRoute = null;
    _cachedRoute = null;
    _activeChatId = null;
  }

  // Pop the current route
  void goBack() {
    debugPrint("[NavigationService] Going back");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot goBack');
      return;
    }
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop();
    }
  }

  // Pop until a specific route
  void popUntil(String routeName) {
    debugPrint("[NavigationService] Popping until $routeName");
    if (navigatorKey.currentState == null) {
      debugPrint(
          '[NavigationService] WARNING: navigatorKey.currentState is null, cannot popUntil $routeName');
      return;
    }
    navigatorKey.currentState!.popUntil(ModalRoute.withName(routeName));
  }
}
