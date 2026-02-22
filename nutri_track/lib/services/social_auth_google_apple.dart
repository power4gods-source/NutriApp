/// Login con Google vía Supabase Auth (signInWithOAuth).
/// Tras el login en Supabase, el backend valida el token y emite JWT propio.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

class SocialAuthGoogleApple {
  /// Login con Google usando Supabase signInWithOAuth.
  /// En móvil abre el navegador; al volver, obtiene sesión y llama al backend.
  static Future<Map<String, dynamic>> loginWithGoogle(AuthService auth) async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {}

    try {
      final client = Supabase.instance.client;
      Session? session;

      // En móvil, signInWithOAuth abre el navegador. Esperamos la sesión vía onAuthStateChange.
      final completer = Completer<Session?>();
      late StreamSubscription<AuthState> sub;
      sub = client.auth.onAuthStateChange.listen((data) {
        if (data.session != null && !completer.isCompleted) {
          completer.complete(data.session);
        }
      });

      await client.auth.signInWithOAuth(OAuthProvider.google);

      session = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
      await sub.cancel();

      session ??= client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        return {'success': false, 'error': 'No se completó el inicio de sesión con Google'};
      }

      final url = await auth.baseUrl;
      final httpResponse = await http.post(
        Uri.parse('$url/auth/supabase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': session.accessToken}),
      ).timeout(const Duration(seconds: 15));

      if (httpResponse.statusCode == 200) {
        final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        await auth.saveAuthDataFromMap(data);
        return {'success': true, 'data': data};
      }

      final err = jsonDecode(httpResponse.body);
      return {
        'success': false,
        'error': err['detail'] ?? err['error'] ?? 'Error al iniciar sesión con Google',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> loginWithApple(AuthService auth) async {
    return {
      'success': false,
      'error': 'Inicio con Apple no disponible. Usa Supabase Auth o google_sign_in.',
    };
  }
}
