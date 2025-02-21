import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyCw4B7orLCy8Fmdwym3O-jScIs_bUG9UUE",
        appId: "1:813529293309:web:YOUR_WEB_APP_ID",
        messagingSenderId: "813529293309",
        projectId: "livespot-b1eb4",
        authDomain: "livespot-b1eb4.firebaseapp.com",
      );
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          // Android configuration
          return const FirebaseOptions(
            apiKey: "AIzaSyAqJRKJ3mFY0C7onZdDzW1pX-SYB4ts-rA",
            appId: "1:813529293309:android:ad33ed367ab91367583994",
            messagingSenderId: "813529293309",
            projectId: "livespot-b1eb4",
          );
        case TargetPlatform.iOS:
          // iOS configuration
          return const FirebaseOptions(
            apiKey: "AIzaSyCw4B7orLCy8Fmdwym3O-jScIs_bUG9UUE",
            appId: "1:813529293309:ios:761f2bdd7d94011a583994",
            messagingSenderId: "813529293309",
            projectId: "livespot-b1eb4",
            iosBundleId: "io.flutter.flutter.app",
          );
        default:
          throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.',
          );
      }
    }
  }
}
