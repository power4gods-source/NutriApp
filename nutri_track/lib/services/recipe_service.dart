import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'firebase_sync_service.dart';
import 'firebase_recipe_service.dart';
import 'firebase_user_service.dart';
import '../config/app_config.dart';

class RecipeService {
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  final FirebaseRecipeService _firebaseRecipeService = FirebaseRecipeService();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  
  /// Obtiene la URL del backend configurada
  Future<String> get baseUrl async => await AppConfig.getBackendUrl();

  Future<Map<String, String>> _getHeaders() async {
    final authService = AuthService();
    final headers = await authService.getAuthHeaders();
    return headers;
  }

  // Verifica si el backend está disponible
  Future<bool> _isBackendAvailable() async {
    try {
      final url = await baseUrl;
      print('🔍 Verificando disponibilidad del backend en: $url');
      final response = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));
      final isAvailable = response.statusCode == 200;
      print('🔍 Backend disponible: $isAvailable (status: ${response.statusCode})');
      return isAvailable;
    } catch (e) {
      print('🔍 Backend no disponible: $e');
      return false;
    }
  }

  // Obtiene recetas desde cache local (también busca en cache de Firebase)
  Future<List<dynamic>> _getRecipesFromCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Primero intentar desde cache específico de recetas
      final jsonString = prefs.getString(cacheKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString);
        if (data is List) return data;
        if (data is Map && data['recipes'] != null) {
          return data['recipes'] as List;
        }
      }
      
      // Si no hay cache específico, intentar desde cache de Firebase (si existe)
      final fileName = cacheKey == 'recipes_general' ? 'recipes.json' : 
                       cacheKey == 'recipes_public' ? 'recipes_public.json' :
                       cacheKey == 'recipes_private' ? 'recipes_private.json' : null;
      
      if (fileName != null) {
        final firebaseCache = prefs.getString('cache_$fileName');
        if (firebaseCache != null) {
          final data = jsonDecode(firebaseCache);
          if (data is Map) {
            final dataMap = Map<String, dynamic>.from(data);
            if (dataMap['recipes'] != null && dataMap['recipes'] is List) {
              return (dataMap['recipes'] as List).cast<dynamic>();
            }
          } else if (data is List) {
            return data.cast<dynamic>();
          }
        }
      }
    } catch (e) {
      print('Error reading from cache: $e');
    }
    return [];
  }

  // Guarda recetas en cache local
  Future<void> _saveRecipesToCache(String cacheKey, List<dynamic> recipes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(recipes));
      await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  // Get general recipes con fallback a Firebase y cache
  // PRIORIDAD: Firebase primero (para modo sin backend), luego backend, luego cache
  Future<List<dynamic>> getGeneralRecipes() async {
    // 1. Intentar desde Firebase PRIMERO (para modo sin backend)
    try {
      final data = await _firebaseService.downloadJsonFile('recipes.json');
      if (data != null) {
        List<dynamic> recipes = [];
        if (data is List) {
          recipes = data.cast<dynamic>();
        } else if (data is Map<String, dynamic>) {
          if (data['recipes'] != null && data['recipes'] is List) {
            recipes = (data['recipes'] as List).cast<dynamic>();
          }
        }
        // Guardar en cache
        await _saveRecipesToCache('recipes_general', recipes);
        print('Loaded ${recipes.length} general recipes from Firebase');
        return recipes;
      }
    } catch (e) {
      print('Firebase error, trying backend: $e');
    }

    // 2. Intentar desde backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final response = await http.get(
          Uri.parse('$url/recipes/general'),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          List<dynamic> recipes = [];
          if (data['recipes'] != null) {
            recipes = (data['recipes'] as List).cast<dynamic>();
          }
          // Guardar en cache
          await _saveRecipesToCache('recipes_general', recipes);
          print('Loaded ${recipes.length} general recipes from backend');
          return recipes;
        }
      } catch (e) {
        print('Backend error, trying cache: $e');
      }
    }

    // 3. Intentar desde Firebase (segunda vez, por si falló antes)
    try {
      final data = await _firebaseService.downloadJsonFile('recipes.json');
      if (data != null) {
        List<dynamic> recipes = [];
        if (data is List) {
          recipes = data.cast<dynamic>();
        } else if (data is Map<String, dynamic>) {
          if (data['recipes'] != null && data['recipes'] is List) {
            recipes = (data['recipes'] as List).cast<dynamic>();
          }
        }
        // Guardar en cache
        await _saveRecipesToCache('recipes_general', recipes);
        print('Loaded ${recipes.length} general recipes from Firebase');
        return recipes;
      }
    } catch (e) {
      print('Firebase error, trying cache: $e');
    }

    // 3. Usar cache local
    final cached = await _getRecipesFromCache('recipes_general');
    if (cached.isNotEmpty) {
      print('Loaded ${cached.length} general recipes from cache');
      return cached;
    }

    print('No recipes available from any source');
    return [];
  }

  // Get public recipes - PRIORIDAD: Backend primero (más actualizado), luego Firebase, luego cache
  Future<List<dynamic>> getPublicRecipes() async {
    print('🔍 getPublicRecipes() llamado');
    
    // 1. Intentar desde backend PRIMERO (más actualizado)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        print('📡 Intentando cargar recetas públicas desde backend: $url/recipes/public');
        final response = await http.get(
          Uri.parse('$url/recipes/public'),
        ).timeout(const Duration(seconds: 15));

        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          List<dynamic> recipes = [];
          if (data['recipes'] != null) {
            recipes = (data['recipes'] as List).cast<dynamic>();
          }
          // Guardar en cache
          await _saveRecipesToCache('recipes_public', recipes);
          print('✅ Loaded ${recipes.length} public recipes from backend');
          return recipes;
        } else {
          print('⚠️ Backend returned status ${response.statusCode}');
        }
      } catch (e, stackTrace) {
        print('❌ Backend error: $e');
        print('❌ Stack trace: $stackTrace');
      }
    } else {
      print('⚠️ Backend no disponible');
    }
    
    // 2. Intentar desde Firebase como fallback
    try {
      final data = await _firebaseService.downloadJsonFile('recipes_public.json');
      if (data != null) {
        List<dynamic> recipes = [];
        if (data is Map && data['recipes'] != null) {
          recipes = (data['recipes'] as List).cast<dynamic>();
        } else if (data is List) {
          recipes = data.cast<dynamic>();
        }
        // Guardar en cache
        await _saveRecipesToCache('recipes_public', recipes);
        print('✅ Loaded ${recipes.length} public recipes from Firebase');
        return recipes;
      }
    } catch (e) {
      print('⚠️ Firebase error: $e');
    }
    
    // 3. Usar cache local como último recurso
    final cached = await _getRecipesFromCache('recipes_public');
    if (cached.isNotEmpty) {
      print('✅ Loaded ${cached.length} public recipes from cache');
      return cached;
    }
    
    print('⚠️ No public recipes available from any source');
    return [];
  }

  // Get private recipes - PRIORIDAD: Backend primero (más actualizado), luego Firebase, luego cache
  Future<List<dynamic>> getPrivateRecipes() async {
    print('🔍 getPrivateRecipes() llamado');
    // Necesitamos el userId para filtrar recetas privadas
    final authService = AuthService();
    // Asegurar que los datos de autenticación estén cargados
    await authService.reloadAuthData();
    var userId = authService.userId;
    print('🔍 UserId obtenido (después de recargar): $userId');
    
    // Si aún es null, intentar desde SharedPreferences directamente
    if (userId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');
        print('🔍 UserId desde SharedPreferences: $userId');
      } catch (e) {
        print('❌ Error obteniendo userId desde SharedPreferences: $e');
      }
    }
    
    if (userId == null) {
      print('❌ UserId es null, retornando lista vacía');
      return [];
    }
    
    // 1. Intentar desde backend PRIMERO (más actualizado después de guardar)
    final backendAvailable = await _isBackendAvailable();
    print('🔍 Backend disponible: $backendAvailable');
    if (backendAvailable) {
      try {
        final url = await baseUrl;
        print('🔄 Cargando recetas privadas desde backend...');
        print('🔄 UserId esperado: $userId');
        final headers = await _getHeaders();
        print('🔄 Headers keys: ${headers.keys}');
        print('🔄 Authorization header presente: ${headers.containsKey('Authorization')}');
        final response = await http.get(
          Uri.parse('$url/recipes/private'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body length: ${response.body.length}');
        if (response.body.length < 500) {
          print('📥 Response body: ${response.body}');
        } else {
          print('📥 Response body (first 500 chars): ${response.body.substring(0, 500)}');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          print('📋 Response data keys: ${data.keys}');
          print('📋 Response data: $data');
          List<dynamic> recipes = [];
          if (data['recipes'] != null) {
            recipes = (data['recipes'] as List).cast<dynamic>();
            print('📋 Total recipes in response: ${recipes.length}');
            if (recipes.isNotEmpty) {
              print('📋 First recipe user_id: ${recipes[0]['user_id']}');
              print('📋 First recipe title: ${recipes[0]['title']}');
            }
          } else {
            print('⚠️ No "recipes" key in response data');
          }
          print('📋 Backend returned ${recipes.length} recipes for user $userId');
          // Guardar en cache
          await _saveRecipesToCache('recipes_private', recipes);
          print('✅ Loaded ${recipes.length} private recipes from backend');
          return recipes;
        } else if (response.statusCode == 401) {
          print('❌ Error de autenticación al cargar recetas privadas. Intentando refrescar token...');
          final authService = AuthService();
          final refreshed = await authService.tryRefreshToken();
          if (refreshed) {
            // Intentar de nuevo después de refrescar
            print('🔄 Reintentando cargar recetas privadas después de refrescar token...');
            final retryHeaders = await _getHeaders();
            final retryResponse = await http.get(
              Uri.parse('$url/recipes/private'),
              headers: retryHeaders,
            ).timeout(const Duration(seconds: 15));
            
            if (retryResponse.statusCode == 200) {
              final retryData = jsonDecode(retryResponse.body) as Map<String, dynamic>;
              List<dynamic> retryRecipes = [];
              if (retryData['recipes'] != null) {
                retryRecipes = (retryData['recipes'] as List).cast<dynamic>();
              }
              await _saveRecipesToCache('recipes_private', retryRecipes);
              print('✅ Loaded ${retryRecipes.length} private recipes from backend (after refresh)');
              return retryRecipes;
            }
          }
          print('⚠️ Backend returned status ${response.statusCode} for private recipes: ${response.body}');
        } else {
          print('⚠️ Backend returned status ${response.statusCode} for private recipes: ${response.body}');
        }
      } catch (e) {
        print('⚠️ Backend error loading private recipes, trying Firebase: $e');
      }
    }
    
    // 2. Intentar desde Firebase - cargar desde users/{userId}.json (lista específica del usuario)
    try {
      final userData = await _firebaseUserService.getUserData(userId);
      if (userData != null && userData['private_recipes'] != null) {
        final userRecipes = (userData['private_recipes'] as List).cast<dynamic>();
        // Guardar en cache
        await _saveRecipesToCache('recipes_private', userRecipes);
        print('✅ Loaded ${userRecipes.length} private recipes from Firebase (user-specific)');
        return userRecipes;
      }
      // Fallback: intentar desde recipes_private.json (compatibilidad)
      final data = await _firebaseService.downloadJsonFile('recipes_private.json');
      if (data != null) {
        List<dynamic> allRecipes = [];
        if (data is Map && data['recipes'] != null) {
          allRecipes = (data['recipes'] as List).cast<dynamic>();
        } else if (data is List) {
          allRecipes = data.cast<dynamic>();
        }
        // Filtrar por usuario
        final userRecipes = allRecipes.where((r) => r['user_id'] == userId).toList();
        // Guardar en cache
        await _saveRecipesToCache('recipes_private', userRecipes);
        print('✅ Loaded ${userRecipes.length} private recipes from Firebase (legacy)');
        return userRecipes;
      }
    } catch (e) {
      print('⚠️ Firebase error loading private recipes: $e');
    }
    
    // 3. Usar cache local como último recurso
    final cached = await _getRecipesFromCache('recipes_private');
    if (cached.isNotEmpty) {
      print('✅ Loaded ${cached.length} private recipes from cache');
      return cached;
    }
    
    print('⚠️ No private recipes available from any source');
    return [];
  }

  // Obtener todas las recetas privadas del backend (sin filtrar por usuario)
  // Útil para encontrar el índice correcto de una receta
  Future<List<dynamic>> getAllPrivateRecipesFromBackend() async {
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$url/recipes/private'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['recipes'] != null) {
            return (data['recipes'] as List).cast<dynamic>();
          }
        }
      } catch (e) {
        print('⚠️ Error obteniendo todas las recetas privadas del backend: $e');
      }
    }
    return [];
  }

  // Get all recipes (general + public + private)
  Future<List<dynamic>> getAllRecipes() async {
    // 1. Intentar desde backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final response = await http.get(
          Uri.parse('$url/recipes/all'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          List<dynamic> allRecipes = [];
          if (data['general'] != null && data['general'] is Map) {
            final general = data['general'] as Map<String, dynamic>;
            if (general['recipes'] != null && general['recipes'] is List) {
              allRecipes.addAll((general['recipes'] as List).cast<dynamic>());
            }
          }
          if (data['public'] != null && data['public'] is Map) {
            final public = data['public'] as Map<String, dynamic>;
            if (public['recipes'] != null && public['recipes'] is List) {
              allRecipes.addAll((public['recipes'] as List).cast<dynamic>());
            }
          }
          if (data['private'] != null && data['private'] is Map) {
            final private = data['private'] as Map<String, dynamic>;
            if (private['recipes'] != null && private['recipes'] is List) {
              allRecipes.addAll((private['recipes'] as List).cast<dynamic>());
            }
          }
          return allRecipes;
        }
      } catch (e) {
        print('Error getting all recipes from backend: $e');
      }
    }
    
    // 2. Fallback: Combinar recetas generales y públicas desde Firestore/cache
    try {
      final generalRecipes = await getGeneralRecipes();
      final publicRecipes = await getPublicRecipes();
      final allRecipes = [...generalRecipes, ...publicRecipes];
      print('Loaded ${allRecipes.length} recipes from Firestore/cache fallback');
      return allRecipes;
    } catch (e) {
      print('Error getting recipes from Firestore fallback: $e');
      return [];
    }
  }

  // Get favorites - con fallback a favoritos locales
  Future<List<dynamic>> getFavorites() async {
    // 1. Intentar desde backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final response = await http.get(
          Uri.parse('$url/profile/favorites'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          List<dynamic> favorites = [];
          if (data['favorite_recipes'] != null && data['favorite_recipes'] is List) {
            favorites = (data['favorite_recipes'] as List).cast<dynamic>();
            // Guardar en cache local
            await _saveFavoritesToLocal(favorites);
            return favorites;
          }
        }
      } catch (e) {
        print('Backend error getting favorites, trying local: $e');
      }
    }
    
    // 2. Usar favoritos locales como fallback
    return await _getFavoritesFromLocal();
  }
  
  // Guardar favoritos localmente
  Future<void> _saveFavoritesToLocal(List<dynamic> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final userId = authService.userId;
      if (userId == null) return;
      
      final favoriteIds = favorites.map((f) => f['title'] ?? '').toList();
      await prefs.setString('favorites_$userId', jsonEncode(favoriteIds));
    } catch (e) {
      print('Error saving favorites to local: $e');
    }
  }
  
  // Obtener favoritos locales
  Future<List<dynamic>> _getFavoritesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final userId = authService.userId;
      if (userId == null) return [];
      
      final favoriteIdsJson = prefs.getString('favorites_$userId');
      if (favoriteIdsJson == null) return [];
      
      final favoriteIds = (jsonDecode(favoriteIdsJson) as List).cast<String>();
      
      // Obtener todas las recetas y filtrar por IDs
      final allRecipes = await getGeneralRecipes();
      final publicRecipes = await getPublicRecipes();
      final privateRecipes = await getPrivateRecipes();
      
      final allRecipesList = [...allRecipes, ...publicRecipes, ...privateRecipes];
      
      return allRecipesList.where((recipe) {
        final recipeId = recipe['title'] ?? '';
        return favoriteIds.contains(recipeId);
      }).toList();
    } catch (e) {
      print('Error getting favorites from local: $e');
      return [];
    }
  }

  // Add to favorites - con fallback a favoritos locales
  Future<bool> addToFavorites(String recipeId) async {
    // 1. Intentar con backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final response = await http.post(
          Uri.parse('$url/profile/favorites/$recipeId'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          // Recargar favoritos y guardar localmente
          await getFavorites();
          return true;
        }
      } catch (e) {
        print('Backend error adding favorite, using local: $e');
      }
    }
    
    // 2. Guardar localmente como fallback
    return await _addFavoriteToLocal(recipeId);
  }
  
  // Añadir favorito localmente
  Future<bool> _addFavoriteToLocal(String recipeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final userId = authService.userId;
      if (userId == null) return false;
      
      final favoriteIdsJson = prefs.getString('favorites_$userId');
      List<String> favoriteIds = [];
      if (favoriteIdsJson != null) {
        favoriteIds = (jsonDecode(favoriteIdsJson) as List).cast<String>();
      }
      
      if (!favoriteIds.contains(recipeId)) {
        favoriteIds.add(recipeId);
        await prefs.setString('favorites_$userId', jsonEncode(favoriteIds));
        
        // Sincronizar con Firebase
        await _firebaseUserService.syncUserFavorites(userId, favoriteIds);
      }
      return true;
    } catch (e) {
      print('Error adding favorite to local: $e');
      return false;
    }
  }

  // Remove from favorites - con fallback a favoritos locales
  Future<bool> removeFromFavorites(String recipeId) async {
    // 1. Intentar con backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final url = await baseUrl;
        final response = await http.delete(
          Uri.parse('$url/profile/favorites/$recipeId'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          // Recargar favoritos y guardar localmente
          await getFavorites();
          return true;
        }
      } catch (e) {
        print('Backend error removing favorite, using local: $e');
      }
    }
    
    // 2. Eliminar localmente como fallback
    return await _removeFavoriteFromLocal(recipeId);
  }
  
  // Eliminar favorito localmente
  Future<bool> _removeFavoriteFromLocal(String recipeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final userId = authService.userId;
      if (userId == null) return false;
      
      final favoriteIdsJson = prefs.getString('favorites_$userId');
      if (favoriteIdsJson == null) return true;
      
      List<String> favoriteIds = (jsonDecode(favoriteIdsJson) as List).cast<String>();
      final removed = favoriteIds.remove(recipeId);
      if (removed) {
        await prefs.setString('favorites_$userId', jsonEncode(favoriteIds));
        
        // Sincronizar con Firebase
        await _firebaseUserService.syncUserFavorites(userId, favoriteIds);
        print('✅ Favorito eliminado localmente: $recipeId');
      } else {
        print('⚠️ Favorito no encontrado en lista local: $recipeId');
      }
      
      return true;
    } catch (e) {
      print('Error removing favorite from local: $e');
      return false;
    }
  }

  // Publish a private recipe (make it public)
  Future<bool> publishRecipe(String recipeId) async {
    try {
      final url = await baseUrl;
      final headers = await _getHeaders();
      print('📤 Publicando receta privada con ID: $recipeId');
      print('📤 Headers: ${headers.keys}');
      print('📤 Authorization presente: ${headers.containsKey('Authorization')}');
      
      final response = await http.post(
        Uri.parse('$url/recipes/private/$recipeId/make-public'),
        headers: headers,
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403) {
        print('❌ Error 403: No tienes permisos para publicar esta receta');
        print('📋 Response body: ${response.body}');
      } else if (response.statusCode == 401) {
        print('❌ Error 401: Token inválido o expirado');
        // Intentar refrescar el token
        final authService = AuthService();
        final refreshed = await authService.tryRefreshToken();
        if (refreshed) {
          print('🔄 Token refrescado, reintentando...');
          final retryHeaders = await _getHeaders();
          final retryResponse = await http.post(
            Uri.parse('$url/recipes/private/$recipeId/make-public'),
            headers: retryHeaders,
          );
          if (retryResponse.statusCode == 200) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error publishing recipe: $e');
      return false;
    }
  }

  // Unpublish a public recipe (remove from public, keep in private)
  Future<bool> unpublishRecipe(String recipeId) async {
    try {
      final url = await baseUrl;
      final headers = await _getHeaders();
      print('📤 Despublicando receta con ID: $recipeId');
      
      final response = await http.post(
        Uri.parse('$url/recipes/public/$recipeId/make-private'),
        headers: headers,
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403) {
        print('❌ Error 403: No tienes permisos para despublicar esta receta');
      } else if (response.statusCode == 401) {
        print('❌ Error 401: Token inválido o expirado');
        final authService = AuthService();
        final refreshed = await authService.tryRefreshToken();
        if (refreshed) {
          print('🔄 Token refrescado, reintentando...');
          final retryHeaders = await _getHeaders();
          final retryResponse = await http.post(
            Uri.parse('$url/recipes/public/$recipeId/make-private'),
            headers: retryHeaders,
          );
          if (retryResponse.statusCode == 200) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error unpublishing recipe: $e');
      return false;
    }
  }

  // Delete a general recipe (only admin)
  Future<bool> deleteGeneralRecipe(String recipeId) async {
    try {
      final url = await baseUrl;
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$url/recipes/general/$recipeId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting general recipe: $e');
      return false;
    }
  }

  // Delete a public recipe (only admin or owner)
  Future<bool> deletePublicRecipe(String recipeId) async {
    try {
      final url = await baseUrl;
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$url/recipes/public/$recipeId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting public recipe: $e');
      return false;
    }
  }

  // Delete a private recipe (only owner)
  Future<bool> deletePrivateRecipe(String recipeId) async {
    try {
      final url = await baseUrl;
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$url/recipes/private/$recipeId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting private recipe: $e');
      return false;
    }
  }

  // Search recipes
  Future<Map<String, dynamic>> searchRecipes({
    String? query,
    List<String>? ingredients,
    int? timeMinutes,
    String? difficulty,
    List<String>? tags,
    int? maxCalories,
    bool includeGeneral = false,
    bool includePublic = true,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (query != null && query.isNotEmpty) body['query'] = query;
      if (ingredients != null && ingredients.isNotEmpty) body['ingredients'] = ingredients;
      if (timeMinutes != null) body['time_minutes'] = timeMinutes;
      if (difficulty != null) body['difficulty'] = difficulty;
      if (tags != null && tags.isNotEmpty) body['tags'] = tags;
      if (maxCalories != null) body['max_calories'] = maxCalories;

      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/search?include_general=$includeGeneral&include_public=$includePublic'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'exact_matches': [], 'suggestions': []};
      }
    } catch (e) {
      print('Error searching recipes: $e');
      return {'exact_matches': [], 'suggestions': []};
    }
  }
}


