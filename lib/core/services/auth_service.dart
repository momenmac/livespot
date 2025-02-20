import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final GoogleSignIn googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId:
              '160030236932-i37bjgcbpobam70f24d0a8f2hf5124tl.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        )
      : GoogleSignIn(
          serverClientId:
              '160030236932-8h4jb9sddepmh7hi7jdkkr5p57hgsvvb.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        );

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return signInSilently();
      } else {
        GoogleSignInAccount? account = await googleSignIn.signInSilently();
        account ??= await googleSignIn.signIn();
        print('Successfully signed in: ${account?.email}');
        return account;
      }
    } catch (error) {
      print('Google sign in error: $error');
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
