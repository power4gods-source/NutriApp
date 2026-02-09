import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/recipe_service.dart';
import '../utils/nutrition_parser.dart';
import 'recipe_detail_screen.dart';

/// Favoritos: mismas tarjetas que en Recetas > Favoritas.
/// Se pueden editar (quitar favorito) dentro de cada receta al abrirla.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final RecipeService _recipeService = RecipeService();
  List<dynamic> _favorites = [];
  Set<String> _failedImageIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await _recipeService.getFavorites();
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getRecipeId(dynamic recipe) {
    return (recipe['title'] ?? recipe['id'] ?? '').toString();
  }

  Future<void> _removeFavorite(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    final success = await _recipeService.removeFromFavorites(recipeId);
    if (success && mounted) {
      _loadFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eliminado de favoritos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Favoritos',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes recetas favoritas',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega recetas a favoritos desde Recetas para verlas aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final recipe = _favorites[index];
                      return _buildRecipeCard(recipe);
                    },
                  ),
                ),
    );
  }

  /// Misma tarjeta que en Recetas > Favoritas
  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final recipeId = _getRecipeId(recipe);
    final ingredients = (recipe['ingredients'] ?? '').toString().split(',');
    final description = recipe['description'] ?? '';
    final imageUrl = recipe['image_url']?.toString().trim() ?? '';
    final hasValidImage = imageUrl.isNotEmpty && !_failedImageIds.contains(recipeId);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipe: recipe),
          ),
        );
        _loadFavorites();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasValidImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _failedImageIds.add(recipeId));
                          });
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(recipe),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: AppTheme.vividRed,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe['title'] ?? 'Sin título',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeFavorite(recipe),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.favorite, color: AppTheme.vividRed, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasValidImage)
                    Text(
                      recipe['title'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['time_minutes'] ?? 0} min',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            recipe['difficulty'] ?? 'N/A',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      if (recipe['servings'] != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people,
                                size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe['servings']} porciones',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                      Builder(
                        builder: (context) {
                          final nutrition =
                              NutritionParser.getNutritionPerServing(recipe);
                          final fromParser = nutrition['calories']?.round();
                          final fromRecipe = recipe['calories_per_serving'];
                          final int caloriesPerServing = fromParser ??
                              (fromRecipe is num
                                  ? fromRecipe.round()
                                  : (int.tryParse(
                                          fromRecipe?.toString() ?? '') ??
                                      0));
                          if (caloriesPerServing > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.vividOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$caloriesPerServing kcal/ración',
                                style: const TextStyle(
                                  color: AppTheme.vividOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingredientes:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ingredients.take(5).join(', ') +
                        (ingredients.length > 5 ? '...' : ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
