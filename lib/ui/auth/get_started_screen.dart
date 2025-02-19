import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/auth/signup/create_account_screen.dart';
import 'package:flutter_application_2/ui/widgets/account_link.dart';
import 'package:flutter_application_2/ui/widgets/animated_button.dart';
import 'package:flutter_application_2/ui/widgets/responsive_container.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

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
                      // Added logo at the top
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
