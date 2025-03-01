import 'package:flutter/material.dart';

/// Maintains a registry of used hero tags to prevent duplicates
class HeroTagRegistry {
  static final Set<String> _usedTags = {};

  /// Generates a unique tag based on the provided base tag
  static String uniqueTag(String baseTag) {
    String tag = baseTag;
    int counter = 0;

    while (_usedTags.contains(tag)) {
      counter++;
      tag = '${baseTag}_$counter';
    }

    _usedTags.add(tag);
    return tag;
  }

  /// Clears all registered tags (use when rebuilding the entire UI)
  static void reset() {
    _usedTags.clear();
  }

  /// Creates a unique hero tag by combining the base tag with a unique identifier
  static Object createWithId(String baseTag, Object uniqueId) {
    return '${baseTag}_$uniqueId';
  }
}

/// A Hero widget that ensures its tag is unique
class SafeHero extends StatefulWidget {
  final String baseTag;
  final Widget child;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool transitionOnUserGestures;

  const SafeHero({
    super.key,
    required this.baseTag,
    required this.child,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
  });

  @override
  State<SafeHero> createState() => _SafeHeroState();
}

class _SafeHeroState extends State<SafeHero> {
  late String _uniqueTag;

  @override
  void initState() {
    super.initState();
    // Create a unique tag for this Hero instance
    _uniqueTag = HeroTagRegistry.uniqueTag(widget.baseTag);
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: _uniqueTag,
      createRectTween: widget.createRectTween,
      flightShuttleBuilder: widget.flightShuttleBuilder,
      placeholderBuilder: widget.placeholderBuilder,
      transitionOnUserGestures: widget.transitionOnUserGestures,
      child: widget.child,
    );
  }
}

/// A Hero widget that ensures its tag is unique using a provided unique ID
class IdBasedHero extends StatelessWidget {
  final String baseTag;
  final Object uniqueId;
  final Widget child;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool transitionOnUserGestures;

  const IdBasedHero({
    super.key,
    required this.baseTag,
    required this.uniqueId,
    required this.child,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: HeroTagRegistry.createWithId(baseTag, uniqueId),
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      transitionOnUserGestures: transitionOnUserGestures,
      child: child,
    );
  }
}
