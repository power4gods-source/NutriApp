import 'package:flutter/material.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  final AuthService _authService = AuthService();
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _recipeService.getFavorites();
      setState(() {
        _favoriteIds = favorites.map((f) => _getRecipeId(f)).toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  String _getRecipeId(dynamic recipe) {
    return recipe['title'] ?? '';
  }

  Future<void> _toggleFavorite() async {
    final recipeId = _getRecipeId(widget.recipe);
    final isFavorite = _favoriteIds.contains(recipeId);

    bool success;
    if (isFavorite) {
      success = await _recipeService.removeFromFavorites(recipeId);
    } else {
      success = await _recipeService.addToFavorites(recipeId);
    }

    if (success) {
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Favorito eliminado' : 'Agregado a favoritos'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final recipeId = _getRecipeId(recipe);
    final isFavorite = _favoriteIds.contains(recipeId);
    final ingredients = (recipe['ingredients'] ?? '').toString().split(',');
    final instructions = recipe['instructions'] as List<dynamic>?;
    final description = recipe['description'] ?? '';
    final ingredientsDetailed = recipe['ingredients_detailed'] as List<dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe['image_url'] != null && recipe['image_url'].toString().isNotEmpty
                  ? Image.network(
                      recipe['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.restaurant, size: 80, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.restaurant, size: 80, color: Colors.grey),
                    ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          
          // Contenido
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      recipe['title'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Info básica
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.access_time,
                          '${recipe['time_minutes'] ?? 0} min',
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.trending_up,
                          recipe['difficulty'] ?? 'N/A',
                        ),
                        if (recipe['servings'] != null) ...[
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            Icons.people,
                            '${recipe['servings']} porciones',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Descripción
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Ingredientes
                    const Text(
                      'Ingredientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ingredientsDetailed != null && ingredientsDetailed.isNotEmpty)
                      ...ingredientsDetailed.map((ing) {
                        final name = ing['name'] ?? '';
                        final quantity = ing['quantity'] ?? '';
                        final unit = ing['unit'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$name: $quantity $unit',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      ...ingredients.map((ing) {
                        if (ing.trim().isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ing.trim(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                    
                    // Instrucciones
                    if (instructions != null && instructions.isNotEmpty) ...[
                      const Text(
                        'Instrucciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...instructions.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final instruction = entry.value.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    '$index',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  instruction,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                    
                    // Información nutricional
                    if (recipe['nutrients'] != null) ...[
                      const Text(
                        'Información Nutricional',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          recipe['nutrients'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

