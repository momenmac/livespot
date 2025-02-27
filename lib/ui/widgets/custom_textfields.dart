import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool validateOnType;
  final double? maxWidth;
  final FocusNode? focusNode;
  final Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;

  const CustomTextField({
    super.key,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.validator,
    this.validateOnType = false,
    this.maxWidth = 400,
    this.focusNode,
    this.onFieldSubmitted,
    this.textInputAction,
  });

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();

    if (widget.validateOnType) {
      widget.controller?.addListener(() {
        setState(() {
          _isDirty = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void triggerValidation() {
    setState(() {
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isError = _isDirty &&
        widget.validator != null &&
        widget.validator!(widget.controller?.text) != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.maxWidth!,
          maxWidth: widget.maxWidth!,
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          focusNode: widget.focusNode,
          onFieldSubmitted: widget.onFieldSubmitted,
          textInputAction: widget.textInputAction,
          validator: (value) {
            if (_isDirty) {
              return widget.validator?.call(value);
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isError
                      ? Colors.red
                      : Theme.of(context).textTheme.labelSmall?.color,
                ),
          ),
        ),
      ),
    );
  }
}
