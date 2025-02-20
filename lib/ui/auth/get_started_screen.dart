import 'package:flutter/material.dart';
// Fix the imports to match your project name
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/core/services/auth_service.dart';
import 'package:flutter_application_2/ui/auth/signup/create_account_screen.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
import 'package:flutter_application_2/ui/widgets/account_link.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/google_sign_in_button.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final AuthService _authService = AuthService();

  Future<void> _handleGoogleSignIn() async {
    try {
      final account = await _authService.signInWithGoogle();
      if (account != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully signed in with Google'),
            backgroundColor: ThemeConstants.primaryColor,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Home()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google'),
            backgroundColor: ThemeConstants.red,
          ),
        );
      }
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
                          child: Icon(Icons.flutter_dash,
                              size: 100, color: ThemeConstants.primaryColor)),
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
                                child: Text('OR'),
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
                          constraints: BoxConstraints(maxWidth: 400),
                          child: GoogleSignInButton(
                            googleSignIn: _authService.googleSignIn,
                            onSignIn: (account) async {
                              if (account != null) {
                                await _handleGoogleSignIn();
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
