import 'firebase_sync_service.dart';

/// Servicio para gestionar usuarios y sus datos en Firestore.
/// Misma API que SupabaseUserService; usa FirebaseSyncService para users/{userId}.json.
class FirebaseUserService {
  final FirebaseSyncService _syncService = FirebaseSyncService();

  Future<bool> registerUser({
    required String userId,
    required String email,
    required String passwordHash,
    String? username,
  }) async {
    try {
      final userData = {
        'user_id': userId,
        'email': email.toLowerCase().trim(),
        'password_hash': passwordHash,
        'username': username ?? email.split('@')[0],
        'role': 'user', // Siempre user; admin solo power4gods@gmail.com
        'ingredients': [],
        'favorites': [],
        'goals': {},
        'shopping_list': [],
        'private_recipes': [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final success = await _syncService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
      if (success) print('✅ Usuario registrado en Firestore: $email');
      return success;
    } catch (e) {
      print('❌ Error registrando usuario: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      return await getUserData(userId);
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return null;
    }
  }

  Future<bool> verifyUser(String email, String passwordHash) async {
    try {
      final userId = _generateUserIdFromEmail(email.toLowerCase().trim());
      final userData = await getUserData(userId);
      if (userData == null) return false;
      final storedHash = userData['password_hash'] as String?;
      return storedHash != null && storedHash == passwordHash;
    } catch (e) {
      print('Error verificando usuario: $e');
      return false;
    }
  }

  Future<String?> getUserIdFromEmail(String email) async {
    try {
      final userId = _generateUserIdFromEmail(email.toLowerCase().trim());
      final userData = await getUserData(userId);
      if (userData != null && userData['email'] == email.toLowerCase().trim()) {
        return userId;
      }
      return null;
    } catch (e) {
      print('Error obteniendo userId: $e');
      return null;
    }
  }

  String _generateUserIdFromEmail(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_');
  }

  Future<bool> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      userData['updated_at'] = DateTime.now().toIso8601String();
      return await _syncService.uploadJsonFile(
        'users/$userId.json',
        userData,
      );
    } catch (e) {
      print('❌ Error guardando datos del usuario: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final data = await _syncService.downloadJsonFile('users/$userId.json');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  Future<bool> syncUserIngredients(String userId, List<dynamic> ingredients) async {
    final userData = await getUserData(userId) ?? {'user_id': userId, 'ingredients': []};
    userData['ingredients'] = ingredients;
    return saveUserData(userId, userData);
  }

  Future<bool> syncUserFavorites(String userId, List<String> favoriteIds) async {
    final userData = await getUserData(userId) ?? {'user_id': userId, 'favorites': []};
    userData['favorites'] = favoriteIds;
    return saveUserData(userId, userData);
  }

  Future<bool> syncUserGoals(String userId, Map<String, dynamic> goals) async {
    final userData = await getUserData(userId) ?? {'user_id': userId, 'goals': {}};
    userData['goals'] = goals;
    return saveUserData(userId, userData);
  }

  Future<bool> syncUserShoppingList(String userId, List<dynamic> shoppingList) async {
    final userData = await getUserData(userId) ?? {'user_id': userId, 'shopping_list': []};
    userData['shopping_list'] = shoppingList;
    return saveUserData(userId, userData);
  }

  Future<bool> syncUserPrivateRecipes(String userId, List<dynamic> privateRecipes) async {
    final userData = await getUserData(userId) ?? {'user_id': userId, 'private_recipes': []};
    userData['private_recipes'] = privateRecipes;
    return saveUserData(userId, userData);
  }

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    return getUserData(userId);
  }
}
