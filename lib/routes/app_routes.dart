import 'package:flutter/material.dart';
import 'package:flutter_application_2/debug/network_test_page.dart';
import 'package:flutter_application_2/ui/auth/get_started_screen.dart';
import 'package:flutter_application_2/ui/auth/login/login_screen.dart';
import 'package:flutter_application_2/ui/auth/signup/create_account_screen.dart';
import 'package:flutter_application_2/ui/auth/signup/verify_email.dart';
import 'package:flutter_application_2/ui/auth/password/forgot_password_screen.dart';
import 'package:flutter_application_2/ui/auth/password/reset_password_screen.dart';
import 'package:flutter_application_2/ui/pages/camera_page.dart';
import 'package:flutter_application_2/ui/pages/home.dart';
import 'package:flutter_application_2/ui/pages/map/map_page.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';

class AppRoutes {
  // Route names
  static const String initial = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String createAccount = '/create-account';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String camera = '/camera';
  static const String map = '/map';
  static const String messages = '/messages';
  static const String networkTest = '/debug/network-test';

  // Route map
  static Map<String, WidgetBuilder> get routes => {
        initial: (_) => const GetStartedScreen(), // Initial route handler
        // initial: (_) => const Home(), // Initial route handler
        home: (_) => const Home(),
        login: (_) => const LoginScreen(),
        createAccount: (_) => const CreateAccountScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        verifyEmail: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return VerifyEmailScreen(
            email: args?['email'],
            profileImage: args?['profileImage'],
            censorEmail: args?['censorEmail'] ?? true,
          );
        },
        resetPassword: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          if (args == null) {
            // If no arguments provided, redirect to forgot password screen
            return const ForgotPasswordScreen();
          }
          return ResetPasswordScreen(
            email: args['email'] ?? '',
            resetToken: args['resetToken'],
          );
        },
        camera: (_) => const CameraPage(),
        map: (_) => const MapPage(),
        messages: (_) => const MessagesPage(),
        networkTest: (context) => const NetworkTestPage(),
      };

  // This method should be in the NavigationService class
  static dynamic extractArguments(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments;
  }
}
