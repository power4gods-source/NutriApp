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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        return web;
    }
  }

  // REEMPLAZA ESTOS VALORES CON LOS DE TU PROYECTO FIREBASE
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDVI1fC0XOaBo5M-cmdnvg9tAbQVo-vAMk',
    appId: '1:329726047912:web:444fae8872073c3f2cb49d',
    messagingSenderId: '329726047912',
    projectId: 'nutritrack-aztqd',
    authDomain: 'nutritrack.firebaseapp.com',
    storageBucket: 'nutritrack.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjA4qUIgsYUOEafu_Y29ZxIKrHv7BzCVA',
    appId: '1:329726047912:android:16adaadb0ebf6a6c2cb49d',
    messagingSenderId: '329726047912',
    projectId: 'nutritrack-aztqd',
    storageBucket: 'nutritrack-aztqd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDVI1fC0XOaBo5M-cmdnvg9tAbQVo-vAMk',
    appId: '1:329726047912:web:444fae8872073c3f2cb49d',
    messagingSenderId: '329726047912',
    projectId: 'nutritrack-aztqd',
    storageBucket: 'nutritrack.appspot.com',
    iosBundleId: 'com.example.nutriTrack',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDVI1fC0XOaBo5M-cmdnvg9tAbQVo-vAMk',
    appId: '1:329726047912:web:444fae8872073c3f2cb49d',
    messagingSenderId: '329726047912',
    projectId: 'nutritrack-aztqd',
    storageBucket: 'nutritrack.appspot.com',
    iosBundleId: 'com.example.nutriTrack',
  );
}