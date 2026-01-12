import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';

class AddConsumptionScreen extends StatefulWidget {
  const AddConsumptionScreen({super.key});

  @override
  State<AddConsumptionScreen> createState() => _AddConsumptionScreenState();
}

class _AddConsumptionScreenState extends State<AddConsumptionScreen> {
  final AuthService _authService = AuthService();
  final TrackingService _trackingService = TrackingService();
  final TextEditingController _foodSearchController = TextEditingController();
  
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedMealType = 'comida';
  List<Map<String, dynamic>> _selectedFoods = [];
  List<Map<String, dynamic>> _foodSuggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _foodSearchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _foodSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _foodSearchController.text.trim();
    if (query.length >= 2) {
      _searchFoods(query);
    } else {
      setState(() => _foodSuggestions = []);
    }
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
            });
          });
          _foodSearchController.clear();
          setState(() {
            _foodSuggestions = [];
          });
          print('✅ Alimento añadido correctamente: ${foundFood?['name'] ?? foodName} (ID: $foodId)');
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

    // Validar que todos los alimentos tengan food_id válido
    final invalidFoods = _selectedFoods.where((food) {
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
      
      // Verificar de nuevo
      final stillInvalid = _selectedFoods.where((food) {
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
      
      // Verificar que el food_id no esté vacío
      if (foodId.toString().isEmpty) {
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
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
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
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                        const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
            
            // Food search
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buscar Alimento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _foodSearchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar alimento...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_foodSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: _foodSuggestions.map((food) {
                          // Asegurar que el food_id esté presente
                          final foodId = food['food_id'] ?? food['id'] ?? food['_id'] ?? '';
                          final foodName = food['name'] ?? '';
                          
                          print('📋 Sugerencia: $foodName (ID: $foodId)');
                          
                          return ListTile(
                            title: Text(foodName),
                            subtitle: Text('${food['nutrition_per_100g']?['calories'] ?? 0} kcal/100g'),
                            trailing: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                            onTap: () {
                              // Si no tiene food_id, intentar buscarlo
                              if (foodId.toString().isEmpty) {
                                print('⚠️ Alimento sin ID, buscando por nombre: $foodName');
                                _findFoodIdByName(foodName, 100.0, 'gramos');
                              } else {
                                print('✅ Alimento con ID válido, mostrando diálogo: $foodName (ID: $foodId)');
                                _showAddFoodDialog(food);
                              }
                            },
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
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${food['quantity']} ${food['unit']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeFood(index),
          ),
        ],
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
        title: Text('Agregar ${food['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedUnit,
              decoration: const InputDecoration(
                labelText: 'Unidad',
                border: OutlineInputBorder(),
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 100.0;
              _addFood(food, quantity: quantity, unit: selectedUnit);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

