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

// Route builder type with dynamic arguments
typedef RouteBuilder = Widget Function(Map<String, dynamic> arguments);

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
  static const String networkTest = '/network-test';

  // Route map with builders that accept arguments
  static Map<String, RouteBuilder> get routes => {
        initial: (_) => const GetStartedScreen(),
        home: (_) => const Home(),
        login: (_) => const LoginScreen(),
        createAccount: (_) => const CreateAccountScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
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
        camera: (_) => const CameraPage(),
        map: (_) => const MapPage(),
        messages: (_) => const MessagesPage(),
        networkTest: (_) => const NetworkTestPage(),
      };
}
