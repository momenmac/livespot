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
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();
// Route builder type with dynamic arguments
typedef RouteBuilder = Widget Function(Map<String, dynamic> arguments);

class AppRoutes {
  // Route names
  static const String initial = '/'; // This should be your login/initial page
  static const String home = '/home';
  static const String login = '/login';
  static const String createAccount = '/create-account';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String camera = '/camera';
  static const String map = '/map';
  static const String messages = '/messages';
  static const String networkTest = '/network-test';

  // Route map with builders that accept arguments
  static final routes = <String, Widget Function(dynamic args)>{
    initial: (args) =>
        const GetStartedScreen(), // <-- Make sure this is your login/initial page
    home: (args) => const Home(),
    login: (args) => const LoginScreen(),
    createAccount: (args) => const CreateAccountScreen(),
    forgotPassword: (args) => const ForgotPasswordScreen(),
    verifyEmail: (args) {
      return VerifyEmailScreen(
        email: args['email'],
        profileImage: args['profileImage'],
        censorEmail: args['censorEmail'] ?? true,
      );
    },
    resetPassword: (args) {
      return ResetPasswordScreen(
        email: args['email'] ?? '',
        resetToken: args['resetToken'],
      );
    },
    camera: (args) => const CameraPage(),
    map: (args) => const MapPage(),
    messages: (args) => const MessagesPage(),
    networkTest: (args) => const NetworkTestPage(),
  };
}
