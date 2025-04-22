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
import 'package:flutter_application_2/providers/theme_provider.dart';
import 'package:flutter_application_2/services/auth/auth_service.dart';
import 'dart:async';
import 'dart:developer' as developer;

// Use conditional import for Platform
import 'dart:io'
    if (dart.library.html) 'package:flutter_application_2/platform_web.dart'
    show Platform;

// Import the correct file for hero tag management
import 'ui/widgets/safe_hero.dart'; // Using relative path instead of package path

// Global flag to track Firebase status
bool _isFirebaseInitialized = false;

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

    if (Firebase.apps.isNotEmpty) {
      print('✅ Firebase is already initialized, reusing existing instance');
      _isFirebaseInitialized = true;
      return true;
    }

    if (!kIsWeb && Platform.isIOS) {
      print('📱 iOS Bundle ID: ${DefaultFirebaseOptions.ios.iosBundleId}');

      String iosInfo =
          await SystemChannels.platform.invokeMethod('SystemInfo.iosInfo') ??
              '';
      bool isSimulator = iosInfo.toLowerCase().contains('simulator');

      if (isSimulator) {
        print(
            '⚠️ iOS Simulator detected: Be cautious with Firebase initialization');
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));

    print('🚀 About to initialize Firebase...');

    if (kIsWeb) {
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

  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final firebaseStatusNotifier = FirebaseStatusNotifier();

  HeroTagRegistry.reset();

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

  final accountProvider = AccountProvider()..initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: firebaseStatusNotifier),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: MyApp(accountProvider: accountProvider),
    ),
  );

  Timer(const Duration(milliseconds: 1500), () async {
    bool success = firebaseInitializedBeforeApp;

    if (shouldSkipFirebase) {
      success = false;
    } else if (!firebaseInitializedBeforeApp) {
      success = await initFirebaseSafely();
    }

    firebaseStatusNotifier.setInitialized(success);

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

class MyApp extends StatefulWidget {
  final AccountProvider accountProvider;

  const MyApp({required this.accountProvider, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialAuthCheckComplete = false;

  @override
  void initState() {
    super.initState();
    // Listen to state changes AFTER the first frame to avoid issues during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure listener is added before potentially calling it
      if (mounted) {
        widget.accountProvider.addListener(_onAuthStateChanged);
        // Trigger initial check manually AFTER listener is added
        _onAuthStateChanged();
      }
    });
  }

  @override
  void dispose() {
    widget.accountProvider.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final isAuthenticated = widget.accountProvider.isAuthenticated;
    final isLoading = widget.accountProvider.isLoading;
    final currentRoute = NavigationService().currentRoute;
    final isAtHome = currentRoute == AppRoutes.home;
    final isAtInitial = currentRoute == AppRoutes.initial ||
        currentRoute == null ||
        currentRoute == '/';

    developer.log(
        '🔄 Auth state changed: isAuthenticated=$isAuthenticated, isLoading=$isLoading, initialCheckComplete=$_initialAuthCheckComplete',
        name: 'AuthListener');

    if (!isLoading) {
      if (!_initialAuthCheckComplete) {
        _initialAuthCheckComplete = true;
        developer.log(
            '🏁 Initial auth check complete. Final state: isAuthenticated=$isAuthenticated',
            name: 'AuthListener');

        if (isAuthenticated && !isAtHome) {
          developer.log('👤 Navigating to home after initial check.',
              name: 'AuthListener');
          _navigateTo(AppRoutes.home);
        } else if (!isAuthenticated && !isAtInitial) {
          developer.log('👤 Navigating to initial after initial check.',
              name: 'AuthListener');
          _navigateTo(AppRoutes.initial);
        }
      } else {
        developer.log('👤 Auth state changed after initialization.',
            name: 'AuthListener');

        if (isAuthenticated && !isAtHome) {
          developer.log('   User became authenticated, navigating to home.',
              name: 'AuthListener');
          _navigateTo(AppRoutes.home);
        } else if (!isAuthenticated && !isAtInitial) {
          developer.log(
              '   User became unauthenticated, navigating to initial.',
              name: 'AuthListener');
          _navigateTo(AppRoutes.initial);
        }
      }
    } else {
      developer.log(
          '⏳ Auth state changed while loading. Waiting for loading to finish.',
          name: 'AuthListener');
    }
  }

  // Helper function for navigation to avoid repetition and ensure it runs post-frame
  void _navigateTo(String routeName) {
    // Schedule navigation for after the current frame build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Double-check mounted status right before navigation
      if (mounted && NavigationService().navigatorKey.currentState != null) {
        developer.log(
            '🚀 Executing navigation via replaceAllWith to: $routeName',
            name: 'AuthListener');
        NavigationService().replaceAllWith(routeName);
      } else if (mounted) {
        developer.log(
            '⚠️ Navigator not ready during scheduled navigation to $routeName.',
            name: 'AuthListener');
        // Optional: Retry logic could be added here if needed, but often resolves itself.
      } else {
        developer.log(
            '⚠️ Widget unmounted before scheduled navigation to $routeName could execute.',
            name: 'AuthListener');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    HeroTagRegistry.reset();

    final firebaseStatus = Provider.of<FirebaseStatusNotifier>(context);

    return SessionMonitor(
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'My App',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: TAppTheme.lightTheme,
            darkTheme: TAppTheme.darkTheme,
            navigatorKey: NavigationService().navigatorKey,
            initialRoute: AppRoutes.initial,
            onGenerateRoute: RouteGuard.generateRoute,
            builder: (context, child) {
              if (!firebaseStatus.isInitialized &&
                  !(kIsWeb || (!kIsWeb && Platform.isIOS))) {
                print(
                    '⚠️ App running with limited functionality (Firebase unavailable)');
              }

              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.0)),
                child: GestureDetector(
                  onTap: () {
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
        },
      ),
    );
  }
}

class FirebaseHelper {
  static bool get isAvailable => _isFirebaseInitialized;

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

  static bool get isSkippedPlatform => kIsWeb || (!kIsWeb && Platform.isIOS);

  static String getStatusMessage() {
    if (isSkippedPlatform) {
      return "Firebase is not available on this platform";
    } else if (isAvailable) {
      return "Firebase is connected and ready";
    } else {
      return "Firebase connection failed";
    }
  }

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
