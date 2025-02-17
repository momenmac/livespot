import 'package:flutter/material.dart';

class Bubble2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    Path path = Path();

    // Path number 1

    paint.color = Color(0xff004BFE);
    path = Path();
    path.lineTo(size.width / 2, size.height * 0.09);
    path.cubicTo(size.width * 0.74, -0.2, size.width, size.height * 0.29,
        size.width, size.height * 0.54);
    path.cubicTo(size.width, size.height * 0.8, size.width * 0.78, size.height,
        size.width / 2, size.height);
    path.cubicTo(size.width * 0.23, size.height, -0.03, size.height * 0.81,
        size.width * 0.01, size.height * 0.54);
    path.cubicTo(size.width * 0.04, size.height * 0.28, size.width * 0.27,
        size.height * 0.38, size.width / 2, size.height * 0.09);
    path.cubicTo(size.width / 2, size.height * 0.09, size.width / 2,
        size.height * 0.09, size.width / 2, size.height * 0.09);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
