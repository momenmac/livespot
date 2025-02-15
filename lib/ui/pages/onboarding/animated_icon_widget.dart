import 'package:flutter/material.dart';

class AnimatedIconWidget extends StatefulWidget {
  final IconData icon;
  final double size;
  final Duration duration;
  final Color color;

  const AnimatedIconWidget({
    super.key,
    required this.icon,
    required this.size,
    required this.duration,
    required this.color,
  });

  @override
  AnimatedIconWidgetState createState() => AnimatedIconWidgetState();
}

class AnimatedIconWidgetState extends State<AnimatedIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(8),
        child: Icon(widget.icon, size: widget.size, color: Colors.white),
      ),
    );
  }
}
