/// Login con Google y Apple.
/// Esta versión es un STUB que compila sin los paquetes google_sign_in y sign_in_with_apple.
/// Para activar login real:
/// 1. Añade en pubspec.yaml: google_sign_in: ^6.2.2 y sign_in_with_apple: ^6.1.3
/// 2. Ejecuta en la carpeta nutri_track: flutter pub get
/// 3. Sustituye el contenido de este archivo por el de social_auth_google_apple_REAL.dart.example

import 'auth_service.dart';

class SocialAuthGoogleApple {
  static const String _hint = 'Añade google_sign_in y sign_in_with_apple al pubspec.yaml, ejecuta flutter pub get en la carpeta nutri_track, y sustituye este archivo por la implementación real (ver social_auth_google_apple_REAL.dart.example).';

  static Future<Map<String, dynamic>> loginWithGoogle(AuthService auth) async {
    return {
      'success': false,
      'error': 'Inicio con Google no disponible. $_hint',
    };
  }

  static Future<Map<String, dynamic>> loginWithApple(AuthService auth) async {
    return {
      'success': false,
      'error': 'Inicio con Apple no disponible. $_hint',
    };
  }
}
