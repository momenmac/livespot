// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool showLoader;

  const AnimatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.showLoader = false,
  });

  @override
  AnimatedButtonState createState() => AnimatedButtonState();
}

class AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          _controller.forward();
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          _controller.reverse();
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null) {
          _controller.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 400, maxWidth: 400),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.onPressed == null
                    ? LinearGradient(
                        colors: [Colors.grey.shade400, Colors.grey.shade500],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : const LinearGradient(
                        colors: [
                          ThemeConstants.primaryColor,
                          ThemeConstants.primaryColor
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: widget.showLoader
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
