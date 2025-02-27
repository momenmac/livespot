import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';

class SocialLoginButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialLoginButton({
    super.key,
    required this.text,
    required this.iconPath,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, minWidth: 300),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? ThemeConstants.darkCardColor
                : ThemeConstants.lightBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      ThemeConstants.textFieldLabelColorDark),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      iconPath,
                      height: 24,
                      width: 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
