import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/widgets/social_login_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/assest_path_constants.dart';

class GoogleSignInButton extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount?) onSignIn;

  const GoogleSignInButton({
    super.key,
    required this.googleSignIn,
    required this.onSignIn,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () async {
              try {
                final user = await widget.googleSignIn.signIn();
                widget.onSignIn(user);
              } catch (error) {
                print('${TextStrings.googleSignInError}$error');
                widget.onSignIn(null);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? ThemeConstants.darkCardColor
                  : ThemeConstants.lightBackgroundColor,
              foregroundColor: Theme.of(context).brightness == Brightness.light
                  ? ThemeConstants.darkCardColor
                  : ThemeConstants.lightBackgroundColor,
              padding: EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AssestPathConstants.googleIcon,
                  height: 24,
                  width: 24,
                ),
                const SizedBox(width: 12),
                Text(TextStrings.signInWithGoogle),
              ],
            ),
          ),
        ),
      );
    } else {
      return SocialLoginButton(
        text: TextStrings.continueWithGoogle,
        iconPath: AssestPathConstants.googleIcon,
        onPressed: () async {
          try {
            final account = await widget.googleSignIn.signIn();
            widget.onSignIn(account);
          } catch (error) {
            print('${TextStrings.googleSignInError}$error');
            widget.onSignIn(null);
          }
        },
      );
    }
  }
}
