import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:flutter_application_2/ui/auth/get_started_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // final isOnboardingCompleted = prefs.getBool('isOnboardingCompleted') ?? false;
  final isOnboardingCompleted = false;
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(MyApp(
      isOnboardingCompleted: isOnboardingCompleted, isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isOnboardingCompleted;
  final bool isLoggedIn;
  const MyApp(
      {super.key,
      required this.isOnboardingCompleted,
      required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      home: GetStartedScreen(),
    );
  }
}
