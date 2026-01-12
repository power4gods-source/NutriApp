import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_sync_service.dart';

/// Servicio para gestionar usuarios y sus datos en Firebase
/// Almacena usuarios en Firestore y datos del usuario en Firebase Storage
class FirebaseUserService {
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  
  FirebaseFirestore get firestore => _firebaseService.firestore;
  FirebaseStorage get storage => _firebaseService.storage;
  
  /// Registra un nuevo usuario en Firebase
  Future<bool> registerUser({
    required String userId,
    required String email,
    required String passwordHash,
    String? username,
  }) async {
    try {
      print('📝 Iniciando registro de usuario en Firebase: $email');
      
      // Usar solo Storage en lugar de Firestore para evitar problemas de permisos
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
      
      print('📤 Subiendo datos del usuario a Firebase Storage...');
      
      // Guardar en Storage (más permisivo que Firestore)
      final uploadSuccess = await _firebaseService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
      
      if (uploadSuccess) {
        print('✅ Usuario registrado en Firebase Storage: $email');
        return true;
      } else {
        print('⚠️ Fallo al subir a Storage, intentando guardar localmente...');
        // Si falla Storage, al menos guardar localmente
        return false; // Se manejará en auth_service con fallback local
      }
    } catch (e, stackTrace) {
      print('❌ Error registrando usuario en Firebase: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Obtiene un usuario desde Firebase Storage
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      // Obtener desde Storage en lugar de Firestore
      final userData = await getUserData(userId);
      return userData;
    } catch (e) {
      print('Error obteniendo usuario desde Firebase: $e');
      return null;
    }
  }
  
  /// Verifica credenciales de usuario en Firebase Storage
  Future<bool> verifyUser(String email, String passwordHash) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final userId = _generateUserIdFromEmail(normalizedEmail);
      final userData = await getUserData(userId);
      
      if (userData == null) return false;
      
      return userData['password_hash'] == passwordHash;
    } catch (e) {
      print('Error verificando usuario en Firebase: $e');
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
  
  /// Guarda datos del usuario en Firebase Storage
  Future<bool> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      userData['updated_at'] = DateTime.now().toIso8601String();
      print('💾 Guardando datos del usuario $userId en Firebase Storage...');
      final success = await _firebaseService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
      if (success) {
        print('✅ Datos del usuario $userId guardados correctamente en Firebase');
      } else {
        print('❌ Error al guardar datos del usuario $userId en Firebase');
      }
      return success;
    } catch (e) {
      print('❌ Error guardando datos del usuario: $e');
      return false;
    }
  }
  
  /// Obtiene datos del usuario desde Firebase Storage
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final data = await _firebaseService.downloadJsonFile('users/$userId.json');
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
  
  /// Carga todos los datos del usuario desde Firebase
  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    return await getUserData(userId);
  }
}

