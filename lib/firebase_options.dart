import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
          'DefaultFirebaseOptions have not been configured for macos - '
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

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyBX9NWqWe-gn51e-Hh69617rBUXK9Q38Bs",
      authDomain: "livespot-b1eb4.firebaseapp.com",
      projectId: "livespot-b1eb4",
      storageBucket: "livespot-b1eb4.firebasestorage.app",
      messagingSenderId: "813529293309",
      appId: "1:813529293309:web:46f5d27446a52292583994",
      measurementId: "G-TR331VFEQ6");

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqJRKJ3mFY0C7onZdDzW1pX-SYB4ts-rA',
    appId: '1:813529293309:android:ad33ed367ab91367583994',
    messagingSenderId: '813529293309',
    projectId: 'livespot-b1eb4',
    storageBucket: 'livespot-b1eb4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCw4B7orLCy8Fmdwym3O-jScIs_bUG9UUE',
    appId: '1:813529293309:ios:761f2bdd7d94011a583994',
    messagingSenderId: '813529293309',
    projectId: 'livespot-b1eb4',
    storageBucket: 'livespot-b1eb4.firebasestorage.app',
    iosClientId:
        '813529293309-e6au6bm35phan94i7l5uhf9d8h4a3ka6.apps.googleusercontent.com',
    iosBundleId: 'com.example.flutterApplication2',
  );
}
