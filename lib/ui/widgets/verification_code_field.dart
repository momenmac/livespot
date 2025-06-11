import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerificationCodeField extends StatefulWidget {
  final void Function(String) onCompleted;

  const VerificationCodeField({
    super.key,
    required this.onCompleted,
  });

  @override
  State<VerificationCodeField> createState() => VerificationCodeFieldState();
}

class VerificationCodeFieldState extends State<VerificationCodeField> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void clearFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onChanged(int index, String value) {
    if (!mounted) return; // Safety check

    if (value.length == 1) {
      if (index < 5) {
        // Small delay to ensure the UI is stable before changing focus
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _focusNodes[index + 1].canRequestFocus) {
            _focusNodes[index + 1].requestFocus();
          }
        });
      } else {
        // Last digit entered, trigger completion
        final code = _controllers.map((c) => c.text).join();
        if (code.length == 6) {
          _handleCompletion(code);
        }
      }
    }

    if (value.isEmpty && index > 0) {
      // Small delay to ensure the UI is stable before changing focus
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _focusNodes[index - 1].canRequestFocus) {
          _focusNodes[index - 1].requestFocus();
        }
      });
    }
  }

  // Make sure onCompleted is called with keyboard dismissal
  void _handleCompletion(String code) {
    if (!mounted) return; // Safety check

    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    // Small delay to ensure the keyboard is dismissed before calling completion
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        widget.onCompleted(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (index) => Container(
              width: 50,
              height: 50,
              margin: EdgeInsets.symmetric(horizontal: 4),
              child: TextFormField(
                // Changed to TextFormField for better form integration
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => _onChanged(index, value),
                // Add textInputAction for better keyboard handling
                textInputAction:
                    index < 5 ? TextInputAction.next : TextInputAction.done,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
