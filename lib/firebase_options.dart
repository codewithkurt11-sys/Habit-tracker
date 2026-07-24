// Firebase configuration for project habit-tracker-37dc1.
// Values are sourced from the registered Firebase Android and Web apps.
// Android's values match android/app/google-services.json.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpGP55VgdMHAnjZHf1fTJCntil_MNDSnQ',
    appId: '1:687760012800:web:f56dda669eeed3cb474ae5',
    messagingSenderId: '687760012800',
    projectId: 'habit-tracker-37dc1',
    authDomain: 'habit-tracker-37dc1.firebaseapp.com',
    storageBucket: 'habit-tracker-37dc1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB0ar7s2C_KAppz-dskZJR5rEvx3Y1vv9o',
    appId: '1:687760012800:android:8fbe9d46ed567d2b474ae5',
    messagingSenderId: '687760012800',
    projectId: 'habit-tracker-37dc1',
    storageBucket: 'habit-tracker-37dc1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholder-ios-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'habit-tracker-37dc1',
    storageBucket: 'habit-tracker-37dc1.appspot.com',
    iosBundleId: 'com.yourself.habits',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholder-macos-key',
    appId: '1:000000000000:macos:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'habit-tracker-37dc1',
    storageBucket: 'habit-tracker-37dc1.appspot.com',
    iosBundleId: 'com.yourself.habits',
  );
}
