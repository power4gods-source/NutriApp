import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

/// Servicio para sincronizar datos JSON con Supabase Storage
/// Reemplaza a FirebaseSyncService
class SupabaseSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Lista de archivos JSON que se sincronizarán
  static const List<String> jsonFiles = [
    'recipes.json',
    'foods.json',
    'users.json',
    'profiles.json',
    'consumption_history.json',
    'meal_plans.json',
    'nutrition_stats.json',
    'user_goals.json',
    'ingredient_food_mapping.json',
    'recipes_public.json',
    'recipes_private.json',
    'followers.json',
  ];

  /// Sube un archivo JSON a Supabase Storage
  Future<bool> uploadJsonFile(String fileName, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      // Subir al bucket 'data' en Supabase Storage
      final path = fileName.startsWith('users/') ? fileName : 'data/$fileName';
      
      print('📤 Subiendo $path a Supabase Storage...');
      
      await _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true, // Sobrescribir si existe
            ),
          );
      
      print('✅ Archivo $fileName subido correctamente (${bytes.length} bytes)');
      return true;
    } catch (e) {
      print('❌ Error uploading $fileName: $e');
      return false;
    }
  }

  /// Descarga un archivo JSON desde Supabase Storage
  /// Puede devolver Map o List dependiendo del contenido del archivo
  Future<dynamic> downloadJsonFile(String fileName) async {
    try {
      final path = fileName.startsWith('users/') ? fileName : 'data/$fileName';
      
      print('📥 Descargando $path desde Supabase Storage...');
      
      final bytes = await _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .download(path);
      
      if (bytes != null && bytes.isNotEmpty) {
        try {
          final jsonString = utf8.decode(bytes);
          final data = jsonDecode(jsonString);
          print('✅ Descargado $fileName desde Supabase (${bytes.length} bytes)');
          return data;
        } catch (e) {
          print('❌ Error parseando JSON de $fileName: $e');
          return null;
        }
      } else {
        print('⚠️ Archivo $fileName vacío o no encontrado');
        return null;
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('not found') || errorStr.contains('404')) {
        // Archivo no encontrado - es normal si no está subido
        return null;
      }
      print('⚠️ Error descargando $fileName: $e');
      return null;
    }
  }

  /// Sube todos los archivos JSON locales a Supabase
  Future<Map<String, bool>> uploadAllJsonFiles(
    Map<String, Map<String, dynamic>> localData,
  ) async {
    final results = <String, bool>{};
    
    for (final fileName in jsonFiles) {
      if (localData.containsKey(fileName)) {
        final success = await uploadJsonFile(fileName, localData[fileName]!);
        results[fileName] = success;
      }
    }
    
    return results;
  }

  /// Descarga todos los archivos JSON desde Supabase
  /// Convierte Lists a Maps cuando sea necesario para mantener consistencia
  Future<Map<String, Map<String, dynamic>>> downloadAllJsonFiles() async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final fileName in jsonFiles) {
      final data = await downloadJsonFile(fileName);
      if (data != null) {
        // Convertir List a Map si es necesario
        if (data is List) {
          // Archivos que son arrays (como recipes.json)
          if (fileName == 'recipes.json') {
            results[fileName] = {'recipes': data};
          } else if (fileName == 'recipes_public.json') {
            results[fileName] = {'recipes': data};
          } else if (fileName == 'recipes_private.json') {
            results[fileName] = {'recipes': data};
          } else {
            // Para otros archivos que sean arrays, usar el nombre del archivo como clave
            results[fileName] = {fileName.replaceAll('.json', ''): data};
          }
        } else if (data is Map<String, dynamic>) {
          results[fileName] = data;
        } else if (data is Map) {
          // Convertir Map genérico a Map<String, dynamic>
          results[fileName] = Map<String, dynamic>.from(data);
        } else {
          print('⚠️ Tipo de dato inesperado para $fileName: ${data.runtimeType}');
        }
      }
    }
    
    return results;
  }

  /// Guarda la última fecha de sincronización localmente
  Future<void> saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }

  /// Obtiene la última fecha de sincronización local
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_sync_time');
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  /// Verifica si hay actualizaciones disponibles en Supabase
  /// Compara la última sincronización local con los archivos en Supabase
  Future<bool> hasUpdatesAvailable() async {
    try {
      final lastSync = await getLastSyncTime();
      if (lastSync == null) return true; // Si nunca se sincronizó, hay actualizaciones

      // Por ahora, siempre retornamos true si hay archivos en Supabase
      // En el futuro se puede implementar comparación de timestamps
      // Para Supabase Storage, no hay metadata fácil de timestamps sin consultar cada archivo
      // Por simplicidad, retornamos true si nunca se sincronizó o si pasó mucho tiempo
      final timeSinceLastSync = DateTime.now().difference(lastSync);
      if (timeSinceLastSync.inHours > 1) {
        return true; // Si pasó más de 1 hora, asumimos que puede haber actualizaciones
      }
      
      return false;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  /// Guarda los datos descargados localmente en SharedPreferences
  Future<bool> saveToLocalCache(Map<String, Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (final entry in data.entries) {
        final fileName = entry.key;
        final fileData = entry.value;
        
        // Guardar cada archivo en cache local
        await prefs.setString('cache_$fileName', jsonEncode(fileData));
        await prefs.setString('cache_${fileName}_timestamp', DateTime.now().toIso8601String());
        print('✅ Guardado localmente: $fileName');
      }
      
      return true;
    } catch (e) {
      print('❌ Error guardando datos localmente: $e');
      return false;
    }
  }

  /// Envía los datos descargados al backend para que los guarde localmente (opcional)
  /// Si el backend no está disponible, solo guarda localmente
  Future<bool> syncToBackend(Map<String, Map<String, dynamic>> data) async {
    // Primero, guardar localmente siempre
    final localSuccess = await saveToLocalCache(data);
    
    // Luego, intentar enviar al backend si está disponible
    try {
      final url = await AppConfig.getBackendUrl();
      final uri = Uri.parse('$url/sync/update-files');
      
      // Verificar si el backend está disponible con un timeout corto
      try {
        final healthCheck = await http.get(
          Uri.parse('$url/health'),
        ).timeout(const Duration(seconds: 3));
        
        if (healthCheck.statusCode != 200) {
          print('⚠️ Backend no disponible, solo guardando localmente');
          return localSuccess;
        }
      } catch (e) {
        print('⚠️ Backend no disponible, solo guardando localmente');
        return localSuccess;
      }
      
      // Si el backend está disponible, intentar enviar los datos
      final authService = AuthService();
      final headers = await authService.getAuthHeaders();
      
      final response = await http.post(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Datos sincronizados con el backend y guardados localmente');
        return true;
      } else {
        print('⚠️ Error al sincronizar con backend (${response.statusCode}), pero guardado localmente');
        return localSuccess;
      }
    } catch (e) {
      print('⚠️ Error al enviar datos al backend: $e. Datos guardados localmente.');
      return localSuccess;
    }
  }
}
