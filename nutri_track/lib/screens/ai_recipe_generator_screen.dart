import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../config/app_config.dart';
import 'recipe_detail_screen.dart';

class AIRecipeGeneratorScreen extends StatefulWidget {
  const AIRecipeGeneratorScreen({super.key});

  @override
  State<AIRecipeGeneratorScreen> createState() => _AIRecipeGeneratorScreenState();
}

class _AIRecipeGeneratorScreenState extends State<AIRecipeGeneratorScreen> {
  final AuthService _authService = AuthService();
  final TrackingService _trackingService = TrackingService();
  
  // Ingredientes cargados automáticamente desde "Alimentación"
  List<String> _userIngredients = [];
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
          _userIngredients = ingredients.map((ing) {
            if (ing is Map) {
              return (ing['name'] ?? '').toString();
            }
            return ing.toString();
          }).where((name) => name.isNotEmpty).toList();
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

  Future<void> _generateRecipes() async {
    if (_userIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega ingredientes en "Alimentación" primero'),
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
      
      // Determinar lógica de ingredientes
      final mustIncludeAll = _userIngredients.length <= 3;
      
      final response = await http.post(
        Uri.parse('$url/ai/generate-recipes'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'meal_type': _mealType ?? 'Comida',
          'ingredients': _userIngredients,
          'num_recipes': 5,
          'must_include_all': mustIncludeAll, // Si hay 3 o menos, deben aparecer todos
          'difficulty': _selectedDifficulty,
          'max_time': _maxTime,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recipes = List<Map<String, dynamic>>.from(data['recipes'] ?? []);
          _isGenerating = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _error = errorData['error'] ?? errorData['detail'] ?? 'Error al generar recetas';
          _isGenerating = false;
        });
      }
    } catch (e) {
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
    final imageUrl = recipe['image_url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToRecipe(recipe),
          child: Stack(
            children: [
              // Imagen
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    );
                  },
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              // Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenido
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Información: duración, dificultad, raciones, kcal/ración
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                              const SizedBox(width: 4),
                              Text(
                                '$time min',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              difficulty,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (recipe['servings'] != null && recipe['servings'] > 0) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 4),
                                Text(
                                  '${recipe['servings']} raciones',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (caloriesPerServing > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$caloriesPerServing kcal/ración',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
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
              // Badge IA
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Generador de Recetas',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isGenerating && _recipes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _generateRecipes,
              tooltip: 'Generar nuevas recetas',
            ),
        ],
      ),
      body: _isLoadingIngredients
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtros (similar a recipe_finder_screen)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredientes cargados automáticamente
                      if (_userIngredients.isNotEmpty) ...[
                        const Text(
                          'Ingredientes disponibles:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _userIngredients.map((ing) {
                            return Chip(
                              label: Text(ing),
                              backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        if (_userIngredients.length <= 3)
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
                                    'Las recetas combinarán estos ingredientes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, size: 20, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Agrega ingredientes en "Alimentación" para generar recetas',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Tipo de comida
                      const Text(
                        'Tipo de comida:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterChip(
                              'Desayuno',
                              _mealType == 'Desayuno',
                              () => setState(() => _mealType = _mealType == 'Desayuno' ? null : 'Desayuno'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterChip(
                              'Comida',
                              _mealType == 'Comida',
                              () => setState(() => _mealType = _mealType == 'Comida' ? null : 'Comida'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterChip(
                              'Cena',
                              _mealType == 'Cena',
                              () => setState(() => _mealType = _mealType == 'Cena' ? null : 'Cena'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Fila de filtros: Dificultad, Tiempo, Dulce/Salado
                      Row(
                        children: [
                          // Dificultad
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDifficulty,
                              decoration: InputDecoration(
                                labelText: 'Dificultad',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(width: 12),
                          // Tiempo máximo
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Tiempo máx (min)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                      // Botón generar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _userIngredients.isEmpty || _isGenerating ? null : _generateRecipes,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(_isGenerating ? 'Generando...' : 'Generar 5 Recetas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Resultados
                Expanded(
                  child: _isGenerating
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Generando recetas con IA...'),
                              SizedBox(height: 8),
                              Text(
                                'Esto puede tardar unos segundos',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _error != null
                          ? Center(
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
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            )
                          : _recipes.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restaurant_menu,
                                          size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Haz clic en "Generar 5 Recetas" para comenzar',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
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
                                          const Icon(Icons.info_outline,
                                              color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${_recipes.length} recetas generadas. Toca una receta para ver los detalles.',
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 13,
                                              ),
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
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50)
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
