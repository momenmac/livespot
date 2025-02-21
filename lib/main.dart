import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:flutter_application_2/ui/auth/get_started_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Un-commented import
import 'package:flutter_application_2/core/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Pass Firebase options
  );
  // final prefs = await SharedPreferences.getInstance();
  // final isOnboardingCompleted = false;
  // final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      navigatorKey: NavigationService().navigatorKey,
      initialRoute: AppRoutes.initial, // Use initialRoute instead of home
      routes: AppRoutes.routes,
    );
  }
}
