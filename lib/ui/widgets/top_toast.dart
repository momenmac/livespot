import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/widgets/safe_hero.dart'; // Import SafeHero

class TopToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;
  // Add a timestamp-based ID generator for unique Hero tags
  static int _uniqueId = 0;
  static String _generateUniqueHeroTag() =>
      'toast_hero_tag_${DateTime.now().microsecondsSinceEpoch}_${_uniqueId++}';

  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    // Safely hide any existing toast first
    _safelyHideToast();

    // Verify we have a valid overlay using maybeOf instead of nullOk
    final overlay = Overlay.maybeOf(context);
    if (overlay == null || !context.mounted) {
      print(
          '⚠️ TopToast: Overlay not available or context not mounted, skipping toast');
      return;
    }

    // Generate a unique Hero tag for this toast instance
    final uniqueHeroTag = _generateUniqueHeroTag();

    // Create and insert the new overlay entry
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        heroTag: uniqueHeroTag,
      ),
    );

    try {
      overlay.insert(_overlayEntry!);

      // Set timer to automatically hide the toast
      _timer = Timer(duration, () {
        _safelyHideToast();
      });
    } catch (e) {
      print('⚠️ TopToast: Error showing toast: $e');
      _overlayEntry = null;
    }
  }

  // Safely hide toast to prevent errors
  static void _safelyHideToast() {
    _timer?.cancel();
    _timer = null;

    try {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    } catch (e) {
      print('⚠️ TopToast: Error hiding toast: $e');
      _overlayEntry = null;
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData? icon;
  final String heroTag;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.heroTag,
    this.icon,
  });

  @override
  _ToastWidgetState createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 10;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(_animation),
          // Use SafeHero instead of Hero to prevent duplicate tag issues
          child: SafeHero(
            tag: widget.heroTag,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: widget.backgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
