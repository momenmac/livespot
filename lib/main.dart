import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/services/auth/session_monitor.dart';
import 'package:flutter_application_2/routes/route_guard.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_2/services/config/firebase_options.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'dart:async';

// Use conditional import for Platform
import 'dart:io'
    if (dart.library.html) 'package:flutter_application_2/platform_web.dart'
    show Platform;

// Import the correct file for hero tag management
import 'ui/widgets/safe_hero.dart'; // Using relative path instead of package path

// Global flag to track Firebase status
bool _isFirebaseInitialized = false;
// Create a key to access the provider from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// NEW: Create a class to notify listeners of Firebase status changes
class FirebaseStatusNotifier extends ChangeNotifier {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void setInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }
}

Future<bool> initFirebaseSafely() async {
  try {
    print(
        '🔍 Starting Firebase initialization with options: ${DefaultFirebaseOptions.currentPlatform.projectId}');

    // First, check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      print('✅ Firebase is already initialized, reusing existing instance');
      _isFirebaseInitialized = true;
      return true;
    }

    if (!kIsWeb && Platform.isIOS) {
      print('📱 iOS Bundle ID: ${DefaultFirebaseOptions.ios.iosBundleId}');

      // Check if we're on iOS simulator (which has problems with Firebase)
      String iosInfo =
          await SystemChannels.platform.invokeMethod('SystemInfo.iosInfo') ??
              '';
      bool isSimulator = iosInfo.toLowerCase().contains('simulator');

      if (isSimulator) {
        print(
            '⚠️ iOS Simulator detected: Be cautious with Firebase initialization');
        // We'll continue, but be prepared for potential crashes
      }
    }

    // Add a short delay to ensure the app is fully loaded before initializing Firebase
    await Future.delayed(const Duration(milliseconds: 800));

    print('🚀 About to initialize Firebase...');

    // Initialize with timeout to prevent hanging
    if (kIsWeb) {
      // Use web-specific initialization
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Firebase initialization timed out');
      });
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Firebase initialization timed out');
      });
    }

    _isFirebaseInitialized = true;
    print('✅ Firebase initialized successfully');
  } catch (e) {
    // If the error is about duplicate app, consider it a success
    if (e.toString().contains('duplicate-app') ||
        e.toString().contains('already exists')) {
      print(
          '⚠️ Firebase app already exists error, but we can use the existing instance');
      _isFirebaseInitialized = true;
      return true;
    }

    print('❌ Failed to initialize Firebase: $e');
    if (!kIsWeb && Platform.isIOS) {
      print(
          '💡 Since you are on iOS, this failure may be due to a simulator issue.');
      print(
          '💡 Try running on a physical device or using the platform-specific workarounds.');
    }
    // Continue without Firebase
    _isFirebaseInitialized = false;
  }

  return _isFirebaseInitialized;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    print('======================================');
    print('✅ FIREBASE SETUP COMPLETE & WORKING! ✅');
    print('======================================');
  } catch (e) {
    print('❌ Failed to initialize Firebase: $e');
  }

  // Ensure binding is initialized at app startup
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Create the Firebase status notifier
  final firebaseStatusNotifier = FirebaseStatusNotifier();

  // Reset hero tag registry on app start
  HeroTagRegistry.reset();

  // Try to check if we're in debug mode on iOS simulator
  bool shouldSkipFirebase = false;
  if (!kIsWeb && Platform.isIOS) {
    try {
      String iosInfo =
          await SystemChannels.platform.invokeMethod('SystemInfo.iosInfo') ??
              '';
      bool isSimulator = iosInfo.toLowerCase().contains('simulator');
      bool isDebug = const bool.fromEnvironment('dart.vm.product') == false;
      shouldSkipFirebase = isSimulator && isDebug;

      if (shouldSkipFirebase) {
        print(
            '⚠️ Debug mode on iOS simulator detected: Will skip Firebase initialization');
      }
    } catch (e) {
      print('⚠️ Could not determine iOS simulator status: $e');
    }
  }

  // Try to get existing Firebase instance or initialize a new one BEFORE starting the app
  bool firebaseInitializedBeforeApp = false;
  if (!shouldSkipFirebase) {
    try {
      if (Firebase.apps.isNotEmpty) {
        print('🔔 Firebase found existing instance before app start');
        firebaseInitializedBeforeApp = true;
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      print('⚠️ Error checking Firebase status: $e');
    }
  }

  // Start the app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()..initialize()),
        ChangeNotifierProvider.value(value: firebaseStatusNotifier),
      ],
      child: const MyApp(),
    ),
  );

  // Initialize Firebase after app start ONLY if not already initialized
  Timer(const Duration(milliseconds: 1500), () async {
    bool success = firebaseInitializedBeforeApp; // Start with existing status

    if (shouldSkipFirebase) {
      success = false;
    } else if (!firebaseInitializedBeforeApp) {
      // Only attempt initialization if not already done
      success = await initFirebaseSafely();
    }

    // Update the notifier with the Firebase status
    firebaseStatusNotifier.setInitialized(success);

    // Print status message
    const divider = "======================================";
    if (success) {
      print('✅ Firebase is now available to the app');
      print(divider);
      print('✅ FIREBASE CONNECTION VERIFIED! ✅');
      print(divider);
    } else if (shouldSkipFirebase) {
      print(
          '🔕 Firebase initialization was deliberately skipped for iOS simulator');
    } else {
      print('🔕 App is running without Firebase services');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reset hero registry when building the root app widget
    HeroTagRegistry.reset();

    // Get the Firebase status
    final firebaseStatus = Provider.of<FirebaseStatusNotifier>(context);

    // Wrap MaterialApp with SessionMonitor
    return SessionMonitor(
      child: MaterialApp(
        title: 'My App',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: TAppTheme.lightTheme,
        darkTheme: TAppTheme.darkTheme,
        navigatorKey: NavigationService().navigatorKey,
        initialRoute: AppRoutes.initial,

        // Replace onGenerateRoute with our enhanced RouteGuard
        onGenerateRoute: RouteGuard.generateRoute,

        builder: (context, child) {
          // Show a banner if Firebase is not available and we're not on web or iOS
          // (since we deliberately skip Firebase on iOS)
          if (!firebaseStatus.isInitialized &&
              !(kIsWeb || (!kIsWeb && Platform.isIOS))) {
            print(
                '⚠️ App running with limited functionality (Firebase unavailable)');
            // You could show a banner or notification here if needed
          }

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
      ),
    );
  }

  // Remove these methods as they're now handled by RouteGuard
  // void _checkRouteAuth(BuildContext context, String? routeName) {...}
  // Widget _getPageForRoute(String? routeName, dynamic args) {...}
}

// Create a more robust helper class to access Firebase safely
class FirebaseHelper {
  static bool get isAvailable => _isFirebaseInitialized;

  // Safely execute Firebase operations with fallbacks
  static Future<T?> safelyRun<T>(Future<T> Function() firebaseOperation,
      {T? fallback}) async {
    if (!isAvailable) {
      print('⚠️ Firebase operation attempted while Firebase is unavailable');
      return fallback;
    }

    try {
      return await firebaseOperation();
    } catch (e) {
      print('❌ Firebase operation failed: $e');
      return fallback;
    }
  }

  // Check if we're deliberately skipping Firebase (on iOS or web)
  static bool get isSkippedPlatform => kIsWeb || (!kIsWeb && Platform.isIOS);

  // Get a user-friendly message about Firebase status
  static String getStatusMessage() {
    if (isSkippedPlatform) {
      return "Firebase is not available on this platform";
    } else if (isAvailable) {
      return "Firebase is connected and ready";
    } else {
      return "Firebase connection failed";
    }
  }

  // A method to safely initialize other Firebase services
  static Future<bool> initializeService(
      Future<void> Function() initFunction, String serviceName) async {
    if (!isAvailable) return false;

    try {
      await initFunction();
      print('✅ $serviceName initialized successfully');
      return true;
    } catch (e) {
      print('❌ Failed to initialize $serviceName: $e');
      return false;
    }
  }

  // Add a method to print the current Firebase status
  static void printStatus() {
    if (isAvailable) {
      print('======================================');
      print('✅ FIREBASE STATUS CHECK: ACTIVE & WORKING! ✅');
      print('======================================');
    } else {
      print('======================================');
      print('❌ FIREBASE STATUS CHECK: NOT AVAILABLE ❌');
      print('======================================');
    }
  }
}
