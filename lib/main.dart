import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_application_2/core/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';

// Import the correct file for hero tag management
import 'ui/widgets/safe_hero.dart'; // Using relative path instead of package path

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Reset hero tag registry on app start
  HeroTagRegistry.reset();

  // Add this line to globally disable FAB hero animations
  // This is an alternative solution if adding hero tags is problematic
  // MaterialRectArcTween.debugAllowMaterialPointsForPath = false;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reset hero registry when building the root app widget
    HeroTagRegistry.reset();

    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      navigatorKey: NavigationService().navigatorKey,
      initialRoute: AppRoutes.initial,
      routes: AppRoutes.routes,
      builder: (context, child) {
        // This ensures overlay entries work correctly
        return MediaQuery(
          // Prevent text scaling to avoid layout issues
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          // Wrap with GestureDetector to dismiss keyboard on tap outside input fields
          child: GestureDetector(
            onTap: () {
              // Hide keyboard when tapping outside text fields
              FocusScopeNode currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            child: child!,
          ),
        );
      },
    );
  }
}
