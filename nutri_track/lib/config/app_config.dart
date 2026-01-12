import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Configuración de la aplicación
/// Permite configurar la URL del backend para diferentes entornos
class AppConfig {
  static const String _backendUrlKey = 'backend_url';
  
  // URLs por defecto según la plataforma
  static String get defaultBackendUrl {
    if (kIsWeb) {
      // En web, usar localhost
      return 'http://localhost:8000';
    } else {
      // En móvil, intentar detectar si es emulador o dispositivo físico
      // Para Android Emulator: 10.0.2.2 apunta al localhost del PC
      // Para dispositivo físico: usar IP del PC (debe estar en la misma red)
      // Por defecto, intentar con 10.0.2.2 (emulador)
      // Si no funciona, el usuario puede configurar la IP manualmente
      return 'http://10.0.2.2:8000'; // Android Emulator por defecto
      // Para dispositivo físico, el usuario debe configurar la IP del PC manualmente
      // o usar Firebase como fuente principal de datos
    }
  }
  
  /// Intenta detectar automáticamente la IP del backend
  /// Prueba varias URLs comunes para encontrar el backend
  static Future<String?> detectBackendUrl() async {
    final urlsToTry = <String>[];
    
    // 1. Primero intentar con la IP guardada previamente
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_backendUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        urlsToTry.add(savedUrl);
        print('🔍 Intentando con URL guardada: $savedUrl');
      }
    } catch (e) {
      print('Error obteniendo URL guardada: $e');
    }
    
    // 2. URLs comunes para diferentes entornos
    urlsToTry.addAll([
      'http://10.0.2.2:8000', // Android Emulator
      'http://localhost:8000', // Web / Local
      'http://127.0.0.1:8000', // Localhost alternativo
    ]);
    
    // 3. Intentar detectar IPs comunes en la red local (192.168.x.x)
    // Nota: En producción, esto debería ser configurado manualmente por el usuario
    // o usar un servicio de descubrimiento de red
    try {
      // Intentar algunas IPs comunes de red local
      final commonIPs = ['192.168.1.100', '192.168.1.101', '192.168.0.100', '192.168.0.101'];
      for (final ip in commonIPs) {
        urlsToTry.add('http://$ip:8000');
      }
    } catch (e) {
      // Ignorar errores al generar IPs
    }
    
    print('🔍 Intentando detectar backend en ${urlsToTry.length} URLs...');
    
    // Probar cada URL
    for (final url in urlsToTry) {
      try {
        print('🔍 Probando: $url');
        final response = await http.get(
          Uri.parse('$url/health'),
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          print('✅ Backend detectado en: $url');
          await setBackendUrl(url);
          return url;
        }
      } catch (e) {
        // Continuar con la siguiente URL
        continue;
      }
    }
    
    print('⚠️ No se pudo detectar el backend automáticamente');
    return null;
  }
  
  /// Obtiene la URL del backend configurada
  static Future<String> getBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_backendUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        return savedUrl;
      }
    } catch (e) {
      print('Error obteniendo URL del backend: $e');
    }
    return defaultBackendUrl;
  }
  
  /// Guarda la URL del backend
  static Future<void> setBackendUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backendUrlKey, url);
    } catch (e) {
      print('Error guardando URL del backend: $e');
    }
  }
  
  /// Resetea la URL del backend al valor por defecto
  static Future<void> resetBackendUrl() async {
    await setBackendUrl(defaultBackendUrl);
  }
  
  /// Verifica si una URL es válida
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

