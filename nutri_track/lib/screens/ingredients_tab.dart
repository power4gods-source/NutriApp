import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/supabase_user_service.dart';
import '../config/app_config.dart';
import '../utils/ingredient_suggestions.dart';
import 'ai_menu_screen.dart';

class Ingredient {
  final String name;
  final double quantity;
  final String unit; // "unidades" or "gramos"

  Ingredient({
    required this.name,
    this.quantity = 1.0,
    this.unit = "unidades",
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 1.0).toDouble(),
      unit: json['unit'] ?? 'unidades',
    );
  }

  // For backward compatibility with old string format
  factory Ingredient.fromString(String name) {
    return Ingredient(name: name, quantity: 1.0, unit: 'unidades');
  }
}

class IngredientsTab extends StatefulWidget {
  const IngredientsTab({super.key});

  @override
  State<IngredientsTab> createState() => _IngredientsTabState();
}

class _IngredientsTabState extends State<IngredientsTab> {
  final AuthService _authService = AuthService();
  final SupabaseUserService _supabaseUserService = SupabaseUserService();
  final TextEditingController _ingredientController = TextEditingController();
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, String> _unitControllers = {};
  List<Ingredient> _ingredients = [];
  bool _isLoading = true;
  String? _editingIngredient;
  List<String> _suggestions = [];

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
    setState(() => _isLoading = true);
    
    try {
      // 1. Intentar cargar desde backend
      final backendAvailable = await _authService.isBackendAvailable();
      if (backendAvailable) {
        try {
          final headers = await _authService.getAuthHeaders();
          final url = await AppConfig.getBackendUrl();
          final response = await http.get(
            Uri.parse('$url/profile/ingredients'),
            headers: headers,
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final ingredientsList = data['ingredients'] ?? [];
            
            setState(() {
              _ingredients = ingredientsList.map((ing) {
                // Handle both old (string) and new (object) formats
                if (ing is String) {
                  return Ingredient.fromString(ing);
                } else {
                  return Ingredient.fromJson(ing);
                }
              }).toList();
              _isLoading = false;
            });
            
            // Sincronizar con Supabase
            final userId = _authService.userId;
            if (userId != null) {
              _supabaseUserService.syncUserIngredients(userId, ingredientsList).catchError((e) {
                print('⚠️ Error sincronizando ingredientes con Supabase: $e');
              });
            }
            return;
          }
        } catch (e) {
          print('⚠️ Error cargando ingredientes desde backend: $e');
        }
      }
      
      // 2. Fallback: cargar desde Firebase
      final userId = _authService.userId;
      if (userId != null) {
        try {
          final userData = await _supabaseUserService.getUser(userId);
          if (userData != null && userData['ingredients'] != null) {
            final ingredientsList = userData['ingredients'] as List;
            setState(() {
              _ingredients = ingredientsList.map((ing) {
                if (ing is String) {
                  return Ingredient.fromString(ing);
                } else {
                  return Ingredient.fromJson(ing);
                }
              }).toList();
              _isLoading = false;
            });
            print('✅ Ingredientes cargados desde Supabase');
            return;
          }
        } catch (e) {
          print('⚠️ Error cargando ingredientes desde Firebase: $e');
        }
      }
      
      // 3. Fallback: cargar desde local
      final prefs = await SharedPreferences.getInstance();
      final ingredientsJson = prefs.getString('ingredients_$userId');
      if (ingredientsJson != null) {
        final ingredientsList = jsonDecode(ingredientsJson) as List;
        setState(() {
          _ingredients = ingredientsList.map((ing) {
            if (ing is String) {
              return Ingredient.fromString(ing);
            } else {
              return Ingredient.fromJson(ing);
            }
          }).toList();
          _isLoading = false;
        });
        print('✅ Ingredientes cargados desde local');
        return;
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading ingredients: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addIngredient(String ingredientName) async {
    if (ingredientName.trim().isEmpty) return;
    
    final trimmedName = ingredientName.trim().toLowerCase();
    
    // Check if ingredient already exists
    if (_ingredients.any((ing) => ing.name.toLowerCase() == trimmedName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ingrediente ya está en tu lista')),
      );
      return;
    }

    try {
      final newIngredient = Ingredient(name: trimmedName, quantity: 1.0, unit: 'unidades');
      final updatedIngredients = [..._ingredients, newIngredient];
      final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();
      
      // 1. Intentar guardar en backend
      final backendAvailable = await _authService.isBackendAvailable();
      if (backendAvailable) {
        try {
          final headers = await _authService.getAuthHeaders();
          final url = await AppConfig.getBackendUrl();
          final requestBody = {'ingredients': ingredientsJson};
          
          print('📤 Enviando ingrediente al backend: ${jsonEncode(requestBody)}');
          
          final response = await http.put(
            Uri.parse('$url/profile/ingredients'),
            headers: headers,
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 10));
          
          print('📥 Respuesta del backend: ${response.statusCode}');

          if (response.statusCode == 200) {
            setState(() {
              _ingredients = updatedIngredients;
              _suggestions = [];
            });
            _ingredientController.clear();
            
            // Sincronizar con Supabase
            final userId = _authService.userId;
            if (userId != null) {
              _supabaseUserService.syncUserIngredients(userId, ingredientsJson).catchError((e) {
                print('⚠️ Error sincronizando con Firebase: $e');
              });
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Ingrediente agregado'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            }
            return;
          } else {
            print('⚠️ Backend respondió con error: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error al guardar en backend: $e');
        }
      }
      
      // 2. Fallback: guardar en Supabase y local
      final userId = _authService.userId;
      if (userId != null) {
        // Guardar en Firebase
        try {
          await _supabaseUserService.syncUserIngredients(userId, ingredientsJson);
          print('✅ Ingrediente guardado en Firebase');
        } catch (e) {
          print('⚠️ Error guardando en Supabase: $e');
        }
        
        // Guardar localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ingredients_$userId', jsonEncode(ingredientsJson));
        print('✅ Ingrediente guardado localmente');
      }
      
      setState(() {
        _ingredients = updatedIngredients;
        _suggestions = [];
      });
      _ingredientController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(backendAvailable 
              ? '✅ Ingrediente agregado (guardado en Supabase)' 
              : '✅ Ingrediente agregado (modo offline)'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('❌ Error adding ingredient: $e');
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

  Future<void> _updateIngredient(String oldName, String newName, double? quantity, String? unit) async {
    if (newName.trim().isEmpty) {
      _cancelEdit(oldName);
      return;
    }
    
    final trimmedNew = newName.trim().toLowerCase();
    final oldIngredient = _ingredients.firstWhere((ing) => ing.name == oldName);
    
    if (trimmedNew == oldName.toLowerCase() && 
        (quantity == null || quantity == oldIngredient.quantity) &&
        (unit == null || unit == oldIngredient.unit)) {
      _cancelEdit(oldName);
      return;
    }
    
    if (_ingredients.any((ing) => ing.name.toLowerCase() == trimmedNew && ing.name != oldName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ingrediente ya existe')),
      );
      _cancelEdit(oldName);
      return;
    }

    try {
      final updatedIngredients = _ingredients.map((ing) {
        if (ing.name == oldName) {
          return Ingredient(
            name: trimmedNew,
            quantity: quantity ?? ing.quantity,
            unit: unit ?? ing.unit,
          );
        }
        return ing;
      }).toList();
      
      final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();
      
      // 1. Intentar guardar en backend
      final backendAvailable = await _authService.isBackendAvailable();
      if (backendAvailable) {
        try {
          final headers = await _authService.getAuthHeaders();
          final url = await AppConfig.getBackendUrl();
          final requestBody = {'ingredients': ingredientsJson};
          
          final response = await http.put(
            Uri.parse('$url/profile/ingredients'),
            headers: headers,
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Sincronizar con Supabase
            final userId = _authService.userId;
            if (userId != null) {
              _supabaseUserService.syncUserIngredients(userId, ingredientsJson).catchError((e) {
                print('⚠️ Error sincronizando con Firebase: $e');
              });
            }
          } else {
            print('⚠️ Backend respondió con error: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error al actualizar en backend: $e');
        }
      }
      
      // 2. Fallback: guardar en Supabase y local
      final userId = _authService.userId;
      if (userId != null) {
        // Guardar en Firebase
        try {
          await _supabaseUserService.syncUserIngredients(userId, ingredientsJson);
        } catch (e) {
          print('⚠️ Error guardando en Supabase: $e');
        }
        
        // Guardar localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ingredients_$userId', jsonEncode(ingredientsJson));
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
            content: Text('✅ Ingrediente actualizado'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating ingredient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al actualizar ingrediente'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _cancelEdit(oldName);
    }
  }

  Future<void> _updateQuantity(String ingredientName, double quantity, String unit) async {
    final ingredient = _ingredients.firstWhere((ing) => ing.name == ingredientName);
    await _updateIngredient(ingredientName, ingredientName, quantity, unit);
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

  Future<void> _removeIngredient(String ingredientName) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final updatedIngredients = _ingredients.where((ing) => ing.name != ingredientName).toList();
      
      final requestBody = {
        'ingredients': updatedIngredients.map((ing) => ing.toJson()).toList()
      };
      
      final ingredientsJson = updatedIngredients.map((ing) => ing.toJson()).toList();
      
      // 1. Intentar guardar en backend
      final backendAvailable = await _authService.isBackendAvailable();
      if (backendAvailable) {
        try {
          final url = await AppConfig.getBackendUrl();
          final requestBody = {'ingredients': ingredientsJson};
          
          final response = await http.put(
            Uri.parse('$url/profile/ingredients'),
            headers: headers,
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Sincronizar con Supabase
            final userId = _authService.userId;
            if (userId != null) {
              _supabaseUserService.syncUserIngredients(userId, ingredientsJson).catchError((e) {
                print('⚠️ Error sincronizando con Firebase: $e');
              });
            }
          } else {
            print('⚠️ Backend respondió con error: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error al eliminar en backend: $e');
        }
      }
      
      // 2. Fallback: guardar en Supabase y local
      final userId = _authService.userId;
      if (userId != null) {
        // Guardar en Firebase
        try {
          await _supabaseUserService.syncUserIngredients(userId, ingredientsJson);
        } catch (e) {
          print('⚠️ Error guardando en Supabase: $e');
        }
        
        // Guardar localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ingredients_$userId', jsonEncode(ingredientsJson));
      }
      
      setState(() {
        _ingredients = updatedIngredients;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ingrediente eliminado'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('❌ Error removing ingredient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al eliminar ingrediente'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header with AI button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search/Add field with autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ingredientController,
                      decoration: InputDecoration(
                        hintText: 'Agregar ingrediente (ej: pollo, nata, bacon...)',
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
                                  setState(() => _suggestions = []);
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          if (_suggestions.isNotEmpty) {
                            _addIngredient(_suggestions.first);
                          } else {
                            _addIngredient(value);
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
                              color: Colors.black.withOpacity(0.1),
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
                  ],
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
                                      _addIngredient(_ingredientController.text);
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Agregar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: hasText ? 2 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _ingredients.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AIMenuScreen(
                                  ingredients: _ingredients.map((ing) => ing.name).toList(),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.auto_awesome, size: 24),
                    label: const Text(
                      'Generar Menú con IA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                  ),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.restaurant_menu,
                                  size: 64, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No tienes ingredientes agregados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
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
                      )
                    : RefreshIndicator(
                        onRefresh: _loadIngredients,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _ingredients.length,
                          itemBuilder: (context, index) {
                            final ingredient = _ingredients[index];
                            final isEditing = _editingIngredient == ingredient.name;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: isEditing
                                  ? _buildEditingTile(ingredient)
                                  : _buildNormalTile(ingredient),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalTile(Ingredient ingredient) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.shopping_basket,
          color: Color(0xFF4CAF50),
          size: 24,
        ),
      ),
      title: Text(
        ingredient.name[0].toUpperCase() + ingredient.name.substring(1),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '${ingredient.quantity} ${ingredient.unit}',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4CAF50)),
            onPressed: () => _startEdit(ingredient.name),
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeIngredient(ingredient.name),
            tooltip: 'Eliminar',
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
                flex: 2,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentUnit,
                  decoration: InputDecoration(
                    labelText: 'Unidad',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unidades', child: Text('Unidades')),
                    DropdownMenuItem(value: 'gramos', child: Text('Gramos')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _unitControllers[ingredient.name] = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _cancelEdit(ingredient.name),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: () {
                    final quantity = double.tryParse(quantityController.text) ?? ingredient.quantity;
                    final unit = _unitControllers[ingredient.name] ?? ingredient.unit;
                    _updateIngredient(ingredient.name, nameController.text, quantity, unit);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
