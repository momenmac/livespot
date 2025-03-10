import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_2/firebase_options.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';

// Import the correct file for hero tag management
import 'ui/widgets/safe_hero.dart'; // Using relative path instead of package path

Future<void> main() async {
  // Ensure binding is initialized at app startup
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Firebase: $e');
    // Continue without Firebase if initialization fails
  }

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Reset hero tag registry on app start
  HeroTagRegistry.reset();

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
      routes: {
        ...AppRoutes.routes,
        AppRoutes.messages: (context) => const MessagesPage(),
      },
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
