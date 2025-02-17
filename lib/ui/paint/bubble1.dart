import 'package:flutter/material.dart';

class Bubble1 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    Path path = Path();

    // Path number 1
    bool isDarkMode = MediaQueryData.fromView(WidgetsBinding.instance.window)
            .platformBrightness ==
        Brightness.dark;
    paint.color =
        isDarkMode ? Color.fromARGB(255, 31, 31, 30) : Color(0xffF2F5FE);
    path = Path();
    path.lineTo(size.width * 0.49, size.height * 0.42);
    path.cubicTo(size.width * 0.38, size.height * 0.76, -0.15,
        size.height * 0.43, -0.22, size.height * 0.17);
    path.cubicTo(-0.3, -0.08, -0.2, -0.31, size.width * 0.08, -0.41);
    path.cubicTo(size.width * 0.36, -0.5, size.width * 0.59, -0.35,
        size.width * 0.72, -0.14);
    path.cubicTo(size.width * 0.84, size.height * 0.06, size.width * 0.6,
        size.height * 0.07, size.width * 0.49, size.height * 0.42);
    path.cubicTo(size.width * 0.49, size.height * 0.42, size.width * 0.49,
        size.height * 0.42, size.width * 0.49, size.height * 0.42);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
