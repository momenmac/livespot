import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';

class CricleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const CricleButton({super.key, required this.onPressed, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: ThemeConstants.primaryColor,
        padding: EdgeInsets.all(0),
        shape: CircleBorder(),
      ),
      child: Icon(
        icon,
        size: 15,
        color: Colors.white,
      ),
    );
  }
}
