import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/auth/login/login_screen.dart';
import 'package:flutter_application_2/ui/widgets/custom_buttons.dart';

class AccountLink extends StatelessWidget {
  const AccountLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          TextStrings.iAlreadyHaveAnAccount,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        CricleButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          },
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }
}
