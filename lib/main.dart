import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_application_2/ui/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_2/firebase_options.dart';
import 'package:flutter_application_2/services/utils/navigation_service.dart';
import 'package:flutter_application_2/routes/app_routes.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'dart:async';

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
  // Skip initialization if we've already tried
  if (_isFirebaseInitialized) return _isFirebaseInitialized;

  try {
    print(
        '🔍 Starting Firebase initialization with options: ${DefaultFirebaseOptions.currentPlatform.projectId}');

    if (Platform.isIOS) {
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('Firebase initialization timed out');
    });

    _isFirebaseInitialized = true;
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Firebase: $e');
    if (Platform.isIOS) {
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
  // Ensure binding is initialized at app startup
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations first
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
  if (Platform.isIOS && !kIsWeb) {
    // This is a heuristic to detect if we're in debug mode on iOS simulator
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

  // Start the app without waiting for Firebase initialization
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        // Add firebase status notifier to providers
        ChangeNotifierProvider.value(value: firebaseStatusNotifier),
      ],
      child: const MyApp(),
    ),
  );

  // Try to initialize Firebase after the app has started
  // This helps prevent startup crashes if Firebase has issues
  Timer(const Duration(milliseconds: 1500), () async {
    bool success = shouldSkipFirebase ? false : await initFirebaseSafely();
    // Update the notifier with the correct Firebase status
    firebaseStatusNotifier.setInitialized(success);

    // Print a clear message about Firebase status
    if (success) {
      print('🔔 Firebase is now available to the app');
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
        // Show a banner if Firebase is not available and we're not on iOS
        // (since we deliberately skip Firebase on iOS)
        if (!firebaseStatus.isInitialized && !Platform.isIOS) {
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
    );
  }
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

  // Check if we're deliberately skipping Firebase (on iOS)
  static bool get isSkippedPlatform => Platform.isIOS && !kIsWeb;

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
}
