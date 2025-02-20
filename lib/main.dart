import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:flutter_application_2/ui/auth/get_started_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Un-commented import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Pass Firebase options
  );
  final prefs = await SharedPreferences.getInstance();
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
