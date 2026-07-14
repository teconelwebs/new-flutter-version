// File generated manually from GoogleService-Info.plist / google-services.json.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDTiu5AOhxcKkAknRFTCBi5lORbeOq0WhU',
    appId: '1:1059196648931:android:4b961c149bcb0fb1aaf4d6',
    messagingSenderId: '1059196648931',
    projectId: 'shopping-welfog-6d808',
    storageBucket: 'shopping-welfog-6d808.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDry9joPY99y7RNDDDGlqrguMAEQevAMow',
    appId: '1:1059196648931:ios:4d592580d49b3f1aaaf4d6',
    messagingSenderId: '1059196648931',
    projectId: 'shopping-welfog-6d808',
    storageBucket: 'shopping-welfog-6d808.firebasestorage.app',
    iosBundleId: 'com.welfog.app',
  );
}
