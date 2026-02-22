import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/ingredient_normalizer.dart';
import '../utils/snackbar_utils.dart';
import '../services/recipe_service.dart';
import '../services/tracking_service.dart';
import 'recipe_results_screen.dart';

class RecipeFinderScreen extends StatefulWidget {
  const RecipeFinderScreen({super.key});

  @override
  State<RecipeFinderScreen> createState() => _RecipeFinderScreenState();
}

class _RecipeFinderScreenState extends State<RecipeFinderScreen> {
  final RecipeService _recipeService = RecipeService();
  final TrackingService _trackingService = TrackingService();
  final List<String> _selectedIngredients = [];
  final TextEditingController _ingredientController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();
  
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String? _selectedDifficulty;
  int? _maxTime;
  int? _maxCalories;
  
  // Ingredientes sugeridos inicialmente (3 más comunes)
  // Se expande cuando el usuario añade nuevos ingredientes
  List<String> _availableIngredients = [
    'Pollo', 'Tomate', 'Queso'
  ];
  
  // Autocompletado de alimentos
  List<Map<String, dynamic>> _foodSuggestions = [];
  List<Map<String, dynamic>> _ingredientSuggestions = [];
  bool _isSearchingFoods = false;
  bool _isSearchingIngredients = false;
  
  List<dynamic> _bestMatches = []; // Recetas generales
  List<dynamic> _flexibleMatches = []; // Recetas públicas
  String _sortBy = 'matches'; // 'matches', 'time', 'difficulty'

  @override
  void initState() {
    super.initState();
    // Agregar listener para autocompletado de alimentos cuando el usuario escribe
    _queryController.addListener(() {
      _onQueryChanged();
    });
    _ingredientController.addListener(() {
      _onIngredientChanged();
    });
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _queryController.dispose();
    super.dispose();
  }
  
  void _onQueryChanged() {
    final query = _queryController.text.trim();
    if (query.length >= 1) {
      _searchFoods(query, isIngredient: false);
    } else {
      setState(() => _foodSuggestions = []);
    }
  }
  
  void _onIngredientChanged() {
    final query = _ingredientController.text.trim();
    if (query.length >= 1) {
      _searchFoods(query, isIngredient: true);
    } else {
      setState(() => _ingredientSuggestions = []);
    }
  }
  
  Future<void> _searchFoods(String query, {bool isIngredient = false}) async {
    if (query.isEmpty) {
      setState(() {
        if (isIngredient) {
          _ingredientSuggestions = [];
        } else {
          _foodSuggestions = [];
        }
      });
      return;
    }
    
    if (isIngredient) {
      setState(() => _isSearchingIngredients = true);
    } else {
      setState(() => _isSearchingFoods = true);
    }
    
    try {
      final foods = await _trackingService.searchFoods(query);
      final suggestions = foods.take(5).map((food) => {
        'name': food['name'] ?? '',
        'food_id': food['food_id'] ?? '',
      }).toList();
      
      setState(() {
        if (isIngredient) {
          _ingredientSuggestions = suggestions;
          _isSearchingIngredients = false;
        } else {
          _foodSuggestions = suggestions;
          _isSearchingFoods = false;
        }
      });
    } catch (e) {
      print('Error searching foods: $e');
      setState(() {
        if (isIngredient) {
          _ingredientSuggestions = [];
          _isSearchingIngredients = false;
        } else {
          _foodSuggestions = [];
          _isSearchingFoods = false;
        }
      });
    }
  }
  
  Future<void> _searchRecipes() async {
    setState(() => _isSearching = true);
    
    try {
      print('🔍 Iniciando búsqueda de recetas...');
      
      // Obtener recetas generales y públicas (siempre ambas)
      print('📥 Obteniendo recetas generales...');
      final generalRecipes = await _recipeService.getGeneralRecipes();
      print('✅ Recetas generales obtenidas: ${generalRecipes.length}');
      
      print('📥 Obteniendo recetas públicas...');
      final publicRecipes = await _recipeService.getPublicRecipes();
      print('✅ Recetas públicas obtenidas: ${publicRecipes.length}');
      
      // Aplicar filtros y búsqueda
      final query = _queryController.text.trim().toLowerCase();
      final selectedLower = _selectedIngredients.map((ing) => ing.toLowerCase()).toList();
      
      print('🔎 Aplicando filtros:');
      print('  - Query: "$query"');
      print('  - Ingredientes: $selectedLower');
      print('  - Dificultad: $_selectedDifficulty');
      print('  - Tiempo máximo: $_maxTime');
      
      // Filtrar y buscar en recetas generales
      List<dynamic> filteredGeneral = _filterAndSearchRecipes(
        generalRecipes,
        query: query.isEmpty ? null : query,
        selectedIngredients: selectedLower.isEmpty ? null : selectedLower,
        difficulty: _selectedDifficulty,
        maxTime: _maxTime,
      );
      print('✅ Recetas generales filtradas: ${filteredGeneral.length}');
      
      // Filtrar y buscar en recetas públicas
      List<dynamic> filteredPublic = _filterAndSearchRecipes(
        publicRecipes,
        query: query.isEmpty ? null : query,
        selectedIngredients: selectedLower.isEmpty ? null : selectedLower,
        difficulty: _selectedDifficulty,
        maxTime: _maxTime,
      );
      print('✅ Recetas públicas filtradas: ${filteredPublic.length}');
      
      // Ordenar por máximas coincidencias
      filteredGeneral = _sortByMatches(filteredGeneral, query, selectedLower);
      filteredPublic = _sortByMatches(filteredPublic, query, selectedLower);
      
      setState(() {
        _bestMatches = filteredGeneral;
        _flexibleMatches = filteredPublic;
        _searchResults = [...filteredGeneral, ...filteredPublic];
        _isSearching = false;
      });
      
      print('🎯 Total de resultados: ${filteredGeneral.length + filteredPublic.length}');
      
      // Navegar a la pantalla de resultados
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeResultsScreen(
              generalRecipes: filteredGeneral,
              publicRecipes: filteredPublic,
              query: _queryController.text.trim(),
              selectedIngredients: _selectedIngredients,
              sortBy: _sortBy,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error al buscar recetas: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isSearching = false);
      if (mounted) {
        showErrorSnackBar(context, 'Error al buscar recetas: $e');
      }
    }
  }
  
  List<String> _getRecipeIngredients(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'];
    if (ingredients is String) {
      return ingredients.split(',').map((ing) => ing.trim()).toList();
    } else if (ingredients is List) {
      return ingredients.map((ing) {
        if (ing is Map) {
          return ing['name']?.toString() ?? '';
        }
        return ing.toString();
      }).toList();
    }
    return [];
  }
  
  int _countMatchingIngredients(Map<String, dynamic> recipe, List<String> selected) {
    final recipeIngredients = _getRecipeIngredients(recipe);
    final recipeIngredientsLower = recipeIngredients.map((ing) => ing.toLowerCase()).toList();
    
    return selected.where((selectedIng) {
      return recipeIngredientsLower.any((recipeIng) => 
        recipeIng.contains(selectedIng) || selectedIng.contains(recipeIng)
      );
    }).length;
  }
  
  // Filtrar y buscar recetas - OPTIMIZADO para búsquedas más rápidas
  List<dynamic> _filterAndSearchRecipes(
    List<dynamic> recipes, {
    String? query,
    List<String>? selectedIngredients,
    String? difficulty,
    int? maxTime,
  }) {
    if (recipes.isEmpty) {
      return [];
    }
    
    List<dynamic> filtered = List.from(recipes);
    
    // Si no hay filtros, devolver todas las recetas
    if (query == null && 
        (selectedIngredients == null || selectedIngredients.isEmpty) && 
        difficulty == null && 
        maxTime == null) {
      return filtered;
    }
    
    // OPTIMIZACIÓN: Filtrar solo por el campo relevante según el tipo de búsqueda
    // Si solo hay ingredientes, filtrar solo por ingredientes
    if (selectedIngredients != null && selectedIngredients.isNotEmpty && 
        query == null && difficulty == null && maxTime == null) {
      final selectedLower = selectedIngredients.map((ing) => ing.toLowerCase()).toList();
      return filtered.where((recipe) {
        final recipeIngredients = _getRecipeIngredients(recipe);
        final recipeIngredientsLower = recipeIngredients.map((ing) => ing.toLowerCase()).toList();
        return selectedLower.any((selected) {
          return recipeIngredientsLower.any((recipeIng) => 
            recipeIng.contains(selected) || selected.contains(recipeIng)
          );
        });
      }).toList();
    }
    
    // Si solo hay tiempo, filtrar solo por tiempo
    if (maxTime != null && maxTime > 0 && 
        query == null && (selectedIngredients == null || selectedIngredients.isEmpty) && difficulty == null) {
      return filtered.where((r) {
        final time = r['time_minutes'];
        if (time == null) return false;
        final timeInt = time is int ? time : (int.tryParse(time.toString()) ?? 999);
        return timeInt <= maxTime;
      }).toList();
    }
    
    // Si solo hay dificultad, filtrar solo por dificultad
    if (difficulty != null && difficulty.isNotEmpty && 
        query == null && (selectedIngredients == null || selectedIngredients.isEmpty) && maxTime == null) {
      return filtered.where((r) {
        final diff = (r['difficulty'] ?? '').toString().toLowerCase();
        return diff == difficulty.toLowerCase();
      }).toList();
    }
    
    // Si solo hay query (título), filtrar solo por título
    if (query != null && query.isNotEmpty && 
        (selectedIngredients == null || selectedIngredients.isEmpty) && 
        difficulty == null && maxTime == null) {
      final keywords = query.split(' ').where((k) => k.isNotEmpty).toList();
      return filtered.where((recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase();
        return keywords.any((keyword) => title.contains(keyword));
      }).toList();
    }
    
    // Si hay múltiples filtros, aplicar todos
    // Filtrar por nombre (keyword search) - solo en título para ser más rápido
    if (query != null && query.isNotEmpty) {
      final keywords = query.split(' ').where((k) => k.isNotEmpty).toList();
      filtered = filtered.where((recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase();
        return keywords.any((keyword) => title.contains(keyword));
      }).toList();
    }
    
    // Filtrar por ingredientes
    if (selectedIngredients != null && selectedIngredients.isNotEmpty) {
      final selectedLower = selectedIngredients.map((ing) => ing.toLowerCase()).toList();
      filtered = filtered.where((recipe) {
        final recipeIngredients = _getRecipeIngredients(recipe);
        final recipeIngredientsLower = recipeIngredients.map((ing) => ing.toLowerCase()).toList();
        return selectedLower.any((selected) {
          return recipeIngredientsLower.any((recipeIng) => 
            recipeIng.contains(selected) || selected.contains(recipeIng)
          );
        });
      }).toList();
    }
    
    // Filtrar por dificultad
    if (difficulty != null && difficulty.isNotEmpty) {
      filtered = filtered.where((r) {
        final diff = (r['difficulty'] ?? '').toString().toLowerCase();
        return diff == difficulty.toLowerCase();
      }).toList();
    }
    
    // Filtrar por tiempo máximo
    if (maxTime != null && maxTime > 0) {
      filtered = filtered.where((r) {
        final time = r['time_minutes'];
        if (time == null) return false;
        final timeInt = time is int ? time : (int.tryParse(time.toString()) ?? 999);
        return timeInt <= maxTime;
      }).toList();
    }
    
    return filtered;
  }
  
  // Ordenar por máximas coincidencias
  List<dynamic> _sortByMatches(List<dynamic> recipes, String query, List<String> selectedIngredients) {
    final sorted = List<dynamic>.from(recipes);
    sorted.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      
      // Contar coincidencias de ingredientes
      if (selectedIngredients.isNotEmpty) {
        scoreA += _countMatchingIngredients(a, selectedIngredients) * 10;
        scoreB += _countMatchingIngredients(b, selectedIngredients) * 10;
      }
      
      // Contar coincidencias de keywords en el título
      if (query.isNotEmpty) {
        final titleA = (a['title'] ?? '').toString().toLowerCase();
        final titleB = (b['title'] ?? '').toString().toLowerCase();
        final keywords = query.split(' ').where((k) => k.isNotEmpty).toList();
        
        for (final keyword in keywords) {
          if (titleA.contains(keyword)) scoreA += 5;
          if (titleB.contains(keyword)) scoreB += 5;
        }
      }
      
      return scoreB.compareTo(scoreA); // Ordenar de mayor a menor
    });
    return sorted;
  }

  void _addIngredient(String ingredient) {
    final trimmedIngredient = ingredient.trim();
    if (trimmedIngredient.isEmpty) return;
    
    setState(() {
      // Si ya está seleccionado, eliminarlo (toggle)
      if (_selectedIngredients.contains(trimmedIngredient)) {
        _selectedIngredients.remove(trimmedIngredient);
      } else {
        // Añadir a seleccionados
        _selectedIngredients.add(trimmedIngredient);
        
        // Si no está en la lista de disponibles, agregarlo
        if (!_availableIngredients.contains(trimmedIngredient)) {
          _availableIngredients.add(trimmedIngredient);
        }
      }
      // Limpiar el campo de texto
      _ingredientController.clear();
      _ingredientSuggestions = [];
    });
    
    // Filtrar recetas en tiempo real
    _filterRecipesInRealTime();
  }
  
  Future<void> _filterRecipesInRealTime() async {
    try {
      // Obtener todas las recetas
      final generalRecipes = await _recipeService.getGeneralRecipes();
      final publicRecipes = await _recipeService.getPublicRecipes();
      
      // Aplicar filtros actuales
      final query = _queryController.text.trim().toLowerCase();
      final selectedLower = _selectedIngredients.map((ing) => ing.toLowerCase()).toList();
      
      List<dynamic> filteredGeneral = _filterAndSearchRecipes(
        generalRecipes,
        query: query.isEmpty ? null : query,
        selectedIngredients: selectedLower.isEmpty ? null : selectedLower,
        difficulty: _selectedDifficulty,
        maxTime: _maxTime,
      );
      
      List<dynamic> filteredPublic = _filterAndSearchRecipes(
        publicRecipes,
        query: query.isEmpty ? null : query,
        selectedIngredients: selectedLower.isEmpty ? null : selectedLower,
        difficulty: _selectedDifficulty,
        maxTime: _maxTime,
      );
      
      // Ordenar por coincidencias
      filteredGeneral = _sortByMatches(filteredGeneral, query, selectedLower);
      filteredPublic = _sortByMatches(filteredPublic, query, selectedLower);
      
      setState(() {
        _bestMatches = filteredGeneral;
        _flexibleMatches = filteredPublic;
      });
    } catch (e) {
      print('Error filtrando recetas en tiempo real: $e');
    }
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _selectedIngredients.remove(ingredient);
    });
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
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Tu próximo plato...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Main content card - autosize, stretches down when adding ingredients
              Flexible(
                child: SingleChildScrollView(
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
                        Text(
                          'Ingredientes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Elige los ingredientes que quieres combinar',
                          style: TextStyle(color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 24),
                        
                        // Ingredient input with autocomplete
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ingredientController,
                                    style: const TextStyle(color: Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: 'Añadir ingrediente',
                                      hintStyle: const TextStyle(color: Colors.black54),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.black38),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.black38),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onChanged: (value) {
                                      setState(() {}); // Actualizar UI para mostrar/ocultar sugerencias
                                    },
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        // Si hay sugerencias, usar la primera
                                        if (_ingredientSuggestions.isNotEmpty) {
                                          final foodName = _ingredientSuggestions.first['name'] ?? '';
                                          if (foodName.isNotEmpty) {
                                            _addIngredient(foodName);
                                          } else {
                                            _addIngredient(value);
                                          }
                                        } else {
                                          _addIngredient(value);
                                        }
                                      }
                                    },
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_ingredientController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.black54),
                                    onPressed: () {
                                      _ingredientController.clear();
                                      setState(() => _ingredientSuggestions = []);
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                                  onPressed: () {
                                    if (_ingredientController.text.isNotEmpty) {
                                      // Si hay sugerencias, usar la primera
                                      if (_ingredientSuggestions.isNotEmpty) {
                                        final foodName = _ingredientSuggestions.first['name'] ?? '';
                                        if (foodName.isNotEmpty) {
                                          _addIngredient(foodName);
                                        } else {
                                          _addIngredient(_ingredientController.text);
                                        }
                                      } else {
                                        _addIngredient(_ingredientController.text);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            // Autocompletado de alimentos para ingredientes
                            if (_ingredientSuggestions.isNotEmpty && _ingredientController.text.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black26),
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
                                        // Agregar el alimento como ingrediente
                                        final foodName = food['name'] ?? '';
                                        if (foodName.isNotEmpty) {
                                          _addIngredient(foodName);
                                          _ingredientController.clear();
                                          setState(() => _ingredientSuggestions = []);
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Selected ingredients (scrollable)
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
                            children: _selectedIngredients.map((ingredient) {
                              return Chip(
                                label: Text(IngredientNormalizer.toSingular(ingredient), style: const TextStyle(color: Colors.black87)),
                                onDeleted: () => _removeIngredient(ingredient),
                                deleteIcon: const Icon(Icons.close, size: 18, color: Colors.black54),
                                backgroundColor: Colors.purple[100],
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 24),
                        
                        // Search query with autocomplete
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _queryController,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Buscar por nombre de receta...',
                                hintStyle: const TextStyle(color: Colors.black54),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                                suffixIcon: _queryController.text.isNotEmpty || _foodSuggestions.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.black54),
                                        onPressed: () {
                                          _queryController.clear();
                                          setState(() => _foodSuggestions = []);
                                        },
                                      )
                                    : null,
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
                              ),
                              onChanged: (value) {
                                setState(() {}); // Actualizar UI para mostrar/ocultar suffixIcon
                              },
                            ),
                            // Autocompletado de alimentos
                            if (_foodSuggestions.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: _foodSuggestions.map((food) {
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.restaurant_menu, size: 20, color: Color(0xFF4CAF50)),
                                      title: Text(
                                        IngredientNormalizer.toSingular((food['name'] ?? '').toString()),
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                      onTap: () {
                                        // Agregar el alimento como ingrediente
                                        final foodName = food['name'] ?? '';
                                        if (foodName.isNotEmpty) {
                                          _addIngredient(foodName);
                                          _queryController.clear();
                                          setState(() => _foodSuggestions = []);
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Filters
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
                                ),
                                items: ['Fácil', 'Media', 'Difícil'].map((d) {
                                  return DropdownMenuItem(
                                    value: d.toLowerCase(),
                                    child: Text(d, style: const TextStyle(color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedDifficulty = value);
                                  _filterRecipesInRealTime();
                                },
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
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() => _maxTime = int.tryParse(value));
                                  _filterRecipesInRealTime();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Search button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSearching ? null : _searchRecipes,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSearching
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Ver resultados',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

}




