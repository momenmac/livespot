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
      print('==== Google Sign In Error ====');
      print('Error details: $error');
      print('============================');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
    } catch (error) {
      print('Sign out error: $error');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account != null) {
      print('User signed in silently:');
      print('Display Name: ${account.displayName}');
      print('Email: ${account.email}');
      print('ID: ${account.id}');
      print('Photo URL: ${account.photoUrl}');
      return account;
    } else {
      print('No user is signed in.');
      return null;
    }
  }
}
