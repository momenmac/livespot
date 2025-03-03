import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';

// Import the correct file for hero tag management
import 'ui/widgets/safe_hero.dart'; // Using relative path instead of package path

Future<void> main() async {
  // Ensure binding is initialized at app startup
  WidgetsFlutterBinding.ensureInitialized();

  // COMPLETELY NEW APPROACH: SafeFirebaseInit
  bool firebaseInitialized = await safeFirebaseInit();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Reset hero tag registry on app start
  HeroTagRegistry.reset();

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

/// Safely initializes Firebase, handling duplicate initialization issues
Future<bool> safeFirebaseInit() async {
  try {
    // First check if any Firebase apps are initialized
    List<FirebaseApp> apps = Firebase.apps;

    if (apps.isEmpty) {
      // No apps initialized yet, we can safely initialize
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      return true;
    } else {
      // An app is already initialized, get the default one
      FirebaseApp defaultApp = Firebase.app();
      debugPrint('ℹ️ Using existing Firebase app: ${defaultApp.name}');
      return true;
    }
  } catch (e) {
    // Special handling for the duplicate app error
    if (e.toString().contains('duplicate-app')) {
      debugPrint('ℹ️ Using existing Firebase instance');
      return true;
    } else {
      debugPrint('❌ Firebase initialization error: $e');
      return false;
    }
  }
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({
    super.key,
    this.firebaseInitialized = false,
  });

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
