import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
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
          onPressed: () {},
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }
}
