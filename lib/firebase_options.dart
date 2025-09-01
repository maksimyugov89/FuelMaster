import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions have not been configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-WN5G-BZ4jXa7HJ47QLf_qGVqebUserc',
    appId: '1:619524253699:android:2a62bb1d5d95a788b0c636',
    messagingSenderId: '619524253699',
    projectId: 'fuelmaster-984fb',
    storageBucket: 'fuelmaster-984fb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '619524253699',
    projectId: 'fuelmaster-984fb',
    storageBucket: 'fuelmaster-984fb.firebasestorage.app',
    iosBundleId: 'com.example.fuelmaster',
  );
}