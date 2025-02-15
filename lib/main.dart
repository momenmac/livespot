import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/auth/login_screen.dart';
import 'package:flutter_application_2/ui/onboarding/onboarding_screen.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
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
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 180, 216)),
        useMaterial3: true,
      ),
      home: isOnboardingCompleted
          ? (isLoggedIn ? Home() : LoginScreen())
          : OnboardingScreen(),
    );
  }
}
