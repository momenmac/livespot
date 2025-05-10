import 'package:flutter/material.dart';

/// A registry to manage unique Hero tags across the app
/// This helps prevent duplicate hero tag issues
class HeroTagRegistry {
  static final Map<String, int> _tagCounts = {};
  
  /// Reset the registry, typically called when rebuilding the app
  static void reset() {
    _tagCounts.clear();
  }
  
  /// Get a unique tag based on a base tag
  static String getUniqueTag(String baseTag) {
    if (!_tagCounts.containsKey(baseTag)) {
      _tagCounts[baseTag] = 0;
    } else {
      _tagCounts[baseTag] = _tagCounts[baseTag]! + 1;
    }
    return '$baseTag-${_tagCounts[baseTag]}';
  }
  
  /// Check if a tag already exists
  static bool hasTag(String baseTag) {
    return _tagCounts.containsKey(baseTag);
  }
}

/// A safer implementation of Hero widget that prevents duplicate hero tag issues
class SafeHero extends StatelessWidget {
  final String tag;
  final Widget child;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool transitionOnUserGestures;
  
  const SafeHero({
    super.key,
    required this.tag,
    required this.child,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final uniqueTag = HeroTagRegistry.getUniqueTag(tag);
    
    return Hero(
      tag: uniqueTag,
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      transitionOnUserGestures: transitionOnUserGestures,
      child: child,
    );
  }
}
