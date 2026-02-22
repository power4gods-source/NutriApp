import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Configuración de la aplicación
/// Permite configurar la URL del backend para diferentes entornos
class AppConfig {
  static const String _backendUrlKey = 'backend_url';

  /// Logo de la app en Firebase Storage - data/Cookind.png (incrementar _logoVersion al actualizar)
  static const int _logoVersion = 2;
  static String get logoFirebaseUrl =>
      'https://firebasestorage.googleapis.com/v0/b/nutritrack-aztqd.firebasestorage.app/o/data%2FCookind.png?alt=media&v=$_logoVersion';

  /// Imagen por defecto para recetas sin foto - data/backup.png en Firebase Storage
  static const String backupPhotoFirebaseUrl =
      'https://firebasestorage.googleapis.com/v0/b/nutritrack-aztqd.firebasestorage.app/o/data%2Fbackup.png?alt=media';

  /// Supabase - Auth (Google OAuth). Reemplaza con tu proyecto.
  static const String supabaseUrl = 'https://gxdzybyszpebhlspwiyz.supabase.co';
  static const String supabaseAnonKey = 'TU_SUPABASE_ANON_KEY'; // Settings → API → anon public
  
  // URLs por defecto según la plataforma
  static String get defaultBackendUrl {
    // Usar Render como backend principal (siempre disponible)
    const String renderUrl = 'https://nutriapp-470k.onrender.com';
    
    if (kIsWeb) {
      // En web, usar Render directamente
      return renderUrl;
    } else {
      // En móvil, usar Render directamente
      // La app intentará Render primero, luego fallback a local si es necesario
      return renderUrl;
      
      // Nota: Si quieres usar backend local para desarrollo, puedes cambiar esto a:
      // return 'http://10.0.2.2:8000'; // Android Emulator
      // return 'http://192.168.1.134:8000'; // IP local del PC
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
      // 'https://nutriapp-470k.onrender.com', // Render (producción)
      'https://cookind-production.up.railway.app', // Railway (producción) 
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

