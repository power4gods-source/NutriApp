import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../utils/ingredient_normalizer.dart';
import 'recipe_detail_screen.dart';

class AIRecipeGeneratorScreen extends StatefulWidget {
  const AIRecipeGeneratorScreen({super.key});

  @override
  State<AIRecipeGeneratorScreen> createState() => _AIRecipeGeneratorScreenState();
}

class _AIRecipeGeneratorScreenState extends State<AIRecipeGeneratorScreen> {
  final AuthService _authService = AuthService();
  final TrackingService _trackingService = TrackingService();
  
  // Ingredientes disponibles (cargados desde "Alimentación")
  List<String> _availableIngredients = [];
  // Ingredientes seleccionados por el usuario
  Set<String> _selectedIngredients = {};
  // Buscador de nuevos ingredientes
  final TextEditingController _ingredientSearchController = TextEditingController();
  List<Map<String, dynamic>> _ingredientSuggestions = [];
  bool _isLoadingIngredients = true;
  
  // Filtros
  String? _selectedDifficulty;
  int? _maxTime;
  String? _mealType; // "Desayuno", "Comida", "Cena" o null (todos)
  
  // Resultados
  List<Map<String, dynamic>> _recipes = [];
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserIngredients();
    _ingredientSearchController.addListener(_onIngredientSearchChanged);
  }

  @override
  void dispose() {
    _ingredientSearchController.dispose();
    super.dispose();
  }

  void _onIngredientSearchChanged() {
    final query = _ingredientSearchController.text.trim();
    if (query.length >= 2) {
      _searchIngredientSuggestions(query);
    } else {
      setState(() => _ingredientSuggestions = []);
    }
  }

  Future<void> _searchIngredientSuggestions(String query) async {
    try {
      final foods = await _trackingService.searchFoods(query);
      setState(() {
        _ingredientSuggestions = foods.take(5).map((food) => {
          'name': food['name'] ?? '',
          'food_id': food['food_id'] ?? '',
        }).toList();
      });
    } catch (e) {
      print('Error searching ingredients: $e');
      setState(() => _ingredientSuggestions = []);
    }
  }

  Future<void> _loadUserIngredients() async {
    setState(() => _isLoadingIngredients = true);
    
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      
      final response = await http.get(
        Uri.parse('$url/profile/ingredients'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ingredients = data['ingredients'] as List? ?? [];
        
        setState(() {
          _availableIngredients = ingredients.map((ing) {
            if (ing is Map) {
              return (ing['name'] ?? '').toString();
            }
            return ing.toString();
          }).where((name) => name.isNotEmpty).toList();
          // Inicialmente ninguno seleccionado
          _selectedIngredients = {};
          _isLoadingIngredients = false;
        });
      } else {
        setState(() => _isLoadingIngredients = false);
      }
    } catch (e) {
      print('Error cargando ingredientes: $e');
      setState(() => _isLoadingIngredients = false);
    }
  }

  void _addIngredient(String ingredient) {
    final trimmed = ingredient.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _selectedIngredients.add(trimmed);
      if (!_availableIngredients.contains(trimmed)) {
        _availableIngredients.add(trimmed);
      }
    });
    _ingredientSearchController.clear();
    setState(() => _ingredientSuggestions = []);
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _selectedIngredients.remove(ingredient);
    });
  }

  Future<void> _generateRecipes() async {
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un ingrediente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _recipes = [];
    });

    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      
      final selectedList = _selectedIngredients.toList();
      // Lógica: 1-3 ingredientes -> must_include_all. 4+ -> strict_ingredients_only (solo esos + condimentos)
      final mustIncludeAll = selectedList.length <= 3;
      final strictIngredientsOnly = selectedList.length >= 4;
      
      final response = await http.post(
        Uri.parse('$url/ai/generate-recipes'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'meal_type': _mealType ?? 'Comida',
          'ingredients': selectedList,
          'num_recipes': 5,
          'must_include_all': mustIncludeAll,
          'strict_ingredients_only': strictIngredientsOnly,
          'difficulty': _selectedDifficulty,
          'max_time': _maxTime,
          'save_to_private': true,
        }),
      ).timeout(const Duration(seconds: 60));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('📥 Parsed data: $data');
          
          final recipes = data['recipes'] ?? [];
          print('📥 Recipes count: ${recipes.length}');
          final savedCount = (data['saved_count'] ?? 0);
          final duplicateCount = (data['duplicate_count'] ?? 0);
          
          if (recipes.isEmpty) {
            // Check if there's an error message
            final errorMsg = data['error'] as String?;
            setState(() {
              _error = errorMsg ?? 'No se generaron recetas. Intenta con otros ingredientes o filtros.';
              _isGenerating = false;
            });
          } else {
            // Validate that recipes have required fields
            final validRecipes = <Map<String, dynamic>>[];
            for (var recipe in recipes) {
              if (recipe is Map<String, dynamic>) {
                // Ensure all required fields exist
                final validRecipe = {
                  'title': recipe['title'] ?? 'Receta sin título',
                  'description': recipe['description'] ?? '',
                  'ingredients': recipe['ingredients'] ?? '',
                  'ingredients_detailed': recipe['ingredients_detailed'] ?? [],
                  'instructions': recipe['instructions'] ?? [],
                  'time_minutes': recipe['time_minutes'] ?? 30,
                  'difficulty': recipe['difficulty'] ?? 'Media',
                  'tags': recipe['tags'] ?? '',
                  'image_url': recipe['image_url'] ?? '',
                  'nutrients': recipe['nutrients'] ?? 'calories 0',
                  'servings': recipe['servings'] ?? 4,
                  'calories_per_serving': recipe['calories_per_serving'] ?? 0,
                  'is_ai_generated': true,
                  'meal_type': recipe['meal_type'] ?? _mealType ?? 'Comida',
                };
                validRecipes.add(validRecipe);
              }
            }
            
            setState(() {
              _recipes = validRecipes;
              _isGenerating = false;
            });
            print('✅ Recetas cargadas y validadas: ${_recipes.length}');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ ${_recipes.length} sugerencias. Guardadas: $savedCount. Duplicadas: $duplicateCount.',
                  ),
                  backgroundColor: const Color(0xFF4CAF50),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          print('❌ Error parseando respuesta: $e');
          setState(() {
            _error = 'Error al procesar las recetas: $e';
            _isGenerating = false;
          });
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          setState(() {
            _error = errorData['error'] ?? errorData['detail'] ?? 'Error al generar recetas (${response.statusCode})';
            _isGenerating = false;
          });
        } catch (e) {
          setState(() {
            _error = 'Error del servidor (${response.statusCode}): ${response.body}';
            _isGenerating = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error completo: $e');
      print('❌ Stack trace: $stackTrace');
      setState(() {
        _error = 'Error de conexión: $e';
        _isGenerating = false;
      });
    }
  }

  void _navigateToRecipe(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final title = recipe['title'] ?? 'Sin título';
    final time = recipe['time_minutes'] ?? 0;
    final difficulty = recipe['difficulty'] ?? 'Fácil';
    final caloriesPerServing = recipe['calories_per_serving'] ?? 0;
    final description = recipe['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToRecipe(recipe),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge IA y título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'IA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Descripción
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              // Información: duración, dificultad, raciones, kcal/ración
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        '$time min',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      difficulty,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (recipe['servings'] != null && recipe['servings'] > 0) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['servings']} raciones',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (caloriesPerServing > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$caloriesPerServing kcal/ración',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header (igual que Buscar Recetas)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Genera recetas con CookAInd',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_isGenerating && _recipes.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _generateRecipes,
                        tooltip: 'Generar nuevas recetas',
                      )
                    else
                      const SizedBox(width: 38),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Contenido en tarjeta
              Flexible(
                child: _isLoadingIngredients
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _isGenerating
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: AppTheme.primary),
                                const SizedBox(height: 20),
                                Text(
                                  'Generando recetas con CookAInd...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Esto puede tardar unos segundos',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                // Dificultad + Tiempo máx
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedDifficulty,
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                                        decoration: InputDecoration(
                                          labelText: 'Dificultad',
                                          labelStyle: const TextStyle(color: Colors.black54),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Colors.black38),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Colors.black38),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: null, child: Text('Todas')),
                                          DropdownMenuItem(value: 'Fácil', child: Text('Fácil')),
                                          DropdownMenuItem(value: 'Media', child: Text('Media')),
                                          DropdownMenuItem(value: 'Difícil', child: Text('Difícil')),
                                        ],
                                        onChanged: (value) => setState(() => _selectedDifficulty = value),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        style: const TextStyle(color: Colors.black87),
                                        decoration: InputDecoration(
                                          labelText: 'Tiempo máx (min)',
                                          labelStyle: const TextStyle(color: Colors.black54),
                                          hintStyle: const TextStyle(color: Colors.black54),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Colors.black38),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Colors.black38),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            _maxTime = value.isEmpty ? null : int.tryParse(value);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Buscador
                                TextField(
                                  controller: _ingredientSearchController,
                                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: 'Añade ingredientes...',
                                    hintStyle: const TextStyle(color: Colors.black54),
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.black38),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.black38),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty) {
                                      if (_ingredientSuggestions.isNotEmpty) {
                                        final first = _ingredientSuggestions.first['name'] ?? '';
                                        if (first.isNotEmpty) {
                                          _addIngredient(first);
                                        } else {
                                          _addIngredient(value);
                                        }
                                      } else {
                                        _addIngredient(value);
                                      }
                                    }
                                  },
                                ),
                                if (_ingredientSuggestions.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: _ingredientSuggestions.map((food) {
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.restaurant_menu, size: 20, color: Color(0xFF4CAF50)),
                                          title: Text(
                                            IngredientNormalizer.toSingular((food['name'] ?? '').toString()),
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          onTap: () {
                                            final name = food['name'] ?? '';
                                            if (name.isNotEmpty) _addIngredient(name);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                // Mis ingredientes
                                Text(
                                  'Combina los que ya tienes:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_availableIngredients.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _availableIngredients.map((ing) {
                                      final isSelected = _selectedIngredients.contains(ing);
                                      return InkWell(
                                        onTap: () {
                                          if (isSelected) {
                                            _removeIngredient(ing);
                                          } else {
                                            _addIngredient(ing);
                                          }
                                        },
                                        child: Chip(
                                          label: Text(IngredientNormalizer.toSingular(ing), style: const TextStyle(color: Colors.black87)),
                                          backgroundColor: isSelected ? Colors.purple[100]! : AppTheme.cardBackground,
                                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                                          labelStyle: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                else
                                  Text(
                                    'No tienes ingredientes guardados. Usa el buscador para añadir.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                // Seleccionados
                                Text(
                                  'Seleccionados:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_selectedIngredients.isEmpty)
                                  Text(
                                    'No hay ingredientes seleccionados',
                                    style: TextStyle(color: AppTheme.textSecondary(context)),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _selectedIngredients.map((ing) {
                                      return InkWell(
                                        onTap: () => _removeIngredient(ing),
                                        child: Chip(
                                          label: Text(IngredientNormalizer.toSingular(ing), style: const TextStyle(color: Colors.black87)),
                                          backgroundColor: Colors.purple[100]!,
                                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                                          labelStyle: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 8),
                                if (_selectedIngredients.length <= 3)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Todas las recetas incluirán estos ingredientes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                                  )
                                else
                                  Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Las recetas usarán ÚNICAMENTE estos ingredientes (más condimentos básicos)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                                  ),
                                const SizedBox(height: 24),
                                // Botón generar (llamativo, contraste con fondo claro)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _selectedIngredients.isEmpty || _isGenerating ? null : _generateRecipes,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      elevation: 4,
                                      shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isGenerating
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Generar sugerencias',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                
                                // Resultados / Error
                                if (_error != null)
                                  Container(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline,
                                            size: 64, color: Colors.red[300]),
                                        const SizedBox(height: 16),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 32),
                                          child: Text(
                                            _error!,
                                            style: TextStyle(color: Colors.red[700]),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _generateRecipes,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Reintentar'),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_recipes.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.restaurant_menu,
                                            size: 64, color: Colors.grey[400]),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Haz clic en "Generar sugerencias" para comenzar',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary(context),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                                  Padding(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(bottom: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline, color: Colors.blue),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${_recipes.length} recetas generadas. Toca una receta para ver los detalles.',
                                                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ..._recipes.map((recipe) => _buildRecipeCard(recipe)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
