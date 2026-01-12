import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Servicio para sincronizar datos JSON con Firebase
/// Permite subir y descargar archivos JSON desde Firebase Storage
class FirebaseSyncService {
  FirebaseStorage? _storage;
  FirebaseFirestore? _firestore;
  
  // Verificar si Firebase está disponible
  bool get _isFirebaseAvailable {
    try {
      _storage ??= FirebaseStorage.instance;
      _firestore ??= FirebaseFirestore.instance;
      return true;
    } catch (e) {
      return false;
    }
  }
  
  FirebaseStorage get storage {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase no está configurado');
    }
    return _storage!;
  }
  
  FirebaseFirestore get firestore {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase no está configurado');
    }
    return _firestore!;
  }
  
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
  ];

  /// Sube un archivo JSON a Firebase Storage
  Future<bool> uploadJsonFile(String fileName, Map<String, dynamic> data) async {
    if (!_isFirebaseAvailable) {
      print('⚠️ Firebase no disponible, no se puede subir $fileName');
      return false;
    }
    try {
      final jsonString = jsonEncode(data);
      final ref = storage.ref().child('data/$fileName');
      
      // Configurar timeout más largo y retry para operaciones críticas
      final uploadTask = ref.putString(
        jsonString,
        metadata: SettableMetadata(contentType: 'application/json'),
      );
      
      // Esperar con timeout extendido (60 segundos para operaciones críticas)
      await uploadTask.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ Timeout al subir $fileName (60s)');
          throw TimeoutException('Timeout al subir $fileName');
        },
      );
      
      // Verificar que la subida se completó correctamente
      await uploadTask;
      
      // Guardar metadata en Firestore con timeout
      await firestore.collection('sync_metadata').doc(fileName).set({
        'fileName': fileName,
        'lastUpdated': FieldValue.serverTimestamp(),
        'size': jsonString.length,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⚠️ Timeout al guardar metadata de $fileName, pero el archivo se subió');
          // No lanzar error, el archivo ya se subió
        },
      );
      
      print('✅ Archivo $fileName subido correctamente (${jsonString.length} bytes)');
      return true;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('retry-limit-exceeded')) {
        print('❌ Error: Firebase Storage alcanzó el límite de reintentos para $fileName');
        print('   Esto puede deberse a problemas de conexión. Intenta nuevamente más tarde.');
      } else if (errorStr.contains('TimeoutException')) {
        print('❌ Timeout al subir $fileName');
      } else {
        print('❌ Error uploading $fileName: $e');
      }
      return false;
    }
  }

  /// Descarga un archivo JSON desde Firebase Storage
  /// Puede devolver Map o List dependiendo del contenido del archivo
  Future<dynamic> downloadJsonFile(String fileName) async {
    if (!_isFirebaseAvailable) {
      print('⚠️ Firebase no disponible, no se puede descargar $fileName');
      return null;
    }
    try {
      final ref = storage.ref().child('data/$fileName');
      
      // Intentar descargar con getData
      // Nota: getData() puede fallar si hay problemas de permisos o conexión
      try {
        final bytes = await ref.getData().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Timeout silencioso - no imprimir para evitar spam
            return null;
          },
        );
        
        if (bytes != null && bytes.isNotEmpty) {
          try {
            final jsonString = utf8.decode(bytes);
            final data = jsonDecode(jsonString);
            print('✅ Descargado $fileName desde Firebase (${bytes.length} bytes)');
            return data;
          } catch (e) {
            print('❌ Error parseando JSON de $fileName: $e');
            return null;
          }
        } else {
          // Archivo vacío o no encontrado - no imprimir (es normal para algunos archivos)
          return null;
        }
      } catch (e) {
        // Manejar errores específicos de Firebase Storage
        final errorStr = e.toString();
        if (errorStr.contains('permission-denied') || errorStr.contains('unauthorized')) {
          print('❌ Error de permisos al descargar $fileName');
          print('   Ve a Firebase Console > Storage > Reglas y permite lectura');
        } else if (errorStr.contains('object-not-found')) {
          // Archivo no encontrado - no imprimir (es normal si no está subido)
          return null;
        } else if (!errorStr.contains('TimeoutException') && !errorStr.contains('retry-limit-exceeded')) {
          // Solo imprimir errores inesperados
          print('⚠️ Error descargando $fileName: $e');
        }
        return null;
      }
    } catch (e) {
      // Error general
      print('❌ Error general descargando $fileName: $e');
      return null;
    }
  }

  /// Sube todos los archivos JSON locales a Firebase
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

  /// Descarga todos los archivos JSON desde Firebase
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

  /// Obtiene la fecha de última actualización de un archivo
  Future<DateTime?> getLastUpdated(String fileName) async {
    if (!_isFirebaseAvailable) {
      return null;
    }
    try {
      final doc = await firestore
          .collection('sync_metadata')
          .doc(fileName)
          .get();
      
      if (doc.exists) {
        final timestamp = doc.data()?['lastUpdated'] as Timestamp?;
        return timestamp?.toDate();
      }
      return null;
    } catch (e) {
      print('Error getting last updated for $fileName: $e');
      return null;
    }
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

  /// Verifica si hay actualizaciones disponibles en Firebase
  Future<bool> hasUpdatesAvailable() async {
    try {
      final lastSync = await getLastSyncTime();
      if (lastSync == null) return true;

      for (final fileName in jsonFiles) {
        final lastUpdated = await getLastUpdated(fileName);
        if (lastUpdated != null && lastUpdated.isAfter(lastSync)) {
          return true;
        }
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
          return localSuccess; // Devolver éxito si se guardó localmente
        }
      } catch (e) {
        print('⚠️ Backend no disponible, solo guardando localmente');
        return localSuccess; // Devolver éxito si se guardó localmente
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
        return localSuccess; // Devolver éxito si se guardó localmente
      }
    } catch (e) {
      print('⚠️ Error al enviar datos al backend: $e. Datos guardados localmente.');
      return localSuccess; // Devolver éxito si se guardó localmente
    }
  }
}

