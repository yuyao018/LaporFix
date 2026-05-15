// TODO: Replace this file with the output of `flutterfire configure`
// Run: dart pub global activate flutterfire_cli
// Then: flutterfire configure
//
// This is a placeholder so the project compiles.
// You MUST replace it with your actual Firebase project configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjJSgOYMwdNf6FcKl-80bN-OtlBNLtao8',
    appId: '1:867769554499:android:e0b5c4f1052ffaf354e6f6',
    messagingSenderId: '867769554499',
    projectId: 'laporfix',
    storageBucket: 'laporfix.firebasestorage.app',
  );

  // TODO: Replace with your actual Firebase config values

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCP-c8o8iqWWWGVrsGBRaBHRNxt6vY3CPU',
    appId: '1:867769554499:ios:251e470bf9c1b66654e6f6',
    messagingSenderId: '867769554499',
    projectId: 'laporfix',
    storageBucket: 'laporfix.firebasestorage.app',
    iosBundleId: 'com.example.group2Urbanfix',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR-API-KEY',
    appId: 'YOUR-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    storageBucket: 'YOUR-STORAGE-BUCKET',
    authDomain: 'YOUR-AUTH-DOMAIN',
  );
}