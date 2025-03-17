import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not supported for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not supported for this app.');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not supported for this app.');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not supported for this app.');
      default:
        throw UnsupportedError(
          'Unknown platform ${defaultTargetPlatform.name} is not supported for this app.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyCw4B7orLCy8Fmdwym3O-jScIs_bUG9UUE', // Use same API key as iOS for now
    appId:
        '1:813529293309:android:1234567890abcdef', // Replace with your actual Android app ID
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
    iosBundleId:
        'com.example.flutterApplication2', // Make sure this matches your actual bundle ID
  );
}
