import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../services/recipe_service.dart';
import '../main.dart';
import '../config/app_theme.dart';

class AddConsumptionScreen extends StatefulWidget {
  const AddConsumptionScreen({super.key});

  @override
  State<AddConsumptionScreen> createState() => _AddConsumptionScreenState();
}

class _AddConsumptionScreenState extends State<AddConsumptionScreen> {
  final AuthService _authService = AuthService();
  final TrackingService _trackingService = TrackingService();
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _foodSearchController = TextEditingController();
  final TextEditingController _recipeSearchController = TextEditingController();
  
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedMealType = 'comida';
  List<Map<String, dynamic>> _selectedFoods = [];
  List<Map<String, dynamic>> _foodSuggestions = [];
  List<Map<String, dynamic>> _recipeSuggestions = [];
  bool _isSearching = false;
  bool _isSearchingRecipes = false;
  int _activeSearchTab = 0; // 0 = alimentos, 1 = recetas

  @override
  void initState() {
    super.initState();
    _foodSearchController.addListener(_onFoodSearchChanged);
    _recipeSearchController.addListener(_onRecipeSearchChanged);
  }

  @override
  void dispose() {
    _foodSearchController.dispose();
    _recipeSearchController.dispose();
    super.dispose();
  }

  void _onFoodSearchChanged() {
    if (_activeSearchTab == 0) {
      final query = _foodSearchController.text.trim();
      if (query.length >= 2) {
        _searchFoods(query);
      } else {
        setState(() => _foodSuggestions = []);
      }
    }
  }

  void _onRecipeSearchChanged() {
    if (_activeSearchTab == 1) {
      final query = _recipeSearchController.text.trim();
      if (query.length >= 2) {
        _searchRecipes(query);
      } else {
        setState(() => _recipeSuggestions = []);
      }
    }
  }

  Future<void> _searchRecipes(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _recipeSuggestions = [];
        _isSearchingRecipes = false;
      });
      return;
    }
    
    setState(() => _isSearchingRecipes = true);
    try {
      final allRecipes = await _recipeService.getAllRecipes();
      final filtered = allRecipes.where((recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase();
        return title.contains(query.toLowerCase());
      }).take(10).toList();
      
      setState(() {
        _recipeSuggestions = filtered.cast<Map<String, dynamic>>();
        _isSearchingRecipes = false;
      });
    } catch (e) {
      print('Error searching recipes: $e');
      setState(() {
        _recipeSuggestions = [];
        _isSearchingRecipes = false;
      });
    }
  }

  void _addRecipeAsConsumption(Map<String, dynamic> recipe) {
    // Obtener calorías por porción
    final caloriesPerServing = recipe['calories_per_serving'] ?? 
                               (recipe['calories'] != null && recipe['servings'] != null 
                                 ? (recipe['calories'] / recipe['servings']).round() 
                                 : 0);
    
    if (caloriesPerServing <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta receta no tiene información nutricional calculada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Añadir la receta como un "alimento" especial con las calorías y nutrientes
    final recipeTitle = recipe['title'] ?? 'Receta';
    setState(() {
      _selectedFoods.add({
        'food_id': 'recipe_${recipeTitle.replaceAll(' ', '_')}',
        'name': recipeTitle,
        'quantity': 1.0,
        'unit': 'ración',
        'calories': caloriesPerServing.toDouble(),
        'is_recipe': true,
        'recipe_data': recipe, // Incluir toda la receta para que el backend pueda parsear nutrientes
      });
    });
    
    _recipeSearchController.clear();
    setState(() {
      _recipeSuggestions = [];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receta "$recipeTitle" añadida: $caloriesPerServing kcal/ración'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _searchFoods(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _foodSuggestions = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    try {
      final foods = await _trackingService.searchFoods(query);
      setState(() {
        _foodSuggestions = foods.cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching foods: $e');
      setState(() {
        _foodSuggestions = [];
        _isSearching = false;
      });
    }
  }

  void _addFood(Map<String, dynamic> food, {double quantity = 100.0, String unit = 'gramos'}) {
    // Validar y obtener el food_id - puede estar en diferentes campos
    String? foodId;
    
    // Intentar obtener food_id de diferentes formas
    if (food['food_id'] != null) {
      foodId = food['food_id'].toString();
    } else if (food['id'] != null) {
      foodId = food['id'].toString();
    } else if (food['_id'] != null) {
      foodId = food['_id'].toString();
    }
    
    // Si aún no hay food_id, intentar buscarlo por nombre
    if (foodId == null || foodId.isEmpty) {
      final foodName = food['name'] ?? '';
      if (foodName.isNotEmpty) {
        // Buscar el alimento por nombre para obtener su ID
        _findFoodIdByName(foodName, quantity, unit);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error: El alimento no tiene ID válido'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    print('📝 Añadiendo alimento: ${food['name']} (ID: $foodId, cantidad: $quantity $unit)');
    
    setState(() {
      _selectedFoods.add({
        'food_id': foodId!,
        'name': food['name'] ?? '',
        'quantity': quantity,
        'unit': unit,
        // Incluir unit_conversions y default_unit para que el backend pueda calcular correctamente
        'unit_conversions': food['unit_conversions'],
        'default_unit': food['default_unit'] ?? 'gramos',
      });
    });
    
    print('✅ Alimento añadido a la lista. Total: ${_selectedFoods.length}');
    print('📋 Lista actual: ${_selectedFoods.map((f) => '${f['name']} (ID: ${f['food_id']})').join(', ')}');
    
    _foodSearchController.clear();
    setState(() {
      _foodSuggestions = [];
    });
  }
  
  Future<void> _findFoodIdByName(String foodName, double quantity, String unit) async {
    try {
      print('🔍 Buscando alimento: $foodName');
      
      // Buscar el alimento exacto
      final foods = await _trackingService.searchFoods(foodName);
      print('📋 Resultados de búsqueda: ${foods.length} alimentos encontrados');
      
      // Si no encuentra, intentar con variaciones comunes
      List<dynamic> allFoods = List.from(foods);
      if (allFoods.isEmpty) {
        print('⚠️ No se encontró con búsqueda exacta, intentando variaciones...');
        // Intentar con singular/plural
        final lowerName = foodName.toLowerCase();
        if (lowerName.endsWith('s') && lowerName.length > 1) {
          final singular = lowerName.substring(0, lowerName.length - 1);
          allFoods = await _trackingService.searchFoods(singular);
          print('📋 Búsqueda singular: ${allFoods.length} resultados');
        } else if (!lowerName.endsWith('s')) {
          allFoods = await _trackingService.searchFoods('${lowerName}s');
          print('📋 Búsqueda plural: ${allFoods.length} resultados');
        }
      }
      
      if (allFoods.isNotEmpty) {
        // Buscar el mejor match (exacto primero)
        Map<String, dynamic>? foundFood;
        final lowerName = foodName.toLowerCase();
        
        // Intentar match exacto primero
        for (var food in allFoods) {
          final foodMap = food as Map<String, dynamic>;
          final foodNameLower = (foodMap['name'] ?? '').toString().toLowerCase();
          if (foodNameLower == lowerName) {
            foundFood = foodMap;
            print('✅ Match exacto encontrado: ${foodMap['name']} (ID: ${foodMap['food_id']})');
            break;
          }
        }
        
        // Si no hay match exacto, usar el primero
        foundFood ??= allFoods.first as Map<String, dynamic>;
        print('📦 Usando alimento: ${foundFood['name']} (ID: ${foundFood['food_id']})');
        
        // Obtener food_id de forma segura
        String foodId = '';
        if (foundFood != null) {
          foodId = (foundFood['food_id'] ?? foundFood['id'] ?? foundFood['_id'] ?? '').toString();
          print('🆔 Food ID obtenido: $foodId');
        }
        
        if (foodId.isNotEmpty) {
          setState(() {
            _selectedFoods.add({
              'food_id': foodId,
              'name': (foundFood?['name'] ?? foodName).toString(),
              'quantity': quantity,
              'unit': unit,
              // Incluir unit_conversions y default_unit para que el backend pueda calcular correctamente
              'unit_conversions': foundFood?['unit_conversions'],
              'default_unit': foundFood?['default_unit'] ?? 'gramos',
            });
          });
          _foodSearchController.clear();
          setState(() {
            _foodSuggestions = [];
          });
          print('✅ Alimento añadido correctamente: ${foundFood?['name'] ?? foodName} (ID: $foodId, cantidad: $quantity $unit)');
        } else {
          print('❌ No se pudo obtener food_id del alimento: ${foundFood?['name']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ No se pudo encontrar el ID del alimento: $foodName'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        print('❌ No se encontró ningún alimento para: $foodName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Alimento no encontrado: $foodName'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error finding food ID: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error al buscar el alimento'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeFood(int index) {
    setState(() {
      _selectedFoods.removeAt(index);
    });
  }

  Future<void> _saveConsumption() async {
    if (_selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un alimento')),
      );
      return;
    }

    // Validar que todos los alimentos tengan food_id válido (excepto recetas)
    final invalidFoods = _selectedFoods.where((food) {
      if (food['is_recipe'] == true) {
        return false; // Las recetas no necesitan food_id válido
      }
      final foodId = food['food_id'] ?? '';
      return foodId.toString().isEmpty;
    }).toList();
    
    if (invalidFoods.isNotEmpty) {
      // Intentar buscar los IDs de los alimentos inválidos
      for (var invalidFood in List.from(invalidFoods)) {
        final foodName = invalidFood['name'] ?? '';
        if (foodName.isNotEmpty) {
          await _findFoodIdByName(foodName, (invalidFood['quantity'] ?? 100.0).toDouble(), invalidFood['unit'] ?? 'gramos');
          // Eliminar el alimento inválido de la lista
          _selectedFoods.remove(invalidFood);
        }
      }
      
      // Verificar de nuevo (excluyendo recetas)
      final stillInvalid = _selectedFoods.where((food) {
        if (food['is_recipe'] == true) {
          return false; // Las recetas no necesitan food_id válido
        }
        final foodId = food['food_id'] ?? '';
        return foodId.toString().isEmpty;
      }).toList();
      
      if (stillInvalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${stillInvalid.length} alimento(s) no tienen ID válido. Por favor, elimínalos y vuelve a agregarlos.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }
    
    // Debug: mostrar los alimentos que se van a enviar
    print('📋 Alimentos a enviar (${_selectedFoods.length}):');
    for (var food in _selectedFoods) {
      final foodId = food['food_id'] ?? '';
      final name = food['name'] ?? '';
      final quantity = food['quantity'] ?? 0.0;
      final unit = food['unit'] ?? 'gramos';
      print('  - $name: food_id="$foodId", quantity=$quantity, unit=$unit');
      
      // Verificar que el food_id no esté vacío (excepto recetas)
      if (food['is_recipe'] != true && foodId.toString().isEmpty) {
        print('❌ ERROR: Alimento sin food_id: $name');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: "$name" no tiene ID válido. Por favor, elimínalo y vuelve a agregarlo.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    // Mostrar indicador de carga
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final success = await _trackingService.addConsumption(
        _selectedDate,
        _selectedMealType,
        _selectedFoods,
      );

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.pop(context); // Cerrar el diálogo de carga
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Consumo agregado correctamente'),
              backgroundColor: AppTheme.primary,
            ),
          );
          notifyConsumptionAdded?.call();
          Navigator.pop(context, true); // Return true to refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al agregar consumo. Verifica que los alimentos sean válidos y que estés autenticado.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al guardar consumo: $e');
      print('Stack trace: $stackTrace');
      
      // Cerrar indicador de carga
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al agregar consumo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Agregar Consumo',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveConsumption,
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Date and meal type selector
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  InkWell(
                    onTap: _selectDate,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMealTypeButton('Desayuno', 'desayuno', Icons.wb_sunny),
                      const SizedBox(width: 10),
                      _buildMealTypeButton('Comida', 'comida', Icons.lunch_dining),
                      const SizedBox(width: 10),
                      _buildMealTypeButton('Cena', 'cena', Icons.dinner_dining),
                      const SizedBox(width: 10),
                      _buildMealTypeButton('Snack', 'snack', Icons.cookie),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Food/Recipe search with tabs
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabs
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _activeSearchTab = 0;
                              _recipeSuggestions = [];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeSearchTab == 0 ? AppTheme.primary : Colors.grey.shade200,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Alimentos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _activeSearchTab == 0 ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _activeSearchTab = 1;
                              _foodSuggestions = [];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeSearchTab == 1 ? AppTheme.primary : Colors.grey.shade200,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Recetas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _activeSearchTab == 1 ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  TextField(
                    controller: _activeSearchTab == 0 ? _foodSearchController : _recipeSearchController,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: _activeSearchTab == 0 ? 'Buscar alimento...' : 'Buscar receta...',
                      hintStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                    ),
                  ),
                  if ((_isSearching && _activeSearchTab == 0) || (_isSearchingRecipes && _activeSearchTab == 1))
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  // Food suggestions
                  if (_activeSearchTab == 0 && _foodSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: _foodSuggestions.map((food) {
                          final foodId = food['food_id'] ?? food['id'] ?? food['_id'] ?? '';
                          final foodName = food['name'] ?? '';
                          
                          return ListTile(
                            title: Text(foodName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                            subtitle: Text('${food['nutrition_per_100g']?['calories'] ?? 0} kcal/100g', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            trailing: const Icon(Icons.add_circle, color: AppTheme.primary),
                            onTap: () {
                              if (foodId.toString().isEmpty) {
                                _findFoodIdByName(foodName, 100.0, 'gramos');
                              } else {
                                _showAddFoodDialog(food);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  // Recipe suggestions
                  if (_activeSearchTab == 1 && _recipeSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: _recipeSuggestions.map((recipe) {
                          final title = recipe['title'] ?? 'Sin título';
                          final caloriesPerServing = recipe['calories_per_serving'] ?? 
                                                     (recipe['calories'] != null && recipe['servings'] != null 
                                                       ? (recipe['calories'] / recipe['servings']).round() 
                                                       : 0);
                          
                          return ListTile(
                            leading: recipe['image_url'] != null && recipe['image_url'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      recipe['image_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 30, color: AppTheme.primary),
                                    ),
                                  )
                                : const Icon(Icons.restaurant, size: 30, color: AppTheme.primary),
                            title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                            subtitle: Text(caloriesPerServing > 0 
                                ? '$caloriesPerServing kcal/ración' 
                                : 'Sin información nutricional', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            trailing: const Icon(Icons.add_circle, color: AppTheme.primary),
                            onTap: () => _addRecipeAsConsumption(recipe),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Selected foods
            if (_selectedFoods.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alimentos Seleccionados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._selectedFoods.asMap().entries.map((entry) {
                      final index = entry.key;
                      final food = entry.value;
                      return _buildSelectedFoodItem(food, index);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTypeButton(String label, String mealType, IconData icon) {
    final isSelected = _selectedMealType == mealType;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMealType = mealType),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade700, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFoodItem(Map<String, dynamic> food, int index) {
    final isRecipe = food['is_recipe'] == true;
    final calories = food['calories'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecipe ? Colors.orange.withValues(alpha: 0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isRecipe ? Border.all(color: Colors.orange.shade700, width: 1) : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          if (isRecipe)
            Icon(Icons.restaurant_menu, color: Colors.orange.shade700, size: 20),
          if (isRecipe) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _editFoodQuantity(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${food['quantity']} ${food['unit']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 14, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (calories > 0)
                  Text(
                    '${calories.toInt()} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      color: isRecipe ? Colors.orange.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700),
            onPressed: () => _removeFood(index),
          ),
        ],
      ),
    );
  }
  
  void _editFoodQuantity(int index) {
    final food = _selectedFoods[index];
    final quantityController = TextEditingController(text: food['quantity'].toString());
    String selectedUnit = food['unit'] ?? 'gramos';
    
    showDialog(
      context: context,
        builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Editar cantidad: ${food['name']}', style: const TextStyle(color: Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                style: const TextStyle(color: Colors.black87),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Unidad',
                  labelStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                ),
                items: [
                  const DropdownMenuItem(value: 'gramos', child: Text('gramos')),
                  const DropdownMenuItem(value: 'unidades', child: Text('unidades')),
                  if (food['unit_conversions'] != null)
                    ...(food['unit_conversions'] as Map<String, dynamic>).keys.map((unit) =>
                      DropdownMenuItem(value: unit, child: Text(unit))
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedUnit = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text);
                if (quantity != null && quantity > 0) {
                  setState(() {
                    _selectedFoods[index]['quantity'] = quantity;
                    _selectedFoods[index]['unit'] = selectedUnit;
                    // Recalcular calorías si es receta (el backend lo hará, pero actualizamos visualmente)
                    if (food['is_recipe'] == true && food['calories'] != null) {
                      final caloriesPerServing = food['calories'] ?? 0.0;
                      _selectedFoods[index]['calories'] = caloriesPerServing * quantity;
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa una cantidad válida'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getUnitItems(Map<String, dynamic> food) {
    final unitConversions = food['unit_conversions'];
    List<String> units = ['gramos']; // Unidad por defecto
    
    if (unitConversions != null && unitConversions is Map) {
      final Map<String, dynamic> conversions = Map<String, dynamic>.from(unitConversions);
      units = conversions.keys.toList().cast<String>();
    }
    
    return units.map((unit) {
      return DropdownMenuItem<String>(
        value: unit,
        child: Text(unit),
      );
    }).toList();
  }

  void _showAddFoodDialog(Map<String, dynamic> food) {
    final quantityController = TextEditingController(text: '100');
    String selectedUnit = food['default_unit'] ?? 'gramos';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Agregar ${food['name']}', style: const TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              style: const TextStyle(color: Colors.black87),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                labelStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedUnit,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Unidad',
                labelStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
              ),
              items: _getUnitItems(food),
              onChanged: (value) {
                if (value != null) selectedUnit = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 100.0;
              _addFood(food, quantity: quantity, unit: selectedUnit);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

