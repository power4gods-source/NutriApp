import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../config/app_config.dart';
import 'firebase_sync_service.dart';
import 'firebase_user_service.dart';

class TrackingService {
  final AuthService _authService = AuthService();
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  
  Future<String> get baseUrl async {
    final config = await AppConfig.getBackendUrl();
    return config;
  }

  // Verificar si el backend está disponible
  Future<bool> _isBackendAvailable() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Food endpoints - con fallback a Firebase y cache local
  Future<List<dynamic>> searchFoods(String query) async {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase().trim();
    
    // 1. Intentar desde backend (si está disponible)
    if (await _isBackendAvailable()) {
      try {
        final headers = await _authService.getAuthHeaders();
        final url = await baseUrl;
        final response = await http.get(
          Uri.parse('$url/foods?search=${Uri.encodeComponent(query)}'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final foods = data['foods'] ?? [];
          // Guardar en cache
          await _saveFoodsToCache(foods);
          return foods;
        }
      } catch (e) {
        print('Error searching foods from backend: $e');
      }
    }
    
    // 2. Intentar desde Supabase
    try {
      final data = await _firebaseService.downloadJsonFile('foods.json');
      if (data != null) {
        List<dynamic> allFoods = [];
        if (data is List) {
          allFoods = data.cast<dynamic>();
        } else if (data is Map<String, dynamic>) {
          if (data['foods'] != null && data['foods'] is List) {
            allFoods = (data['foods'] as List).cast<dynamic>();
          } else {
            // Si es un Map con claves de alimentos
            allFoods = data.values.whereType<Map<String, dynamic>>().toList();
          }
        }
        
        // Filtrar alimentos que coincidan con la búsqueda
        final filtered = allFoods.where((food) {
          final name = (food['name'] ?? '').toString().toLowerCase();
          final foodId = (food['food_id'] ?? '').toString().toLowerCase();
          // También buscar en name_variations si existe
          final variations = food['name_variations'];
          bool matchesVariations = false;
          if (variations != null && variations is List) {
            matchesVariations = variations.any((v) => 
              v.toString().toLowerCase().contains(lowerQuery)
            );
          }
          return name.contains(lowerQuery) || 
                 name == lowerQuery ||
                 foodId.contains(lowerQuery) ||
                 matchesVariations;
        }).toList();
        
        // Ordenar: coincidencias exactas primero
        filtered.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          if (nameA == lowerQuery && nameB != lowerQuery) return -1;
          if (nameA != lowerQuery && nameB == lowerQuery) return 1;
          return 0;
        });
        
        final result = filtered.take(20).toList();
        
        // Guardar en cache
        await _saveFoodsToCache(result);
        print('✅ Búsqueda completada: ${result.length} alimentos encontrados para "$query"');
        return result;
      }
    } catch (e) {
      print('Error searching foods from Firebase: $e');
    }
    
    // 3. Intentar desde cache local
    final cached = await _getFoodsFromCache();
    if (cached.isNotEmpty) {
      final filtered = cached.where((food) {
        final name = (food['name'] ?? '').toString().toLowerCase();
        final foodId = (food['food_id'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery) || foodId.contains(lowerQuery);
      }).take(20).toList();
      return filtered;
    }
    
    return [];
  }
  
  // Guardar alimentos en cache local
  Future<void> _saveFoodsToCache(List<dynamic> foods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(foods);
      await prefs.setString('cache_foods', jsonString);
    } catch (e) {
      print('Error saving foods to cache: $e');
    }
  }
  
  // Obtener alimentos desde cache local
  Future<List<dynamic>> _getFoodsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cache_foods');
      if (jsonString != null) {
        final data = jsonDecode(jsonString);
        if (data is List) {
          return data.cast<dynamic>();
        }
      }
    } catch (e) {
      print('Error getting foods from cache: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getFood(String foodId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/foods/$foodId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting food: $e');
      return null;
    }
  }

  // Ingredient mapping endpoints
  Future<Map<String, dynamic>> getIngredientMapping(String ingredientName) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/mapping/ingredient/${Uri.encodeComponent(ingredientName)}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'ingredient_name': ingredientName,
        'mapping': null,
        'food': null,
        'auto_matched': false,
        'suggestions': [],
      };
    } catch (e) {
      print('Error getting ingredient mapping: $e');
      return {
        'ingredient_name': ingredientName,
        'mapping': null,
        'food': null,
        'auto_matched': false,
        'suggestions': [],
      };
    }
  }

  Future<bool> createIngredientMapping(
    String ingredientName,
    String foodId, {
    double? defaultQuantity,
    String? defaultUnit,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final queryParams = {
        'ingredient_name': ingredientName,
        'food_id': foodId,
        if (defaultQuantity != null) 'default_quantity': defaultQuantity.toString(),
        if (defaultUnit != null) 'default_unit': defaultUnit,
      };
      final url = await baseUrl;
      final uri = Uri.parse('$url/mapping/ingredient-to-food').replace(
        queryParameters: queryParams,
      );
      final response = await http.post(uri, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating ingredient mapping: $e');
      return false;
    }
  }

  // Consumption endpoints
  Future<bool> addConsumption(
    String date,
    String mealType,
    List<Map<String, dynamic>> foods,
  ) async {
    try {
      // Validar y limpiar los datos antes de enviar
      print('📋 Validando ${foods.length} alimentos/recetas antes de enviar...');
      final validFoods = foods.where((food) {
        // Si es una receta, solo necesita tener calorías
        if (food['is_recipe'] == true) {
          final calories = food['calories'] ?? 0.0;
          return calories > 0;
        }
        // Si es un alimento normal, necesita food_id
        final foodId = food['food_id'] ?? food['id'] ?? '';
        final foodIdStr = foodId.toString();
        final isValid = foodIdStr.isNotEmpty;
        if (!isValid) {
          print('⚠️ Alimento sin ID válido: ${food['name']}');
        }
        return isValid;
      }).map((food) {
        // Si es una receta, crear un "alimento" especial con las calorías y nutrientes
        if (food['is_recipe'] == true) {
          final recipeData = food['recipe_data'] ?? {};
          final caloriesPerServing = food['calories'] ?? 0.0;
          final recipeTitle = recipeData['title'] ?? food['name'] ?? 'Receta';
          
          // Incluir toda la información de la receta para que el backend pueda parsear nutrientes
          print('✅ Receta válida: $recipeTitle (${caloriesPerServing} kcal/ración)');
          return {
            'food_id': 'recipe_${recipeTitle.replaceAll(' ', '_')}',
            'quantity': food['quantity'] ?? 1.0,
            'unit': 'ración',
            'name': recipeTitle,
            'calories': caloriesPerServing,
            'recipe_data': recipeData, // Incluir recipe_data para que el backend parse los nutrientes
          };
        }
        
        // Alimento normal
        final foodId = (food['food_id'] ?? food['id'] ?? '').toString();
        final quantity = (food['quantity'] ?? 0.0).toDouble();
        final unit = (food['unit'] ?? 'gramos').toString();
        print('✅ Alimento válido: ${food['name']} (ID: $foodId, cantidad: $quantity $unit)');
        return {
          'food_id': foodId,
          'quantity': quantity,
          'unit': unit,
        };
      }).toList();
      
      if (validFoods.isEmpty) {
        print('❌ No hay alimentos válidos para agregar');
        final foodsList = foods.map((f) {
          final foodId = f['food_id'] ?? f['id'] ?? '';
          return '${f['name']}: food_id=$foodId';
        }).toList();
        print('⚠️ Alimentos recibidos: ${foodsList.join(', ')}');
        return false;
      }
      
      print('✅ ${validFoods.length} alimentos válidos listos para enviar');
      
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      
      // Verificar que hay token de autenticación
      if (!headers.containsKey('Authorization') || headers['Authorization'] == null) {
        print('❌ No hay token de autenticación disponible');
        return false;
      }
      
      // El backend espera date y meal_type como query params, y solo la lista de foods en el body
      final uri = Uri.parse('$url/tracking/consumption').replace(
        queryParameters: {
          'date': date,
          'meal_type': mealType,
        },
      );
      
      print('📤 Enviando consumo a: $uri');
      print('📤 Query params: date=$date, meal_type=$mealType');
      print('📤 Alimentos a enviar (${validFoods.length}):');
      for (var food in validFoods) {
        print('   - ${food['food_id']}: ${food['quantity']} ${food['unit']}');
      }
      print('📤 Body (lista de alimentos): ${jsonEncode(validFoods)}');
      print('📤 Headers: ${headers.keys.join(', ')}');
      
      final response = await http.post(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(validFoods), // Solo la lista de alimentos
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout al enviar consumo');
        },
      );
      
      print('📥 Respuesta del servidor: ${response.statusCode}');
      print('📥 Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Consumo agregado correctamente');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('❌ Error de autenticación: ${response.statusCode} - ${response.body}');
        print('❌ Token disponible: ${headers.containsKey('Authorization')}');
        print('🔄 Intentando refrescar el token...');
        
        // Intentar refrescar el token automáticamente
        final refreshed = await _authService.tryRefreshToken();
        
        if (!refreshed) {
          print('❌ No se pudo refrescar el token automáticamente');
          print('ℹ️ El token ha expirado. Por favor, cierra sesión y vuelve a iniciar sesión');
          
          // Limpiar el token inválido
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await _authService.logout();
        } else {
          print('✅ Token refrescado correctamente');
          // Reintentar la petición con el nuevo token
          // Por ahora, retornamos false para que el usuario sepa que debe hacer login
          // En el futuro, se podría reintentar automáticamente
        }
        
        return false;
      } else if (response.statusCode == 422) {
        print('❌ Error de validación (422): ${response.body}');
        // Intentar parsear el error para dar más información
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Detalles del error: $errorData');
        } catch (e) {
          print('❌ No se pudo parsear el error');
        }
        return false;
      } else {
        print('❌ Error del servidor: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error adding consumption: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<List<dynamic>> getConsumption({
    String? date,
    String? start,
    String? end,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (start != null) queryParams['start'] = start;
      if (end != null) queryParams['end'] = end;
      
      final url = await baseUrl;
      final uri = Uri.parse('$url/tracking/consumption').replace(
        queryParameters: queryParams,
      );
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entries = data['entries'] ?? [];
        print('📥 Consumo obtenido: ${entries.length} entradas');
        return entries;
      }
      print('⚠️ Error obteniendo consumo: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('Error getting consumption: $e');
      return [];
    }
  }

  // Meal plan endpoints
  Future<bool> createMealPlan(
    String date,
    String mealType,
    List<Map<String, dynamic>> ingredients,
  ) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/tracking/meal-plan'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': date,
          'meal_type': mealType,
          'ingredients': ingredients,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating meal plan: $e');
      return false;
    }
  }

  // Statistics endpoints
  Future<Map<String, dynamic>> getDailyStats(String date) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/tracking/stats/daily?date=$date'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error getting daily stats: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getWeeklyStats(String week) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/tracking/stats/weekly?week=$week'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error getting weekly stats: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getMonthlyStats(String month) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/tracking/stats/monthly?month=$month'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error getting monthly stats: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getYearlyStats(String year) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/tracking/stats/yearly?year=$year'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error getting yearly stats: $e');
      return {};
    }
  }

  // Goals endpoints
  Future<Map<String, dynamic>> getGoals() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/tracking/goals'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'daily_goals': {
          'calories': 2000.0,
          'protein': 150.0,
          'carbohydrates': 250.0,
          'fat': 65.0,
        }
      };
    } catch (e) {
      print('Error getting goals: $e');
      return {
        'daily_goals': {
          'calories': 2000.0,
          'protein': 150.0,
          'carbohydrates': 250.0,
          'fat': 65.0,
        }
      };
    }
  }

  Future<bool> updateGoals(Map<String, dynamic> dailyGoals) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/tracking/goals'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'daily_goals': dailyGoals}),
      );
      
      final success = response.statusCode == 200;
      
      // Sincronizar con Firebase
      if (success) {
        final userId = _authService.userId;
        if (userId != null) {
          await _firebaseUserService.syncUserGoals(userId, dailyGoals);
        }
      }
      
      return success;
    } catch (e) {
      print('Error updating goals: $e');
      
      // Fallback: guardar en Firestore si el backend falla
      try {
        final userId = _authService.userId;
        if (userId != null) {
          final success = await _firebaseUserService.syncUserGoals(userId, dailyGoals);
          if (success) {
            // Guardar también localmente
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('goals_$userId', jsonEncode(dailyGoals));
            return true;
          }
        }
      } catch (firebaseError) {
        print('Error sincronizando objetivos con Firebase: $firebaseError');
      }
      
      return false;
    }
  }
}




