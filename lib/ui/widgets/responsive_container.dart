import 'package:flutter/material.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;

  const ResponsiveContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth =
            constraints.maxWidth > 500 ? 500 : constraints.maxWidth;
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        );
      },
    );
  }
}
