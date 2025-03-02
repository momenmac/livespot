import 'dart:async';

import 'package:flutter/material.dart';

/// Helper extension for safer setState calls
extension SafeState<T extends StatefulWidget> on State<T> {
  /// Calls setState only if the widget is still mounted.
  ///
  /// Usage:
  /// ```dart
  /// safeSetState(() {
  ///   _myVariable = newValue;
  /// });
  /// ```
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
}

/// Helper mixin for safely canceling timers
mixin AutoDisposeTimerMixin<T extends StatefulWidget> on State<T> {
  final List<Timer> _timers = [];

  /// Creates a timer that will be automatically disposed when the widget is
  Timer createTimer(Duration duration, void Function() callback) {
    final timer = Timer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Creates a periodic timer that will be automatically disposed
  Timer createPeriodicTimer(Duration duration, void Function(Timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _timers.add(timer);
    return timer;
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
