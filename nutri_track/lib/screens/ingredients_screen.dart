import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/firebase_user_service.dart';
import '../services/tracking_service.dart';
import '../utils/ingredient_suggestions.dart';
import '../utils/plural_helper.dart';
import '../utils/ingredient_normalizer.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'ai_menu_screen.dart';
import 'ai_recipe_generator_screen.dart';
import 'ingredients_tab.dart';
import 'suggestions_screen.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  Set<String> _selectedMealTypes = {'Desayuno'}; // Selección múltiple
  final GlobalKey<_IngredientsTabContentState> _ingredientsKey = GlobalKey<_IngredientsTabContentState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Mis Ingredientes',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Meal type filters section
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Por lo que tienes en tu nevera',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMealFilter('Desayuno', _selectedMealTypes.contains('Desayuno')),
                    const SizedBox(width: 10),
                    _buildMealFilter('Comida', _selectedMealTypes.contains('Comida')),
                    const SizedBox(width: 10),
                    _buildMealFilter('Cena', _selectedMealTypes.contains('Cena')),
                  ],
                ),
                const SizedBox(height: 20),
                // Generate suggestions button - creates meal plan from ingredients
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ingredients = _ingredientsKey.currentState?.ingredients ?? [];
                      if (ingredients.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Agrega ingredientes primero'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Navegar a pantalla de generación de recetas con IA
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIRecipeGeneratorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 24),
                    label: const Text(
                      'Generar Receta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Ingredients content
          Expanded(
            child: _IngredientsTabContent(
              key: _ingredientsKey,
              onGeneratePressed: (ingredients) {
                // This callback is not used, but kept for compatibility
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealFilter(String label, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              // Si está seleccionado, deseleccionar (pero mantener al menos uno)
              if (_selectedMealTypes.length > 1) {
                _selectedMealTypes.remove(label);
              }
            } else {
              // Si no está seleccionado, seleccionar
              _selectedMealTypes.add(label);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// Wrapper to access IngredientsTab functionality
class _IngredientsTabContent extends StatefulWidget {
  final Function(List<Ingredient>)? onGeneratePressed;
  
  const _IngredientsTabContent({super.key, this.onGeneratePressed});

  @override
  State<_IngredientsTabContent> createState() => _IngredientsTabContentState();
}

class _IngredientsTabContentState extends State<_IngredientsTabContent> {
  final AuthService _authService = AuthService();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  final TrackingService _trackingService = TrackingService();
  final TextEditingController _ingredientController = TextEditingController();
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, String> _unitControllers = {};
  List<Ingredient> _ingredients = [];
  bool _isLoading = true;
  String? _editingIngredient;
  List<String> _suggestions = [];
  
  // Getter to access ingredients from parent
  List<Ingredient> get ingredients => _ingredients;
  
  // Verifica si un ingrediente es carne o pescado
  bool _isMeatOrFish(String name) {
    final meatFishKeywords = [
      'pollo', 'pavo', 'ternera', 'cerdo', 'cordero', 'carne', 'res',
      'pescado', 'salmón', 'atún', 'merluza', 'bacalao', 'sardina',
      'marisco', 'gamba', 'langosta', 'cangrejo', 'pulpo', 'calamar'
    ];
    return meatFishKeywords.any((keyword) => name.contains(keyword));
  }

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _ingredientController.addListener(() {
      _onSearchChanged();
      setState(() {}); // Update UI when text changes
    });
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    for (var controller in _editingControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _ingredientController.text;
    setState(() {
      _suggestions = IngredientSuggestions.getSuggestions(query);
    });
  }

  Future<void> _loadIngredients() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final headers = await _authService.getAuthHeaders();
      print('Loading ingredients with headers: $headers');
      
      final url = await AppConfig.getBackendUrl();
      final response = await http.get(
        Uri.parse('$url/profile/ingredients'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('La petición tardó demasiado. El backend puede no estar disponible.');
        },
      );

      print('Load response status: ${response.statusCode}');
      print('Load response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final raw = data?['ingredients'];
        final List<dynamic> ingredientsList = raw is List
            ? raw
            : (raw is Map ? raw.values.toList() : <dynamic>[]);
        
        print('✅ Ingredientes cargados desde servidor: ${ingredientsList.length} ingredientes');
        print('   Ingredientes: ${ingredientsList.map((ing) => ing is Map ? ing['name'] : ing).toList()}');
        
        // Guardar en cache local
        final prefs = await SharedPreferences.getInstance();
        final authService = AuthService();
        final userId = authService.userId;
        if (userId != null) {
          final ingredientsJson = ingredientsList.map<Map<String, dynamic>>((ing) {
            if (ing is Map) return Map<String, dynamic>.from(ing);
            if (ing is String) return {'name': ing, 'quantity': 1.0, 'unit': 'unidades'};
            return {'name': ing.toString(), 'quantity': 1.0, 'unit': 'unidades'};
          }).toList();
          await prefs.setString('ingredients_$userId', jsonEncode(ingredientsJson));
        }
        
        if (mounted) {
          setState(() {
            _ingredients = ingredientsList.map<Ingredient>((ing) {
              // Handle both old (string) and new (object) formats
              if (ing is String) {
                return Ingredient.fromString(ing);
              } else if (ing is Map<String, dynamic>) {
                return Ingredient.fromJson(ing);
              } else {
                // Fallback: try to convert to Map
                return Ingredient.fromJson(Map<String, dynamic>.from(ing as Map));
              }
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        print('❌ Error loading ingredients: Status ${response.statusCode}');
        print('   Response body: ${response.body}');
        // Intentar cargar desde cache local
        await _loadIngredientsFromCache();
      }
    } catch (e) {
      print('Error loading ingredients: $e');
      // Intentar cargar desde cache local como fallback
      await _loadIngredientsFromCache();
    }
  }
  
  Future<void> _loadIngredientsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final userId = authService.userId;
      
      if (userId != null) {
        final ingredientsJson = prefs.getString('ingredients_$userId');
        if (ingredientsJson != null) {
          final ingredientsList = jsonDecode(ingredientsJson) as List;
          if (mounted) {
            setState(() {
              _ingredients = ingredientsList.map<Ingredient>((ing) {
                if (ing is Map<String, dynamic>) {
                  return Ingredient.fromJson(ing);
                } else if (ing is String) {
                  return Ingredient.fromString(ing);
                } else {
                  return Ingredient.fromJson(Map<String, dynamic>.from(ing as Map));
                }
              }).toList();
              _isLoading = false;
            });
          };
          print('✅ Ingredientes cargados desde cache local: ${_ingredients.length}');
          return;
        }
      }
    } catch (e) {
      print('Error loading ingredients from cache: $e');
    }
    
    // Si no hay cache, mostrar lista vacía
    if (mounted) {
      setState(() {
        _isLoading = false;
        _ingredients = [];
      });
    }
  }

  Future<void> _addIngredient(String ingredientName) async {
    if (ingredientName.trim().isEmpty) return;
    
    final trimmedName = ingredientName.trim().toLowerCase();
    // Normalizar al singular
    final normalizedName = _normalizeToSingular(trimmedName);
    
    // Check if ingredient already exists (comparar tanto singular como plural)
    if (_ingredients.any((ing) {
      final ingName = ing.name.toLowerCase();
      final ingNormalized = _normalizeToSingular(ingName);
      return ingName == trimmedName || 
             ingName == normalizedName ||
             ingNormalized == trimmedName ||
             ingNormalized == normalizedName;
    })) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ingrediente ya está en tu lista')),
      );
      return;
    }

    // Para carnes y pescados, usar gramos por defecto
    // Definir estas variables ANTES del try para que estén disponibles en el catch
    final isMeatOrFish = _isMeatOrFish(normalizedName);
    final double defaultQuantity = isMeatOrFish ? 100.0 : 1.0;
    final String defaultUnit = isMeatOrFish ? 'gramos' : 'unidades';
    
    try {
      final headers = await _authService.getAuthHeaders();
      
      // Usar POST para añadir ingrediente individual (como favoritos)
      final url = await AppConfig.getBackendUrl();
      final encodedName = Uri.encodeComponent(normalizedName);
      final response = await http.post(
        Uri.parse('$url/profile/ingredients/$encodedName?quantity=$defaultQuantity&unit=$defaultUnit'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('La petición tardó demasiado. El backend puede no estar disponible.');
        },
      );
      
      print('📤 POST ingrediente: $trimmedName (normalizado: $normalizedName)');
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Recargar desde el servidor para confirmar que se guardó
        await _loadIngredients();
        
        // Sincronizar con Firebase
        final userId = _authService.userId;
        if (userId != null) {
          final ingredientsJson = _ingredients.map((ing) => ing.toJson()).toList();
          await _firebaseUserService.syncUserIngredients(userId, ingredientsJson);
        }
        
        if (mounted) {
          _ingredientController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ingrediente agregado y guardado correctamente'),
              backgroundColor: AppTheme.primary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Error de autenticación - intentar refrescar token
        print('❌ Error de autenticación al agregar ingrediente');
        final refreshed = await _authService.tryRefreshToken();
        
        if (!refreshed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Tu sesión ha expirado. Por favor, cierra sesión y vuelve a iniciar sesión'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Si se refrescó, reintentar la operación
          print('✅ Token refrescado, reintentando agregar ingrediente...');
          // Por ahora, solo informamos al usuario
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Por favor, intenta agregar el ingrediente nuevamente'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        String errorMessage = 'Error al agregar ingrediente';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding ingredient: $e');
      
      // Fallback: guardar localmente si el backend no está disponible
      if (e is TimeoutException || e.toString().contains('Backend no disponible')) {
        try {
          // Guardar localmente
          final prefs = await SharedPreferences.getInstance();
          final authService = AuthService();
          final userId = authService.userId;
          
          if (userId != null) {
            // Agregar a la lista local (usar nombre normalizado al singular)
            final newIngredient = Ingredient(
              name: normalizedName,
              quantity: defaultQuantity,
              unit: defaultUnit,
            );
            
            final updatedIngredients = [..._ingredients, newIngredient];
            final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();
            
            // Guardar en SharedPreferences
            await prefs.setString('ingredients_$userId', jsonEncode(ingredientsJson));
            
            // Actualizar UI
            if (mounted) {
              setState(() {
                _ingredients = updatedIngredients;
              });
              _ingredientController.clear();
              
              // Sincronizar con Firebase
              final userId = _authService.userId;
              if (userId != null) {
                final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();
                await _firebaseUserService.syncUserIngredients(userId, ingredientsJson);
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Ingrediente guardado localmente (sin conexión)'),
                  backgroundColor: AppTheme.primary,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return;
          }
        } catch (localError) {
          print('Error saving ingredient locally: $localError');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: ${e is TimeoutException ? "Backend no disponible o sin conexión" : e}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _updateIngredient(String oldName, String newName, double? quantity, String? unit) async {
    if (newName.trim().isEmpty) {
      _cancelEdit(oldName);
      return;
    }
    
    final trimmedNew = newName.trim().toLowerCase();
    // Normalizar al singular
    final normalizedNew = _normalizeToSingular(trimmedNew);
    final normalizedOld = _normalizeToSingular(oldName.toLowerCase());
    
    // Check if new name already exists (and it's not the same ingredient)
    if (_ingredients.any((ing) {
      final ingNormalized = _normalizeToSingular(ing.name.toLowerCase());
      return ingNormalized == normalizedNew && ingNormalized != normalizedOld;
    })) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ingrediente ya existe')),
      );
      _cancelEdit(oldName);
      return;
    }

    try {
      // Use a single PUT with the full ingredients list (avoids duplicates/race conditions).
      final updatedIngredients = _ingredients.map((ing) {
        if (ing.name == oldName) {
          return Ingredient(
            name: normalizedNew,
            quantity: quantity ?? ing.quantity,
            unit: unit ?? ing.unit,
          );
        }
        return ing;
      }).toList();

      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();

      final response = await http.put(
        Uri.parse('$url/profile/ingredients'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ingredients': ingredientsJson}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Sync to Supabase storage + local state
        final userId = _authService.userId;
        if (userId != null) {
          await _firebaseUserService.syncUserIngredients(userId, ingredientsJson);
        }

        setState(() {
          _ingredients = updatedIngredients;
          _editingIngredient = null;
        });

        _editingControllers[oldName]?.dispose();
        _editingControllers.remove(oldName);
        _quantityControllers[oldName]?.dispose();
        _quantityControllers.remove(oldName);
        _unitControllers.remove(oldName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ingrediente actualizado correctamente'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      } else {
        String errorMessage = 'Error al actualizar ingrediente';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _cancelEdit(oldName);
      }
    } catch (e) {
      print('Error updating ingredient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      _cancelEdit(oldName);
    }
  }

  Future<void> _removeIngredient(String ingredientName) async {
    try {
      final headers = await _authService.getAuthHeaders();
      // Usar DELETE para eliminar ingrediente individual (como favoritos)
      final url = await AppConfig.getBackendUrl();
      final encodedName = Uri.encodeComponent(ingredientName.toLowerCase());
      final response = await http.delete(
        Uri.parse('$url/profile/ingredients/$encodedName'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Recargar desde el servidor para confirmar que se guardó
        await _loadIngredients();
        
        // Sincronizar con Firebase
        final userId = _authService.userId;
        if (userId != null) {
          final ingredientsJson = _ingredients.map((ing) => ing.toJson()).toList();
          await _firebaseUserService.syncUserIngredients(userId, ingredientsJson);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ingrediente eliminado correctamente'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      } else {
        String errorMessage = 'Error al eliminar ingrediente';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error removing ingredient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startEdit(String ingredientName) {
    setState(() {
      _editingIngredient = ingredientName;
      if (!_editingControllers.containsKey(ingredientName)) {
        final ingredient = _ingredients.firstWhere((ing) => ing.name == ingredientName);
        _editingControllers[ingredientName] = TextEditingController(text: ingredientName);
        _quantityControllers[ingredientName] = TextEditingController(text: ingredient.quantity.toString());
        _unitControllers[ingredientName] = ingredient.unit;
      }
    });
  }

  void _cancelEdit(String ingredientName) {
    setState(() {
      _editingIngredient = null;
    });
    _editingControllers[ingredientName]?.dispose();
    _editingControllers.remove(ingredientName);
    _quantityControllers[ingredientName]?.dispose();
    _quantityControllers.remove(ingredientName);
    _unitControllers.remove(ingredientName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search/Add field with autocomplete
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ingredientController,
                decoration: InputDecoration(
                  hintText: 'Agregar ingredientes (cebolla, pollo, fresas...)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                  suffixIcon: _ingredientController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _ingredientController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) async {
                  if (value.trim().isNotEmpty) {
                    // Buscar en la base de datos primero
                    final foods = await _trackingService.searchFoods(value.trim());
                    if (foods.isNotEmpty) {
                      // Usar el mejor match
                      final bestMatch = foods.first['name'] as String;
                      _addIngredient(bestMatch);
                    } else {
                      // Intentar con plural/singular
                      final trimmedName = value.trim().toLowerCase();
                      final pluralName = PluralHelper.toPlural(trimmedName).toLowerCase();
                      final foods2 = await _trackingService.searchFoods(pluralName);
                      if (foods2.isNotEmpty) {
                        final bestMatch = foods2.first['name'] as String;
                        _addIngredient(bestMatch);
                      } else {
                        // No encontrado
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Ingrediente no encontrado en la base de datos'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  }
                },
              ),
              // Suggestions dropdown
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _suggestions.map((suggestion) {
                      return InkWell(
                        onTap: () {
                          _addIngredient(suggestion);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ingredientController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        return ElevatedButton.icon(
                          onPressed: hasText
                              ? () {
                                  if (_suggestions.isNotEmpty) {
                                    _addIngredient(_suggestions.first);
                                  } else {
                                    _addIngredient(value.text);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Agregar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Ingredients list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ingredients.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tienes ingredientes agregados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega ingredientes que tienes en casa',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ingredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _ingredients[index];
                        final isEditing = _editingIngredient == ingredient.name;
                        
                        if (isEditing) {
                          return _buildEditingTile(ingredient);
                        }
                        
                        return _buildIngredientTile(ingredient);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildIngredientTile(Ingredient ingredient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ingredient.quantity} ${ingredient.unit}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF4CAF50)),
                onPressed: () => _startEdit(ingredient.name),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeIngredient(ingredient.name),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditingTile(Ingredient ingredient) {
    final nameController = _editingControllers[ingredient.name] ?? 
        TextEditingController(text: ingredient.name);
    final quantityController = _quantityControllers[ingredient.name] ?? 
        TextEditingController(text: ingredient.quantity.toString());
    final currentUnit = _unitControllers[ingredient.name] ?? ingredient.unit;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: currentUnit,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unidades', child: Text('unidades')),
                    DropdownMenuItem(value: 'gramos', child: Text('gramos')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _unitControllers[ingredient.name] = value ?? 'unidades';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancelEdit(ingredient.name),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    final quantity = double.tryParse(quantityController.text) ?? ingredient.quantity;
                    final unit = _unitControllers[ingredient.name] ?? ingredient.unit;
                    _updateIngredient(ingredient.name, newName, quantity, unit);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _normalizeToSingular(String ingredient) {
    return IngredientNormalizer.normalize(ingredient);
  }
}

