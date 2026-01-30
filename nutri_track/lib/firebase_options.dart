// Archivo de opciones de Firebase.
// Para usar Firebase (Spark) con tu proyecto:
// 1. Crea un proyecto en https://console.firebase.google.com/
// 2. En la carpeta nutri_track ejecuta: dart pub global activate flutterfire_cli && flutterfire configure
// 3. Ese comando sobrescribirá este archivo con tus claves reales.
// Mientras tanto, este stub permite que la app compile; Firebase se inicializará con valores placeholder.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Stub: valores placeholder para compilación. Reemplazar con "flutterfire configure".
    return const FirebaseOptions(
      apiKey: 'AIzaSyDummyReplaceWithFlutterFireConfigure',
      appId: '1:000000000000:web:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'nutritrack-dummy',
      authDomain: 'nutritrack-dummy.firebaseapp.com',
      storageBucket: 'nutritrack-dummy.appspot.com',
    );
  }
}
