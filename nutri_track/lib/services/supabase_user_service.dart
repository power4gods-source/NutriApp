import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_sync_service.dart';

/// Servicio para gestionar usuarios y sus datos en Supabase
/// Reemplaza a FirebaseUserService
class SupabaseUserService {
  final SupabaseSyncService _supabaseService = SupabaseSyncService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Registra un nuevo usuario en Supabase
  /// Usa Supabase Auth para el registro y Storage para los datos del usuario
  Future<bool> registerUser({
    required String userId,
    required String email,
    required String passwordHash,
    String? username,
  }) async {
    try {
      print('📝 Iniciando registro de usuario en Supabase: $email');
      
      // Intentar registro con Supabase Auth (opcional - usamos Storage principalmente)
      // Nota: Supabase Auth requiere la contraseña real, no el hash
      // Por ahora, solo guardamos en Storage para mantener compatibilidad
      // Si quieres usar Supabase Auth, necesitarías pasar la contraseña real aquí
      
      // Crear estructura inicial de datos del usuario en Storage
      final userData = {
        'user_id': userId,
        'email': email.toLowerCase().trim(),
        'password_hash': passwordHash,
        'username': username ?? email.split('@')[0],
        'ingredients': [],
        'favorites': [],
        'goals': {},
        'shopping_list': [],
        'private_recipes': [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      print('📤 Subiendo datos del usuario a Supabase Storage...');
      
      // Guardar en Storage
      final uploadSuccess = await _supabaseService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
      
      if (uploadSuccess) {
        print('✅ Usuario registrado en Supabase Storage: $email');
        return true;
      } else {
        print('⚠️ Fallo al subir a Storage');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error registrando usuario en Supabase: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Obtiene un usuario desde Supabase Storage
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final userData = await getUserData(userId);
      return userData;
    } catch (e) {
      print('Error obteniendo usuario desde Supabase: $e');
      return null;
    }
  }
  
  /// Verifica credenciales de usuario desde Storage
  /// Compara el hash de la contraseña almacenado
  Future<bool> verifyUser(String email, String passwordHash) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final userId = _generateUserIdFromEmail(normalizedEmail);
      final userData = await getUserData(userId);
      
      if (userData == null) return false;
      
      // Comparar hash de contraseña
      final storedHash = userData['password_hash'] as String?;
      return storedHash != null && storedHash == passwordHash;
    } catch (e) {
      print('Error verificando usuario en Supabase: $e');
      return false;
    }
  }
  
  /// Obtiene el userId desde el email
  Future<String?> getUserIdFromEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final userId = _generateUserIdFromEmail(normalizedEmail);
      
      // Verificar que el usuario existe
      final userData = await getUserData(userId);
      if (userData != null && userData['email'] == normalizedEmail) {
        return userId;
      }
      return null;
    } catch (e) {
      print('Error obteniendo userId desde email: $e');
      return null;
    }
  }
  
  /// Genera userId desde email (mismo formato que auth_service)
  String _generateUserIdFromEmail(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_');
  }
  
  /// Guarda datos del usuario en Supabase Storage
  Future<bool> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      userData['updated_at'] = DateTime.now().toIso8601String();
      print('💾 Guardando datos del usuario $userId en Supabase Storage...');
      final success = await _supabaseService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
      if (success) {
        print('✅ Datos del usuario $userId guardados correctamente en Supabase');
      } else {
        print('❌ Error al guardar datos del usuario $userId en Supabase');
      }
      return success;
    } catch (e) {
      print('❌ Error guardando datos del usuario: $e');
      return false;
    }
  }
  
  /// Obtiene datos del usuario desde Supabase Storage
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final data = await _supabaseService.downloadJsonFile('users/$userId.json');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }
  
  /// Sincroniza ingredientes del usuario
  Future<bool> syncUserIngredients(String userId, List<dynamic> ingredients) async {
    try {
      final userData = await getUserData(userId) ?? {
        'user_id': userId,
        'ingredients': [],
      };
      
      userData['ingredients'] = ingredients;
      return await saveUserData(userId, userData);
    } catch (e) {
      print('Error sincronizando ingredientes: $e');
      return false;
    }
  }
  
  /// Sincroniza favoritos del usuario
  Future<bool> syncUserFavorites(String userId, List<String> favoriteIds) async {
    try {
      final userData = await getUserData(userId) ?? {
        'user_id': userId,
        'favorites': [],
      };
      
      userData['favorites'] = favoriteIds;
      return await saveUserData(userId, userData);
    } catch (e) {
      print('Error sincronizando favoritos: $e');
      return false;
    }
  }
  
  /// Sincroniza objetivos nutricionales del usuario
  Future<bool> syncUserGoals(String userId, Map<String, dynamic> goals) async {
    try {
      final userData = await getUserData(userId) ?? {
        'user_id': userId,
        'goals': {},
      };
      
      userData['goals'] = goals;
      return await saveUserData(userId, userData);
    } catch (e) {
      print('Error sincronizando objetivos: $e');
      return false;
    }
  }
  
  /// Sincroniza la cesta de la compra del usuario
  Future<bool> syncUserShoppingList(String userId, List<dynamic> shoppingList) async {
    try {
      final userData = await getUserData(userId) ?? {
        'user_id': userId,
        'shopping_list': [],
      };
      
      userData['shopping_list'] = shoppingList;
      return await saveUserData(userId, userData);
    } catch (e) {
      print('Error sincronizando cesta de la compra: $e');
      return false;
    }
  }
  
  /// Sincroniza recetas privadas del usuario
  Future<bool> syncUserPrivateRecipes(String userId, List<dynamic> privateRecipes) async {
    try {
      final userData = await getUserData(userId) ?? {
        'user_id': userId,
        'private_recipes': [],
      };
      
      userData['private_recipes'] = privateRecipes;
      return await saveUserData(userId, userData);
    } catch (e) {
      print('Error sincronizando recetas privadas: $e');
      return false;
    }
  }
  
  /// Carga todos los datos del usuario desde Supabase
  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    return await getUserData(userId);
  }
}
