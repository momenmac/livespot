import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;

class GoogleSignInButton extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount?) onSignIn;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.googleSignIn,
    required this.onSignIn,
    this.isLoading = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  Future<void> _attemptSignIn() async {
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
        print('Already signed in with Google, retrieving current account');
        account = widget.googleSignIn.currentUser ??
            await widget.googleSignIn.signInSilently();
      } else {
        // Detailed logging before sign in attempt
        print('Starting Google Sign In flow, attempt #${_retryCount + 1}');
        if (Platform.isIOS) {
          print('Running on iOS ${Platform.operatingSystemVersion}');
        }

        // Perform the regular sign in
        account = await widget.googleSignIn.signIn();

        print(
            'Sign in completed: ${account != null ? 'Success' : 'Cancelled/Failed'}');
      }

      widget.onSignIn(account);
      // Reset retry count on success
      _retryCount = 0;
    } catch (e) {
      print('Google Sign In Error (detailed): $e');

      // Only retry if we haven't exceeded max retries
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print('Retrying sign in (attempt $_retryCount of $_maxRetries)...');

        // Add a small delay before retrying
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _attemptSignIn();
          }
        });
        return;
      } else {
        _retryCount = 0;
        // Show a more helpful error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to sign in with Google. Please check your internet connection and try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  _attemptSignIn();
                }
              },
            ),
          ),
        );
        widget.onSignIn(null);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: widget.isLoading || _isSigningIn ? null : _attemptSignIn,
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
