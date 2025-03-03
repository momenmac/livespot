import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  Future<T?> replaceAllWith<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  Future<T?> replaceUntilHome<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => route.isFirst,
      arguments: arguments,
    );
  }

  void goBack<T>([T? result]) {
    return navigatorKey.currentState!.pop(result);
  }

  void popUntilHome() {
    navigatorKey.currentState!.popUntil((route) => route.isFirst);
  }
}
