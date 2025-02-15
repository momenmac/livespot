import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/widgets/sign_in_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome Back!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            SignInButton(
              onPressed: () {
                // Handle Google sign-in
              },
              text: 'Sign in with Google',
              icon: Icons.g_mobiledata,
            ),
          ],
        ),
      ),
    );
  }
}
