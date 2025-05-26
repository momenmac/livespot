import 'package:flutter/material.dart';

class AnimatedActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;

  const AnimatedActionButton({
    super.key,
    required this.child,
    this.onTap,
    this.gradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.boxShadow,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: widget.onTap != null ? _onTapDown : null,
            onTapUp: widget.onTap != null ? _onTapUp : null,
            onTapCancel: widget.onTap != null ? _onTapCancel : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: widget.borderRadius,
                boxShadow: _isPressed
                    ? widget.boxShadow
                        ?.map((shadow) => shadow.copyWith(
                              blurRadius: shadow.blurRadius * 0.5,
                              offset: shadow.offset * 0.5,
                            ))
                        .toList()
                    : widget.boxShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
