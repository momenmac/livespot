import 'package:flutter/material.dart';

class AnimatedSpeechBubble extends StatefulWidget {
  final Widget child;
  final Color bubbleColor;
  final double cornerRadius;
  final double arrowWidth;
  final double arrowHeight;
  final EdgeInsets padding;
  final double elevation;
  final Color shadowColor;
  final Alignment arrowAlignment;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedSpeechBubble({
    super.key,
    required this.child,
    this.bubbleColor = Colors.white,
    this.cornerRadius = 12.0,
    this.arrowWidth = 16.0,
    this.arrowHeight = 12.0,
    this.padding = const EdgeInsets.all(16.0),
    this.elevation = 4.0,
    this.shadowColor = Colors.black45,
    this.arrowAlignment = Alignment.bottomCenter,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
  });

  @override
  State<AnimatedSpeechBubble> createState() => _AnimatedSpeechBubbleState();
}

class _AnimatedSpeechBubbleState extends State<AnimatedSpeechBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: widget.animationCurve),
      ),
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: widget.arrowAlignment == Alignment.topCenter
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: SpeechBubble(
              child: widget.child,
              bubbleColor: widget.bubbleColor,
              cornerRadius: widget.cornerRadius,
              arrowWidth: widget.arrowWidth,
              arrowHeight: widget.arrowHeight,
              padding: widget.padding,
              elevation: widget.elevation,
              shadowColor: widget.shadowColor,
              arrowAlignment: widget.arrowAlignment,
            ),
          ),
        );
      },
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final Widget child;
  final Color bubbleColor;
  final double cornerRadius;
  final double arrowWidth;
  final double arrowHeight;
  final EdgeInsets padding;
  final double elevation;
  final Color shadowColor;
  final Alignment arrowAlignment;

  const SpeechBubble({
    super.key,
    required this.child,
    this.bubbleColor = Colors.white,
    this.cornerRadius = 12.0,
    this.arrowWidth = 16.0,
    this.arrowHeight = 12.0,
    this.padding = const EdgeInsets.all(16.0),
    this.elevation = 4.0,
    this.shadowColor = Colors.black45,
    this.arrowAlignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The bubble container
          Container(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: elevation,
                  offset: Offset(0, elevation / 2),
                ),
              ],
            ),
            padding: padding,
            child: child,
          ),
          
          // The arrow pointing to the marker
          if (arrowAlignment == Alignment.bottomCenter)
            Positioned(
              bottom: -arrowHeight + 1, // Small overlap to avoid gaps
              left: 0,
              right: 0,
              child: Center(
                child: CustomPaint(
                  size: Size(arrowWidth, arrowHeight),
                  painter: _TrianglePainter(
                    color: bubbleColor,
                    strokeColor: bubbleColor,
                  ),
                ),
              ),
            )
          else if (arrowAlignment == Alignment.topCenter)
            Positioned(
              top: -arrowHeight + 1,
              left: 0,
              right: 0,
              child: Center(
                child: CustomPaint(
                  size: Size(arrowWidth, arrowHeight),
                  painter: _TrianglePainter(
                    color: bubbleColor,
                    strokeColor: bubbleColor,
                    pointDown: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final Color color;
  final bool pointDown;
  final double strokeWidth;
  final Paint _fillPaint;
  final Paint _strokePaint;

  _TrianglePainter({
    required this.color,
    required this.strokeColor,
    this.pointDown = true,
    this.strokeWidth = 1.0,
  })  : _fillPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill,
        _strokePaint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    
    if (pointDown) {
      // Arrow pointing down
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
    } else {
      // Arrow pointing up
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    }
    
    // Draw fill and stroke
    canvas.drawPath(path, _fillPaint);
    canvas.drawPath(path, _strokePaint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.pointDown != pointDown ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
