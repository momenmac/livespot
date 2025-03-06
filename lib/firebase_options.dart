import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase configuration options for the app
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // These are placeholder values - replace with your actual Firebase project configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:
        "AIzaSyAgUhHU8wSJgO5kJ15ZkP78vYsCcOUUvr8", // Replace with your API key
    authDomain: "demo-project.firebaseapp.com",
    projectId: "demo-project",
    storageBucket: "demo-project.appspot.com",
    messagingSenderId: "123456789012",
    appId: "1:123456789012:web:abc123def456ghi789",
    measurementId: "G-ABC123DEF45",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        "AIzaSyABCDEFGhIJklMNOPqrsTUVwxyz12345678", // Replace with your API key
    appId: "1:123456789012:android:abc123def456ghi789",
    messagingSenderId: "123456789012",
    projectId: "demo-project",
    storageBucket: "demo-project.appspot.com",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:
        "AIzaSyABCDEFGhIJklMNOPqrsTUVwxyz98765432", // Replace with your API key
    appId: "1:123456789012:ios:abc123def456ghi789",
    messagingSenderId: "123456789012",
    projectId: "demo-project",
    storageBucket: "demo-project.appspot.com",
    iosClientId:
        "123456789012-abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com",
    iosBundleId: "com.example.flutterApplication2",
  );
}
