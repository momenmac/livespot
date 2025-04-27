import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'dart:async';

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
      // Check network connectivity first
      bool hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No internet connection. Please check your network settings and try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _isSigningIn = false;
        });
        return;
      }

      // --- Improved Google Sign-In approach for iOS Safari issues ---
      try {
        final isSignedIn = await widget.googleSignIn.isSignedIn();
        if (isSignedIn) {
          print(
              'GoogleSignIn: Already signed in. Signing out before new attempt.');
          await widget.googleSignIn.signOut();
          // Wait a moment for Google servers to register the sign out
          await Future.delayed(Duration(milliseconds: 300));
        }
      } catch (e) {
        print('GoogleSignIn: Error handling pre-signin state: $e');
        // Continue anyway
      }

      // --- SAFARI WORKAROUND: Special handling for iOS ---
      GoogleSignInAccount? account;
      if (Platform.isIOS) {
        try {
          // On iOS, try silent sign-in first, which might skip the Safari page
          account = await widget.googleSignIn.signInSilently();
          print(
              'iOS: Tried silent sign-in first: ${account != null ? "success" : "failed"}');

          // If silent sign-in fails, try full sign-in
          if (account == null) {
            // For iOS, set the scopes before calling signIn() to reduce Safari issues
            widget.googleSignIn.scopes.addAll(['email', 'profile']);

            // Use a timeout to handle Safari not returning
            account = await _timedSignIn();
          }
        } catch (e) {
          print('iOS GoogleSignIn error: $e');
          rethrow;
        }
      } else {
        // For non-iOS platforms, just do normal sign-in
        account = await widget.googleSignIn.signIn();
      }

      if (account == null) {
        print('GoogleSignIn: User cancelled the sign-in or an error occurred.');

        if (Platform.isIOS) {
          print('NOTE: On iOS, this often happens due to Safari issues:');
          print('1. Make sure your internet connection is stable');
          print('2. Check that Google Cloud Console OAuth setup is correct');
          print(
              '3. On simulator: This is a known issue - try on a real device');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign-in was cancelled or failed. Please try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 4),
          ),
        );
      }

      print(
          'Sign in completed: ${account != null ? "Success" : "Cancelled/Failed"}');
      widget.onSignIn(account);
      _retryCount = 0;
    } catch (e, stack) {
      print('Google Sign In Error (detailed): $e');
      print('Stack: $stack');

      // Show a user-friendly error based on error type
      String errorMessage = 'Sign-in failed. Please try again.';

      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('Socket')) {
        errorMessage =
            'Network issue during sign-in. Please check your internet connection.';
      } else if (e.toString().contains('Safari')) {
        errorMessage =
            'Problem with Safari during sign-in. If on simulator, try a physical device.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
          duration: Duration(seconds: 6),
        ),
      );

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

  // Sign-in with timeout for Safari issues
  Future<GoogleSignInAccount?> _timedSignIn() async {
    try {
      print('Starting Google Sign In with 20-second timeout');
      return await widget.googleSignIn.signIn().timeout(Duration(seconds: 20),
          onTimeout: () {
        print('GoogleSignIn timed out after 20 seconds, likely Safari issue');
        throw TimeoutException(
            'Google Sign In timed out. Safari may have failed to return to the app.');
      });
    } catch (e) {
      if (e is TimeoutException) {
        // Check if user might have actually signed in despite timeout
        final isSignedIn = await widget.googleSignIn.isSignedIn();
        if (isSignedIn) {
          print(
              'User appears to have signed in despite timeout, retrieving account');
          return await widget.googleSignIn.signInSilently();
        }
      }
      rethrow;
    }
  }

  // Check if internet is available
  Future<bool> _checkInternetConnection() async {
    try {
      // Try to reach Google
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Network check failed: $e');
      return false;
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
