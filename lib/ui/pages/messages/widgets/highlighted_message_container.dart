import 'package:flutter/material.dart';

/// A container that highlights its content briefly to draw attention
class HighlightedMessageContainer extends StatefulWidget {
  final Widget child;
  final bool isHighlighted;
  final Color highlightColor;

  const HighlightedMessageContainer({
    super.key,
    required this.child,
    required this.isHighlighted,
    this.highlightColor = const Color(0xFFFFDA6B),
  });

  @override
  State<HighlightedMessageContainer> createState() =>
      _HighlightedMessageContainerState();
}

class _HighlightedMessageContainerState
    extends State<HighlightedMessageContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.isHighlighted) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant HighlightedMessageContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isHighlighted
                ? widget.highlightColor.withOpacity(_animation.value * 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
