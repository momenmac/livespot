import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_2/ui/auth/widgets/google_sign_in_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Get GoogleSignIn from the provider instead of creating a new instance
    final googleSignIn = Provider.of<GoogleSignIn>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to the App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GoogleSignInButton(
              googleSignIn: googleSignIn, // Use the shared instance
              onSignIn: (account) {
                if (account != null) {
                  // Handle successful sign-in
                  print('Signed in as ${account.email}');
                } else {
                  // Handle sign-in failure
                  print('Sign-in failed or cancelled');
                }
              },
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
