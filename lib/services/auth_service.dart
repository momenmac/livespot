import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AuthService {
  final GoogleSignIn googleSignIn = _getGoogleSignIn();

  static GoogleSignIn _getGoogleSignIn() {
    if (kIsWeb) {
      //web
      return GoogleSignIn(
        clientId:
            '160030236932-i37bjgcbpobam70f24d0a8f2hf5124tl.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      //ios
      return GoogleSignIn(
        clientId:
            '160030236932-v1fqu2qitgnlivemngb5h1uq92fgr8mq.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else {
      return GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        // TODO: Verify Google token with backend
        // TODO: Check if user exists in database
        // TODO: If new user, create user record with Google data
        // TODO: Generate and store JWT token
        // TODO: Store user preferences and settings
        // TODO: Log sign in attempt for security

        print('==== Google Sign In Success ====');
        print('Email: ${account.email}');
        print('Display Name: ${account.displayName}');
        print('Photo URL: ${account.photoUrl}');
        print('ID: ${account.id}');
        print('Server Auth Code: ${account.serverAuthCode}');
        print('============================');
      } else {
        print('Sign in failed - account is null');
      }
      return account;
    } catch (error) {
      // TODO: Log authentication errors to backend
      // TODO: Implement proper error handling and user feedback
      print('==== Google Sign In Error ====');
      print('Error details: $error');
      print('============================');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      // TODO: Invalidate JWT token
      // TODO: Clear user session in backend
      // TODO: Log sign out event
      // TODO: Clear local secure storage
      await googleSignIn.signOut();
    } catch (error) {
      // TODO: Handle sign out errors properly
      print('Sign out error: $error');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account != null) {
      // TODO: Verify session is still valid in backend
      // TODO: Refresh JWT token if needed
      // TODO: Update last active timestamp
      // TODO: Sync user data with backend
      print('User signed in silently:');
      print('Display Name: ${account.displayName}');
      print('Email: ${account.email}');
      print('ID: ${account.id}');
      print('Photo URL: ${account.photoUrl}');
      return account;
    } else {
      // TODO: Clear any stale local data
      print('No user is signed in.');
      return null;
    }
  }
}
