import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/recipe_service.dart';
import '../services/firebase_recipe_service.dart';
import '../services/firebase_user_service.dart';
import '../services/tracking_service.dart';
import '../config/app_config.dart';
import '../utils/plural_helper.dart';

class AddRecipeScreen extends StatefulWidget {
  final Map<String, dynamic>? recipeToEdit; // Receta a editar (null si es nueva)
  final String? recipeType; // 'general', 'public', 'private'
  final int? recipeIndex; // Índice de la receta en la lista (para actualización)
  final bool forceCreate; // Si true, pre-rellena pero guarda como nueva
  
  const AddRecipeScreen({
    super.key,
    this.recipeToEdit,
    this.recipeType,
    this.recipeIndex,
    this.forceCreate = false,
  });

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final RecipeService _recipeService = RecipeService();
  final FirebaseRecipeService _firebaseRecipeService = FirebaseRecipeService();
  final TrackingService _trackingService = TrackingService();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController(text: '4');
  
  String _difficulty = 'Fácil';
  List<Map<String, dynamic>> _ingredients = [];
  Map<String, dynamic>? _calculatedNutrition;
  bool _isCalculating = false;
  bool _isSaving = false;
  
  final TextEditingController _ingredientNameController = TextEditingController();
  final TextEditingController _ingredientQuantityController = TextEditingController();
  String _ingredientUnit = 'gramos';
  
  bool get _isEditing => widget.recipeToEdit != null && !widget.forceCreate;

  @override
  void initState() {
    super.initState();
    _loadRecipeData();
  }
  
  void _loadRecipeData() {
    if (widget.recipeToEdit != null) {
      final recipe = widget.recipeToEdit!;
      _titleController.text = recipe['title'] ?? '';
      _timeController.text = (recipe['time_minutes'] ?? 30).toString();
      _difficulty = recipe['difficulty'] ?? 'Fácil';
      _servingsController.text = (recipe['servings'] ?? 4).toString();
      
      // Parsear descripción e instrucciones
      // Primero verificar si hay instrucciones en formato array (recetas generales)
      if (recipe['instructions'] != null && recipe['instructions'] is List) {
        // Formato de array: cada elemento es un paso
        final instructionsList = recipe['instructions'] as List;
        _instructionsController.text = instructionsList.map((step) => step.toString()).join('\n');
        // La descripción está separada
        _descriptionController.text = recipe['description'] ?? '';
      } else {
        // Formato de string combinado: "descripción\n\nInstrucciones:\ninstrucciones"
        final description = recipe['description'] ?? '';
        if (description.contains('Instrucciones:')) {
          final parts = description.split('Instrucciones:');
          _descriptionController.text = parts[0].trim();
          if (parts.length > 1) {
            _instructionsController.text = parts[1].trim();
          }
        } else {
          _descriptionController.text = description;
        }
      }
      
      // Parsear ingredientes
      // Primero intentar usar ingredients_detailed (formato de recetas generales)
      if (recipe['ingredients_detailed'] != null && recipe['ingredients_detailed'] is List) {
        final ingredientsDetailed = recipe['ingredients_detailed'] as List;
        _ingredients = ingredientsDetailed.map((ing) {
          if (ing is Map) {
            return {
              'name': ing['name'] ?? '',
              'quantity': (ing['quantity'] ?? 0).toDouble(),
              'unit': ing['unit'] ?? 'gramos',
            };
          }
          return null;
        }).where((ing) => ing != null).cast<Map<String, dynamic>>().toList();
      } else {
        // Si no hay ingredients_detailed, parsear desde el string (formato: "nombre: cantidad unidad, ...")
        final ingredientsStr = recipe['ingredients'] ?? '';
        if (ingredientsStr.isNotEmpty) {
          final ingredientList = ingredientsStr.split(',');
          _ingredients = ingredientList.map((ing) {
            final trimmed = ing.trim();
            // Intentar parsear formato "nombre: cantidad unidad"
            if (trimmed.contains(':')) {
              final parts = trimmed.split(':');
              if (parts.length >= 2) {
                final name = parts[0].trim();
                final quantityUnit = parts[1].trim().split(' ');
                if (quantityUnit.length >= 2) {
                  final quantity = double.tryParse(quantityUnit[0]) ?? 0;
                  final unit = quantityUnit[1];
                  return {
                    'name': name,
                    'quantity': quantity,
                    'unit': unit,
                  };
                }
              }
            } else {
              // Si no tiene formato "nombre: cantidad", usar solo el nombre con cantidad por defecto
              return {
                'name': trimmed,
                'quantity': 100.0,
                'unit': 'gramos',
              };
            }
            return null;
          }).where((ing) => ing != null).cast<Map<String, dynamic>>().toList();
        }
      }
      
      // Parsear nutrición si existe
      final nutrientsStr = recipe['nutrients'] ?? '';
      if (nutrientsStr.isNotEmpty) {
        try {
          final nutrients = nutrientsStr.split(',');
          _calculatedNutrition = {};
          for (var nutrient in nutrients) {
            final parts = nutrient.trim().split(' ');
            if (parts.length >= 2) {
              final key = parts[0];
              final value = double.tryParse(parts[1]) ?? 0;
              _calculatedNutrition![key] = value;
            }
          }
        } catch (e) {
          print('Error parsing nutrients: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _servingsController.dispose();
    _ingredientNameController.dispose();
    _ingredientQuantityController.dispose();
    super.dispose();
  }

  Future<void> _calculateNutrition() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega ingredientes primero')),
      );
      return;
    }

    setState(() => _isCalculating = true);

    try {
      // Obtener información nutricional de cada ingrediente
      double totalCalories = 0.0;
      double totalProtein = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;
      double totalFiber = 0.0;
      double totalSugar = 0.0;
      double totalSodium = 0.0;

      // Primero validar que todos los ingredientes existan
      List<String> missingIngredients = [];
      Map<String, Map<String, dynamic>> ingredientFoods = {};
      
      for (var ingredient in _ingredients) {
        final ingredientName = ingredient['name'] as String;
        bool found = false;
        
        // Buscar el alimento en la base de datos
        List<dynamic> foods = await _trackingService.searchFoods(ingredientName);
        
        // Si no encuentra, intentar con singular/plural
        if (foods.isEmpty) {
          if (ingredientName.endsWith('s') && ingredientName.length > 1) {
            final singularName = ingredientName.substring(0, ingredientName.length - 1);
            foods = await _trackingService.searchFoods(singularName);
          }
          if (foods.isEmpty && !ingredientName.endsWith('s')) {
            foods = await _trackingService.searchFoods('${ingredientName}s');
          }
        }
        
        if (foods.isNotEmpty) {
          final food = foods.first;
          if (food['nutrition_per_100g'] != null && food['nutrition_per_100g'] is Map) {
            ingredientFoods[ingredientName] = Map<String, dynamic>.from(food);
            found = true;
          }
        }
        
        if (!found) {
          missingIngredients.add(ingredientName);
        }
      }
      
      // Si hay ingredientes faltantes, mostrar error
      if (missingIngredients.isNotEmpty) {
        setState(() => _isCalculating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Los siguientes ingredientes no se encontraron en la base de datos:\n${missingIngredients.join(', ')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Calcular nutrición para todos los ingredientes válidos
      for (var ingredient in _ingredients) {
        final ingredientName = ingredient['name'] as String;
        final quantity = (ingredient['quantity'] as num).toDouble();
        final unit = ingredient['unit'] as String;
        final food = ingredientFoods[ingredientName]!;
        
        final nutritionPer100g = food['nutrition_per_100g'] as Map<String, dynamic>;
        final unitConversions = food['unit_conversions'] as Map<String, dynamic>? ?? {};

        // Convertir a gramos
        double grams = quantity;
        if (unitConversions.containsKey(unit)) {
          grams = quantity * (unitConversions[unit] as num).toDouble();
        } else if (unit == 'unidades') {
          grams = quantity * 100.0;
        }

        // Calcular nutrición
        final multiplier = grams / 100.0;
        totalCalories += ((nutritionPer100g['calories'] ?? 0) as num).toDouble() * multiplier;
        totalProtein += ((nutritionPer100g['protein'] ?? 0) as num).toDouble() * multiplier;
        totalCarbs += ((nutritionPer100g['carbohydrates'] ?? 0) as num).toDouble() * multiplier;
        totalFat += ((nutritionPer100g['fat'] ?? 0) as num).toDouble() * multiplier;
        totalFiber += ((nutritionPer100g['fiber'] ?? 0) as num).toDouble() * multiplier;
        totalSugar += ((nutritionPer100g['sugar'] ?? 0) as num).toDouble() * multiplier;
        totalSodium += ((nutritionPer100g['sodium'] ?? 0) as num).toDouble() * multiplier;
      }

      // Dividir por número de porciones
      final servings = double.tryParse(_servingsController.text) ?? 4.0;
      setState(() {
        _calculatedNutrition = {
          'calories': (totalCalories / servings).round(),
          'protein': (totalProtein / servings).toStringAsFixed(1),
          'carbohydrates': (totalCarbs / servings).toStringAsFixed(1),
          'fat': (totalFat / servings).toStringAsFixed(1),
          'fiber': (totalFiber / servings).toStringAsFixed(1),
          'sugar': (totalSugar / servings).toStringAsFixed(1),
          'sodium': (totalSodium / servings).toStringAsFixed(1),
        };
        _isCalculating = false;
      });
    } catch (e) {
      setState(() => _isCalculating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al calcular nutrición: $e')),
        );
      }
    }
  }

  void _addIngredient() {
    final name = _ingredientNameController.text.trim();
    final quantity = double.tryParse(_ingredientQuantityController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del ingrediente')),
      );
      return;
    }

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad válida')),
      );
      return;
    }

    // Convertir a plural
    final pluralName = PluralHelper.toPlural(name);

    setState(() {
      _ingredients.add({
        'name': pluralName.toLowerCase(),
        'quantity': quantity,
        'unit': _ingredientUnit,
      });
      _ingredientNameController.clear();
      _ingredientQuantityController.clear();
      _ingredientUnit = 'gramos';
      _calculatedNutrition = null; // Resetear nutrición
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      _calculatedNutrition = null; // Resetear nutrición
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ingrediente')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Calcular nutrición automáticamente si no está calculada
      if (_calculatedNutrition == null) {
        await _calculateNutrition();
        // Esperar un momento para que se actualice el estado
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final headers = await _authService.getAuthHeaders();
      // Formatear ingredientes como string separado por comas
      final ingredientsString = _ingredients.map((ing) {
        return '${ing['name']}: ${ing['quantity']} ${ing['unit']}';
      }).join(', ');

      // Formatear nutrientes como string
      String nutrientsString = 'calories 0';
      if (_calculatedNutrition != null) {
        final nutrients = _calculatedNutrition!;
        nutrientsString = 'calories ${nutrients['calories']}, protein ${nutrients['protein']}, carbohydrates ${nutrients['carbohydrates']}, fat ${nutrients['fat']}, fiber ${nutrients['fiber']}, sugar ${nutrients['sugar']}, sodium ${nutrients['sodium']}';
      }

      // Combinar descripción e instrucciones
      // Si hay descripción, incluirla; si no, solo instrucciones
      String fullDescription;
      if (_descriptionController.text.trim().isNotEmpty) {
        fullDescription = '${_descriptionController.text.trim()}\n\nInstrucciones:\n${_instructionsController.text.trim()}';
      } else {
        fullDescription = 'Instrucciones:\n${_instructionsController.text.trim()}';
      }

      final servings = double.tryParse(_servingsController.text) ?? 4.0;
      final caloriesPerServing = _calculatedNutrition != null 
          ? _calculatedNutrition!['calories'] as int 
          : 0;
      
      final recipe = {
        'title': _titleController.text.trim(),
        'description': fullDescription,
        'time_minutes': int.tryParse(_timeController.text) ?? 30,
        'difficulty': _difficulty,
        'ingredients': ingredientsString,
        'nutrients': nutrientsString,
        'image_url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop', // Imagen por defecto
        'tags': '',
        'servings': servings,
        'calories_per_serving': caloriesPerServing, // Calorías por porción
        // NO incluir user_id aquí - el backend lo obtiene del token JWT
      };
      
      print('📤 ${_isEditing ? 'Actualizando' : 'Enviando'} receta al backend: ${recipe['title']}');
      print('📤 UserId del token: ${_authService.userId}');
      print('📤 Tipo de receta: ${widget.recipeType ?? 'private'}');
      print('📤 Índice de receta: ${widget.recipeIndex}');

      // Intentar guardar/actualizar en backend primero, si está disponible
      bool saved = false;
      final url = await AppConfig.getBackendUrl();
      final recipeType = widget.recipeType ?? 'private';
      
      try {
        http.Response response;
        
        if (_isEditing && widget.recipeIndex != null) {
          // Actualizar receta existente
          String endpoint;
          if (recipeType == 'general') {
            endpoint = '$url/recipes/general/${widget.recipeIndex}';
          } else if (recipeType == 'public') {
            endpoint = '$url/recipes/public/${widget.recipeIndex}';
          } else {
            endpoint = '$url/recipes/private/${widget.recipeIndex}';
          }
          
          response = await http.put(
            Uri.parse(endpoint),
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(recipe),
          ).timeout(const Duration(seconds: 30));
        } else {
          // Crear nueva receta (solo privadas se pueden crear desde aquí)
          response = await http.post(
            Uri.parse('$url/recipes/private'),
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(recipe),
          ).timeout(const Duration(seconds: 30));
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          saved = true;
          final responseData = jsonDecode(response.body);
          print('✅ Receta ${_isEditing ? 'actualizada' : 'guardada'} en backend correctamente');
          print('📋 Response: $responseData');
          // Esperar un momento para que el backend termine de escribir el archivo
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          print('⚠️ Backend respondió con status ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('Backend no disponible o error, ${_isEditing ? 'actualizando' : 'guardando'} en Firebase: $e');
      }

      // Si el backend no está disponible, guardar directamente en Firebase
      if (!saved) {
        final userId = _authService.userId;
        if (userId != null) {
          // Guardar en recipes_private.json primero (más rápido)
          saved = await _firebaseRecipeService.savePrivateRecipe(recipe, userId);
          
          // Sincronizar también en los datos del usuario (en segundo plano, sin bloquear)
          if (saved) {
            // No esperar a que se sincronice en users/{userId}.json - hacerlo en segundo plano
            Future.microtask(() async {
              try {
                final firebaseUserService = FirebaseUserService();
                final userData = await firebaseUserService.getUserData(userId) ?? {
                  'user_id': userId,
                  'private_recipes': [],
                };
                
                List<dynamic> privateRecipes = [];
                if (userData['private_recipes'] != null) {
                  privateRecipes = List<dynamic>.from(userData['private_recipes']);
                }
                
                // Agregar la nueva receta
                recipe['user_id'] = userId;
                recipe['created_at'] = DateTime.now().toIso8601String();
                privateRecipes.add(recipe);
                
                await firebaseUserService.syncUserPrivateRecipes(userId, privateRecipes);
                print('✅ Receta privada sincronizada en datos del usuario (background)');
              } catch (e) {
                print('⚠️ Error sincronizando receta en datos del usuario (background): $e');
              }
            });
          }
        } else {
          throw Exception('Usuario no autenticado');
        }
      } else {
        // Si se guardó/actualizó en backend, también sincronizar en Firebase (solo para recetas privadas)
        if (recipeType == 'private') {
          final userId = _authService.userId;
          if (userId != null) {
            // Sincronizar inmediatamente (no en segundo plano) para que esté disponible al recargar
            try {
              final firebaseUserService = FirebaseUserService();
              final userData = await firebaseUserService.getUserData(userId) ?? {
                'user_id': userId,
                'private_recipes': [],
              };
              
              List<dynamic> privateRecipes = [];
              if (userData['private_recipes'] != null) {
                privateRecipes = List<dynamic>.from(userData['private_recipes']);
              }
              
              // Verificar si la receta ya existe (por título)
              final recipeTitle = recipe['title'] as String;
              privateRecipes.removeWhere((r) => r['title'] == recipeTitle && r['user_id'] == userId);
              
              // Agregar/actualizar la receta con metadata
              final recipeWithMetadata = Map<String, dynamic>.from(recipe);
              recipeWithMetadata['user_id'] = userId;
              if (_isEditing && widget.recipeToEdit != null) {
                // Mantener created_at si existe
                recipeWithMetadata['created_at'] = widget.recipeToEdit!['created_at'] ?? DateTime.now().toIso8601String();
                recipeWithMetadata['updated_at'] = DateTime.now().toIso8601String();
              } else {
                recipeWithMetadata['created_at'] = DateTime.now().toIso8601String();
              }
              privateRecipes.add(recipeWithMetadata);
              
              await firebaseUserService.syncUserPrivateRecipes(userId, privateRecipes);
              print('✅ Receta privada sincronizada en datos del usuario (users/$userId.json)');
            } catch (e) {
              print('⚠️ Error sincronizando receta en datos del usuario: $e');
              // Continuar aunque falle Firebase - la receta ya está en el backend
            }
          }
        }
      }

      if (saved) {
        // Agregar automáticamente a favoritos solo si es nueva receta
        if (!_isEditing) {
          try {
            final recipeId = _titleController.text.trim();
            await _recipeService.addToFavorites(recipeId);
            print('✅ Receta agregada automáticamente a favoritos');
          } catch (e) {
            print('⚠️ Error agregando a favoritos: $e');
          }
        }
        
        // Invalidar cache según el tipo de receta
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = recipeType == 'general' ? 'recipes_general' :
                          recipeType == 'public' ? 'recipes_public' :
                          'recipes_private';
          await prefs.remove(cacheKey);
          await prefs.remove('${cacheKey}_timestamp');
          print('✅ Cache de recetas $recipeType invalidado');
        } catch (e) {
          print('Error invalidating cache: $e');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing 
                ? '✅ Receta actualizada correctamente'
                : '✅ Receta guardada y agregada a favoritos'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
          // Volver con resultado indicando que se guardó/actualizó y debe recargar
          Navigator.pop(context, {
            'saved': true, 
            'filter': recipeType == 'general' ? 'general' : 
                     recipeType == 'public' ? 'public' : 'private',
            'updated': _isEditing,
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al guardar la receta'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nueva Receta',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRecipe,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditing ? 'Actualizar' : 'Guardar',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tiempo y Dificultad
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: InputDecoration(
                        labelText: 'Tiempo (min) *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el tiempo';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: InputDecoration(
                        labelText: 'Dificultad *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['Fácil', 'Media', 'Difícil']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _difficulty = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Porciones
              TextFormField(
                controller: _servingsController,
                decoration: InputDecoration(
                  labelText: 'Porciones',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Descripción (opcional)
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Instrucciones (obligatorio)
              TextFormField(
                controller: _instructionsController,
                decoration: InputDecoration(
                  labelText: 'Instrucciones *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa las instrucciones';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Ingredientes
              const Text(
                'Ingredientes *',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Agregar ingrediente
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ingredientNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (value) {
                        // Al presionar Enter, mover foco a cantidad
                        FocusScope.of(context).nextFocus();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _ingredientQuantityController,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        // Al presionar Enter, agregar ingrediente si hay nombre
                        if (_ingredientNameController.text.trim().isNotEmpty) {
                          _addIngredient();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ingredientUnit,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['gramos', 'unidades', 'tazas', 'cucharadas']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _ingredientUnit = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                    iconSize: 32,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de ingredientes
              if (_ingredients.isNotEmpty) ...[
                ..._ingredients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ingredient = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${ingredient['name']} - ${ingredient['quantity']} ${ingredient['unit']}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeIngredient(index),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),

                // Botón para calcular nutrición
                ElevatedButton.icon(
                  onPressed: _isCalculating ? null : _calculateNutrition,
                  icon: _isCalculating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate),
                  label: Text(_isCalculating ? 'Calculando...' : 'Calcular Nutrición'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Información nutricional calculada
                if (_calculatedNutrition != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información Nutricional (por porción)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNutritionRow('Calorías', '${_calculatedNutrition!['calories']} kcal'),
                        _buildNutritionRow('Proteínas', '${_calculatedNutrition!['protein']} g'),
                        _buildNutritionRow('Carbohidratos', '${_calculatedNutrition!['carbohydrates']} g'),
                        _buildNutritionRow('Grasas', '${_calculatedNutrition!['fat']} g'),
                        _buildNutritionRow('Fibra', '${_calculatedNutrition!['fiber']} g'),
                        _buildNutritionRow('Azúcar', '${_calculatedNutrition!['sugar']} g'),
                        _buildNutritionRow('Sodio', '${_calculatedNutrition!['sodium']} mg'),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

