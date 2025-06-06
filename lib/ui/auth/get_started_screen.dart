import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/api/account/auth_service.dart';
import 'package:flutter_application_2/ui/auth/signup/create_account_screen.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
import 'package:flutter_application_2/ui/widgets/account_link.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/auth/widgets/google_sign_in_button.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    // Prevent duplicate calls
    if (_isLoading) return;

    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      final result = await accountProvider.signInWithGoogle();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Check whether this was a new account, a linked account, or regular login
        final bool isNewAccount = result['is_new_account'] ?? false;
        final bool accountLinked = result['account_linked'] ?? false;

        String message;
        if (isNewAccount) {
          message = "Welcome! Your account has been created.";
        } else if (accountLinked) {
          message = "Google account linked to your existing account.";
        } else {
          message = "Welcome back!";
        }

        // Show success message with longer duration
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: message,
          duration: const Duration(seconds: 2),
        );

        // Delay navigation slightly to ensure the toast is visible
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } else {
        ResponsiveSnackBar.showError(
          context: context,
          message: accountProvider.error ?? "Failed to sign in with Google",
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ResponsiveSnackBar.showError(
        context: context,
        message: "Error: ${e.toString()}",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final verticalPadding =
              orientation == Orientation.portrait ? 100.0 : 20.0;
          final bottomPadding =
              orientation == Orientation.portrait ? 69.0 : 20.0;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(20, verticalPadding, 20, bottomPadding),
                child: ResponsiveContainer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Image.asset(
                        'assets/icons/Logo2.png',
                        width: 200,
                        height: 200,
                      )),
                      SizedBox(
                          height:
                              orientation == Orientation.portrait ? 20 : 10),
                      Text(
                        TextStrings.appName,
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                          height: orientation == Orientation.portrait ? 10 : 5),
                      Text(
                        TextStrings.appDescription,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                          height:
                              orientation == Orientation.portrait ? 89 : 30),
                      AnimatedButton(
                        text: TextStrings.letsGetStarted,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CreateAccountScreen()),
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 300),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Theme.of(context).dividerColor,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(TextStrings.or),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Theme.of(context).dividerColor,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: 400, minHeight: 56),
                          child: GoogleSignInButton(
                            googleSignIn: _authService.googleSignIn,
                            isLoading: _isLoading,
                            onSignIn: (account) {
                              if (account != null) {
                                // Only proceed if not already loading
                                if (!_isLoading) {
                                  _handleGoogleSignIn();
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                          height:
                              orientation == Orientation.portrait ? 18 : 10),
                      AccountLink(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
