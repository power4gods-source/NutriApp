import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'firebase_sync_service.dart';

/// Servicio que gestiona las fuentes de datos con fallback automático
/// Prioridad: Backend Local > Firestore > Datos Locales (SharedPreferences)
class DataSourceService {
  static const String baseUrl = 'http://localhost:8000';
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  
  // Cache de datos locales
  Map<String, dynamic>? _localCache;
  
  /// Verifica si el backend está disponible
  Future<bool> isBackendAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtiene datos con fallback automático
  Future<Map<String, dynamic>?> getData(String fileName) async {
    // 1. Intentar desde backend local
    if (await isBackendAvailable()) {
      try {
        final data = await _getFromBackend(fileName);
        if (data != null) {
          // Convertir a Map si es necesario
          Map<String, dynamic>? dataMap;
          if (data is Map<String, dynamic>) {
            dataMap = data;
          } else if (data is Map) {
            dataMap = Map<String, dynamic>.from(data);
          }
          if (dataMap != null) {
            // Guardar en cache local
            await _saveToLocalCache(fileName, dataMap);
            return dataMap;
          }
        }
      } catch (e) {
        print('Error obteniendo desde backend: $e');
      }
    }
    
    // 2. Intentar desde Firestore
    try {
      final data = await _firebaseService.downloadJsonFile(fileName);
      if (data != null) {
        // Convertir a Map si es necesario
        Map<String, dynamic>? dataMap;
        if (data is Map<String, dynamic>) {
          dataMap = data;
        } else if (data is Map) {
          dataMap = Map<String, dynamic>.from(data);
        }
        if (dataMap != null) {
          // Guardar en cache local
          await _saveToLocalCache(fileName, dataMap);
          return dataMap;
        }
      }
    } catch (e) {
      print('Error obteniendo desde Firestore: $e');
    }
    
    // 3. Usar datos locales (cache)
    return await _getFromLocalCache(fileName);
  }
  
  /// Obtiene datos desde el backend
  Future<dynamic> _getFromBackend(String fileName) async {
    try {
      // Mapeo de archivos a endpoints
      final endpointMap = {
        'recipes.json': '/recipes/general',
        'foods.json': '/tracking/foods',
        'users.json': '/users',
        'profiles.json': '/profile',
      };
      
      final endpoint = endpointMap[fileName];
      if (endpoint == null) return null;
      
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error en _getFromBackend: $e');
    }
    return null;
  }
  
  /// Guarda datos en cache local
  Future<void> _saveToLocalCache(String fileName, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('cache_$fileName', jsonString);
      await prefs.setString('cache_${fileName}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error guardando en cache: $e');
    }
  }
  
  /// Obtiene datos desde cache local
  Future<Map<String, dynamic>?> _getFromLocalCache(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cache_$fileName');
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error obteniendo desde cache: $e');
    }
    return null;
  }
  
  /// Obtiene la fecha de última actualización del cache
  Future<DateTime?> getCacheTimestamp(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString('cache_${fileName}_timestamp');
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      print('Error obteniendo timestamp: $e');
    }
    return null;
  }
  
  /// Limpia el cache local
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error limpiando cache: $e');
    }
  }
  
  /// Sincroniza todos los datos desde Firestore y los guarda localmente
  Future<Map<String, bool>> syncAllFromFirestore() async {
    final results = <String, bool>{};
    
    for (final fileName in FirebaseSyncService.jsonFiles) {
      try {
        final data = await _firebaseService.downloadJsonFile(fileName);
        if (data != null) {
          // Convertir a Map si es necesario
          Map<String, dynamic>? dataMap;
          if (data is Map<String, dynamic>) {
            dataMap = data;
          } else if (data is Map) {
            dataMap = Map<String, dynamic>.from(data);
          } else if (data is List) {
            // Si es una lista (como recipes.json), convertir a formato Map
            dataMap = {'recipes': data};
          }
          if (dataMap != null) {
            await _saveToLocalCache(fileName, dataMap);
            results[fileName] = true;
          } else {
            results[fileName] = false;
          }
        } else {
          results[fileName] = false;
        }
      } catch (e) {
        print('Error sincronizando $fileName: $e');
        results[fileName] = false;
      }
    }
    
    return results;
  }
}

