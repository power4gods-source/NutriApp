import 'firebase_sync_service.dart';

/// Servicio para gestionar recetas en Firestore.
/// Misma API que SupabaseRecipeService; usa FirebaseSyncService.
class FirebaseRecipeService {
  final FirebaseSyncService _syncService = FirebaseSyncService();

  Future<bool> savePrivateRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      final allPrivateRecipes = await getAllPrivateRecipes();
      recipe['user_id'] = userId;
      recipe['created_at'] = DateTime.now().toIso8601String();
      recipe['is_public'] = false;
      allPrivateRecipes.add(recipe);
      return await _syncService.uploadJsonFile(
        'recipes_private.json',
        {'recipes': allPrivateRecipes},
      );
    } catch (e) {
      print('Error saving private recipe: $e');
      return false;
    }
  }

  Future<bool> savePublicRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      final publicRecipes = await getPublicRecipes();
      recipe['user_id'] = userId;
      recipe['created_at'] = DateTime.now().toIso8601String();
      recipe['is_public'] = true;
      publicRecipes.add(recipe);
      return await _syncService.uploadJsonFile(
        'recipes_public.json',
        {'recipes': publicRecipes},
      );
    } catch (e) {
      print('Error saving public recipe: $e');
      return false;
    }
  }

  Future<List<dynamic>> getAllPublicRecipes() async => getPublicRecipes();

  Future<List<dynamic>> getAllPrivateRecipes() async {
    try {
      final data = await _syncService.downloadJsonFile('recipes_private.json');
      if (data != null) {
        if (data is Map && data['recipes'] != null) {
          return (data['recipes'] as List).cast<dynamic>();
        }
        if (data is List) return data.cast<dynamic>();
      }
      return [];
    } catch (e) {
      print('Error getting private recipes: $e');
      return [];
    }
  }

  Future<List<dynamic>> getPrivateRecipes(String userId) async {
    final allRecipes = await getAllPrivateRecipes();
    return allRecipes.where((r) => r['user_id'] == userId).toList();
  }

  Future<List<dynamic>> getPublicRecipes() async {
    try {
      final data = await _syncService.downloadJsonFile('recipes_public.json');
      if (data != null) {
        if (data is Map && data['recipes'] != null) {
          return (data['recipes'] as List).cast<dynamic>();
        }
        if (data is List) return data.cast<dynamic>();
      }
      return [];
    } catch (e) {
      print('Error getting public recipes: $e');
      return [];
    }
  }

  Future<bool> publishPrivateRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      final allPrivateRecipes = await getAllPrivateRecipes();
      for (int i = 0; i < allPrivateRecipes.length; i++) {
        if (allPrivateRecipes[i]['title'] == recipe['title'] &&
            allPrivateRecipes[i]['user_id'] == userId &&
            (allPrivateRecipes[i]['is_public'] == false ||
                allPrivateRecipes[i]['is_public'] == null)) {
          allPrivateRecipes[i]['is_public'] = true;
          allPrivateRecipes[i]['made_public_at'] =
              DateTime.now().toIso8601String();
          break;
        }
      }
      await _syncService.uploadJsonFile(
        'recipes_private.json',
        {'recipes': allPrivateRecipes},
      );
      final publicRecipe = Map<String, dynamic>.from(recipe);
      publicRecipe['is_public'] = true;
      publicRecipe['made_public_at'] = DateTime.now().toIso8601String();
      return await savePublicRecipe(publicRecipe, userId);
    } catch (e) {
      print('Error publishing recipe: $e');
      return false;
    }
  }
}
