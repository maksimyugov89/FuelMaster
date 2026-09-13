import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:fuelmaster/utils/env_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'yet.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions android = FirebaseOptions(
    apiKey: EnvConfig.require('FIREBASE_ANDROID_API_KEY'),
    appId: EnvConfig.require('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: EnvConfig.require('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: EnvConfig.require('FIREBASE_PROJECT_ID'),
    storageBucket: EnvConfig.require('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions ios = FirebaseOptions(
    apiKey: EnvConfig.require('FIREBASE_IOS_API_KEY'),
    appId: EnvConfig.require('FIREBASE_IOS_APP_ID'),
    messagingSenderId: EnvConfig.require('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: EnvConfig.require('FIREBASE_PROJECT_ID'),
    storageBucket: EnvConfig.require('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: EnvConfig.require('FIREBASE_IOS_BUNDLE_ID'),
  );
}
