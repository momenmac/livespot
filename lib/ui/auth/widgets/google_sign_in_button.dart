import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInButton extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount?) onSignIn;
  final bool isLoading;

  const GoogleSignInButton({
    Key? key,
    required this.googleSignIn,
    required this.onSignIn,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: widget.isLoading || _isSigningIn
          ? null
          : () async {
              // Prevent multiple sign-in attempts
              if (_isSigningIn) return;

              setState(() {
                _isSigningIn = true;
              });

              try {
                // First check if already signed in to avoid duplicate requests
                final alreadySignedIn = await widget.googleSignIn.isSignedIn();
                GoogleSignInAccount? account;

                if (alreadySignedIn) {
                  // Just get the current account
                  print(
                      'Already signed in with Google, retrieving current account');
                  account = widget.googleSignIn.currentUser ??
                      await widget.googleSignIn.signInSilently();
                } else {
                  // Perform the regular sign in
                  account = await widget.googleSignIn.signIn();
                }

                widget.onSignIn(account);
              } catch (e) {
                print('Google Sign In Error: $e');
                widget.onSignIn(null);
              } finally {
                if (mounted) {
                  setState(() {
                    _isSigningIn = false;
                  });
                }
              }
            },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: ThemeConstants.primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // More rounded corners
        ),
        // Apply slight elevation for a modern look
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading || _isSigningIn) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConstants.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Please wait...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ] else ...[
            Image.asset(
              'assets/icons/Google.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) {
                print('Failed to load Google icon: $error');
                return Icon(Icons.g_mobiledata, size: 24);
              },
            ),
            const SizedBox(width: 14), // More spacing
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                // Use a color that works on both light and dark themes
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
