import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Servicio para registrar el token FCM y recibir notificaciones push.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Solicita permisos, obtiene el token y lo envía al backend.
  /// Llamar tras login o al iniciar la app si el usuario está autenticado.
  static Future<void> registerFcmToken(AuthService authService) async {
    if (kIsWeb) return; // FCM en web requiere configuración adicional

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(authService, token);
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        if (authService.isAuthenticated) {
          await _sendTokenToBackend(authService, newToken);
        }
      });
    } catch (e) {
      debugPrint('FCM: Error registrando token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(AuthService authService, String token) async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$url/profile/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': token}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('FCM: Token enviado al backend correctamente');
      } else {
        debugPrint('FCM: Error enviando token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FCM: Error enviando token al backend: $e');
    }
  }
}
