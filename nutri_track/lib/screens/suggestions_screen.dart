import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/recipe_service.dart';
import 'ai_menu_screen.dart';

class SuggestionsScreen extends StatefulWidget {
  final List<String> ingredients;
  final List<String> mealTypes;

  const SuggestionsScreen({
    super.key,
    required this.ingredients,
    required this.mealTypes,
  });

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final AuthService _authService = AuthService();
  final RecipeService _recipeService = RecipeService();
  
  List<dynamic> _databaseSuggestions = [];
  List<dynamic> _aiSuggestions = [];
  bool _isLoading = true;
  bool _isGeneratingAI = false;
  bool _showAISuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadDatabaseSuggestions();
  }

  Future<void> _loadDatabaseSuggestions() async {
    setState(() => _isLoading = true);
    
    try {
      // Obtener todas las recetas generales
      final allRecipes = await _recipeService.getGeneralRecipes();
      
      // Filtrar recetas que contengan alguno de los ingredientes disponibles
      List<dynamic> filteredRecipes = [];
      for (var recipe in allRecipes) {
        final recipeIngredients = recipe['ingredients'] ?? [];
        final recipeIngredientNames = recipeIngredients.map((ing) {
          if (ing is Map) return (ing['name'] ?? '').toString().toLowerCase();
          return ing.toString().toLowerCase();
        }).toList();
        
        // Verificar si algún ingrediente del usuario está en la receta
        final hasMatchingIngredient = widget.ingredients.any((userIng) {
          final userIngLower = userIng.toLowerCase();
          return recipeIngredientNames.any((recipeIng) => 
            recipeIng.contains(userIngLower) || userIngLower.contains(recipeIng)
          );
        });
        
        if (hasMatchingIngredient) {
          filteredRecipes.add(recipe);
        }
      }
      
      setState(() {
        _databaseSuggestions = filteredRecipes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading database suggestions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAISuggestions() async {
    setState(() => _isGeneratingAI = true);
    
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('http://localhost:8000/ai/generate-menu'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ingredients': widget.ingredients,
          'meal_types': widget.mealTypes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _aiSuggestions = data['menu'] as List? ?? [];
          _showAISuggestions = true;
          _isGeneratingAI = false;
        });
      } else {
        setState(() => _isGeneratingAI = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al generar menú con IA'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isGeneratingAI = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sugerencias',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ingredientes utilizados
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        const Text(
                          'Ingredientes disponibles:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.ingredients.map((ing) {
                            return Chip(
                              label: Text(ing),
                              backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tipos de comida: ${widget.mealTypes.join(", ")}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón para generar con IA
                  if (!_showAISuggestions)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingAI ? null : _generateAISuggestions,
                        icon: _isGeneratingAI
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGeneratingAI ? 'Generando...' : 'Generar con IA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  
                  // Menú generado por IA
                  if (_showAISuggestions && _aiSuggestions.isNotEmpty) ...[
                    const Text(
                      'Menú generado por IA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._aiSuggestions.take(3).map((suggestion) {
                      return _buildSuggestionCard(suggestion, isAI: true);
                    }).toList(),
                    const SizedBox(height: 32),
                  ],
                  
                  // Nuestras sugerencias (base de datos)
                  const Text(
                    'Nuestras sugerencias',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_databaseSuggestions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No hay sugerencias disponibles',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._databaseSuggestions.map((recipe) {
                      return _buildSuggestionCard(recipe, isAI: false);
                    }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSuggestionCard(dynamic suggestion, {required bool isAI}) {
    final title = suggestion['title'] ?? suggestion['name'] ?? 'Sin título';
    final description = suggestion['description'] ?? '';
    final time = suggestion['time_minutes'] ?? 0;
    final difficulty = suggestion['difficulty'] ?? 'N/A';
    final imageUrl = suggestion['image_url'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 64),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAI)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Generado por IA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$time min',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      difficulty,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

