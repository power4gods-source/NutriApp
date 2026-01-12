import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_sync_service.dart';
import 'firebase_user_service.dart';

/// Servicio para gestionar recetas directamente en Firebase
/// Permite guardar, actualizar y obtener recetas sin necesidad del backend local
class FirebaseRecipeService {
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  
  /// Guarda una receta privada directamente en Firebase
  Future<bool> savePrivateRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      // Obtener TODAS las recetas privadas (no solo del usuario)
      final allPrivateRecipes = await getAllPrivateRecipes();
      
      // Agregar metadata
      recipe['user_id'] = userId;
      recipe['created_at'] = DateTime.now().toIso8601String();
      recipe['is_public'] = false;
      
      // Agregar a la lista
      allPrivateRecipes.add(recipe);
      
      // Guardar en Firebase Storage
      final success = await _firebaseService.uploadJsonFile(
        'recipes_private.json',
        {'recipes': allPrivateRecipes},
      );
      
      return success;
    } catch (e) {
      print('Error saving private recipe to Firebase: $e');
      return false;
    }
  }
  
  /// Guarda una receta pública directamente en Firebase
  Future<bool> savePublicRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      // Obtener recetas públicas actuales
      final publicRecipes = await getPublicRecipes();
      
      // Agregar metadata
      recipe['user_id'] = userId;
      recipe['created_at'] = DateTime.now().toIso8601String();
      recipe['is_public'] = true;
      
      // Agregar a la lista
      publicRecipes.add(recipe);
      
      // Guardar en Firebase Storage
      final success = await _firebaseService.uploadJsonFile(
        'recipes_public.json',
        {'recipes': publicRecipes},
      );
      
      return success;
    } catch (e) {
      print('Error saving public recipe to Firebase: $e');
      return false;
    }
  }
  
  /// Obtiene todas las recetas públicas desde Firebase (para luego filtrar)
  Future<List<dynamic>> getAllPublicRecipes() async {
    return await getPublicRecipes();
  }
  
  /// Obtiene todas las recetas privadas desde Firebase (para luego filtrar)
  Future<List<dynamic>> getAllPrivateRecipes() async {
    try {
      final data = await _firebaseService.downloadJsonFile('recipes_private.json');
      if (data != null) {
        if (data is Map && data['recipes'] != null) {
          return (data['recipes'] as List).cast<dynamic>();
        } else if (data is List) {
          return data.cast<dynamic>();
        }
      }
      return [];
    } catch (e) {
      print('Error getting private recipes from Firebase: $e');
      return [];
    }
  }
  
  /// Obtiene recetas privadas de un usuario desde Firebase
  Future<List<dynamic>> getPrivateRecipes(String userId) async {
    final allRecipes = await getAllPrivateRecipes();
    return allRecipes.where((r) => r['user_id'] == userId).toList();
  }
  
  /// Obtiene todas las recetas públicas desde Firebase
  Future<List<dynamic>> getPublicRecipes() async {
    try {
      final data = await _firebaseService.downloadJsonFile('recipes_public.json');
      if (data != null) {
        if (data is Map && data['recipes'] != null) {
          return (data['recipes'] as List).cast<dynamic>();
        } else if (data is List) {
          return data.cast<dynamic>();
        }
      }
      return [];
    } catch (e) {
      print('Error getting public recipes from Firebase: $e');
      return [];
    }
  }
  
  /// Publica una receta privada (la mantiene en privadas y también la agrega a públicas)
  Future<bool> publishPrivateRecipe(Map<String, dynamic> recipe, String userId) async {
    try {
      // Obtener TODAS las recetas privadas
      final allPrivateRecipes = await getAllPrivateRecipes();
      
      // Marcar la receta como pública en privadas (mantenerla en privadas también)
      for (int i = 0; i < allPrivateRecipes.length; i++) {
        if (allPrivateRecipes[i]['title'] == recipe['title'] && 
            allPrivateRecipes[i]['user_id'] == userId &&
            (allPrivateRecipes[i]['is_public'] == false || allPrivateRecipes[i]['is_public'] == null)) {
          allPrivateRecipes[i]['is_public'] = true;
          allPrivateRecipes[i]['made_public_at'] = DateTime.now().toIso8601String();
          break;
        }
      }
      
      // Guardar privadas actualizadas
      await _firebaseService.uploadJsonFile(
        'recipes_private.json',
        {'recipes': allPrivateRecipes},
      );
      
      // Crear una copia para agregar a públicas (sin modificar la original)
      final publicRecipe = Map<String, dynamic>.from(recipe);
      publicRecipe['is_public'] = true;
      publicRecipe['made_public_at'] = DateTime.now().toIso8601String();
      
      // Agregar también a públicas
      return await savePublicRecipe(publicRecipe, userId);
    } catch (e) {
      print('Error publishing recipe: $e');
      return false;
    }
  }
}

