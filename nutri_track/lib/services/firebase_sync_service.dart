import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Servicio para sincronizar datos JSON con Firestore.
/// Misma API que SupabaseSyncService; usa colección "storage", doc id = nombre de archivo (con / → _).
class FirebaseSyncService {
  static const String _collection = 'storage';

  static String _docId(String fileName) =>
      fileName.replaceAll('/', '_');

  static final List<String> jsonFiles = [
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
    'chats.json',
  ];

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Sube un archivo JSON a Firestore
  Future<bool> uploadJsonFile(String fileName, Map<String, dynamic> data) async {
    try {
      final docRef = _firestore.collection(_collection).doc(_docId(fileName));
      await docRef.set({'data': data});
      print('✅ Archivo $fileName subido correctamente a Firestore');
      return true;
    } catch (e) {
      print('❌ Error uploading $fileName: $e');
      return false;
    }
  }

  /// Descarga un archivo JSON desde Firestore
  Future<dynamic> downloadJsonFile(String fileName) async {
    try {
      final docRef = _firestore.collection(_collection).doc(_docId(fileName));
      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!;
      if (data.containsKey('data')) {
        print('✅ Descargado $fileName desde Firestore');
        return data['data'];
      }
      return data;
    } catch (e) {
      print('⚠️ Error descargando $fileName: $e');
      return null;
    }
  }

  /// Sube todos los archivos JSON locales a Firestore
  Future<Map<String, bool>> uploadAllJsonFiles(
    Map<String, Map<String, dynamic>> localData,
  ) async {
    final results = <String, bool>{};
    for (final fileName in jsonFiles) {
      if (localData.containsKey(fileName)) {
        results[fileName] = await uploadJsonFile(fileName, localData[fileName]!);
      }
    }
    return results;
  }

  /// Descarga todos los archivos JSON desde Firestore
  Future<Map<String, Map<String, dynamic>>> downloadAllJsonFiles() async {
    final results = <String, Map<String, dynamic>>{};
    for (final fileName in jsonFiles) {
      final data = await downloadJsonFile(fileName);
      if (data != null) {
        if (data is List) {
          if (fileName == 'recipes.json' ||
              fileName == 'recipes_public.json' ||
              fileName == 'recipes_private.json') {
            results[fileName] = {'recipes': data};
          } else {
            results[fileName] = {fileName.replaceAll('.json', ''): data};
          }
        } else if (data is Map<String, dynamic>) {
          results[fileName] = data;
        } else if (data is Map) {
          results[fileName] = Map<String, dynamic>.from(data);
        }
      }
    }
    return results;
  }

  Future<void> saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_sync_time');
    if (timeString != null) return DateTime.tryParse(timeString);
    return null;
  }

  Future<bool> hasUpdatesAvailable() async {
    try {
      final lastSync = await getLastSyncTime();
      if (lastSync == null) return true;
      final timeSinceLastSync = DateTime.now().difference(lastSync);
      if (timeSinceLastSync.inHours > 1) return true;
      return false;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  Future<bool> saveToLocalCache(Map<String, Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        await prefs.setString('cache_${entry.key}', jsonEncode(entry.value));
        await prefs.setString(
            'cache_${entry.key}_timestamp', DateTime.now().toIso8601String());
      }
      return true;
    } catch (e) {
      print('❌ Error guardando datos localmente: $e');
      return false;
    }
  }

  Future<bool> syncToBackend(Map<String, Map<String, dynamic>> data) async {
    final localSuccess = await saveToLocalCache(data);
    try {
      final url = await AppConfig.getBackendUrl();
      final uri = Uri.parse('$url/sync/update-files');
      try {
        final healthCheck = await http
            .get(Uri.parse('$url/health'))
            .timeout(const Duration(seconds: 3));
        if (healthCheck.statusCode != 200) {
          print('⚠️ Backend no disponible, solo guardando localmente');
          return localSuccess;
        }
      } catch (_) {
        print('⚠️ Backend no disponible, solo guardando localmente');
        return localSuccess;
      }
      final authService = AuthService();
      final headers = await authService.getAuthHeaders();
      final response = await http
          .post(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('✅ Datos sincronizados con el backend y guardados localmente');
        return true;
      }
      return localSuccess;
    } catch (e) {
      print('⚠️ Error al enviar datos al backend: $e');
      return localSuccess;
    }
  }
}
