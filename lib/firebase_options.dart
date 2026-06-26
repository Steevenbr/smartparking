import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyClQ3F41QCwrNEBI5MxOkUu5WA9nwWK7BE",
    authDomain: "smartparking-app-70441.firebaseapp.com",
    projectId: "smartparking-app-70441",
    storageBucket: "smartparking-app-70441.firebasestorage.app",
    messagingSenderId: "983202249416",
    appId: "1:983202249416:web:c0194bfc0ae83643b883fd",
    measurementId: "G-0LKXCGHJRB",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyClQ3F41QCwrNEBI5MxOkUu5WA9nwWK7BE",
    projectId: "smartparking-app-70441",
    storageBucket: "smartparking-app-70441.firebasestorage.app",
    messagingSenderId: "983202249416",
    appId: "1:983202249416:web:c0194bfc0ae83643b883fd",
  );
}