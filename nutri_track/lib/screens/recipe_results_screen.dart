import 'dart:ui';

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'recipe_detail_screen.dart';

class RecipeResultsScreen extends StatefulWidget {
  final List<dynamic> generalRecipes;
  final List<dynamic> publicRecipes;
  final String? query;
  final List<String> selectedIngredients;
  final String sortBy;

  const RecipeResultsScreen({
    super.key,
    required this.generalRecipes,
    required this.publicRecipes,
    this.query,
    this.selectedIngredients = const [],
    this.sortBy = 'matches',
  });

  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  String _currentSortBy = 'matches';
  List<dynamic> _sortedGeneral = [];
  List<dynamic> _sortedPublic = [];

  @override
  void initState() {
    super.initState();
    _currentSortBy = widget.sortBy;
    _sortedGeneral = List.from(widget.generalRecipes);
    _sortedPublic = List.from(widget.publicRecipes);
    _sortRecipes();
  }

  void _sortRecipes() {
    setState(() {
      switch (_currentSortBy) {
        case 'time':
          _sortedGeneral.sort((a, b) {
            final timeA = (a['time_minutes'] ?? 999) as int;
            final timeB = (b['time_minutes'] ?? 999) as int;
            return timeA.compareTo(timeB);
          });
          _sortedPublic.sort((a, b) {
            final timeA = (a['time_minutes'] ?? 999) as int;
            final timeB = (b['time_minutes'] ?? 999) as int;
            return timeA.compareTo(timeB);
          });
          break;
        case 'difficulty':
          final difficultyOrder = {'fácil': 1, 'media': 2, 'difícil': 3};
          _sortedGeneral.sort((a, b) {
            final diffA = difficultyOrder[(a['difficulty'] ?? '').toString().toLowerCase()] ?? 4;
            final diffB = difficultyOrder[(b['difficulty'] ?? '').toString().toLowerCase()] ?? 4;
            return diffA.compareTo(diffB);
          });
          _sortedPublic.sort((a, b) {
            final diffA = difficultyOrder[(a['difficulty'] ?? '').toString().toLowerCase()] ?? 4;
            final diffB = difficultyOrder[(b['difficulty'] ?? '').toString().toLowerCase()] ?? 4;
            return diffA.compareTo(diffB);
          });
          break;
        default: // 'matches'
          final query = (widget.query ?? '').toLowerCase();
          final selectedLower = widget.selectedIngredients.map((ing) => ing.toLowerCase()).toList();
          _sortedGeneral = _sortByMatches(_sortedGeneral, query, selectedLower);
          _sortedPublic = _sortByMatches(_sortedPublic, query, selectedLower);
          break;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final totalResults = _sortedGeneral.length + _sortedPublic.length;
    
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
              // Header: back button (shifted left) + sort icon (right)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, color: Colors.white, size: 28),
                      onSelected: (value) {
                        setState(() => _currentSortBy = value);
                        _sortRecipes();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'matches',
                          child: Row(
                            children: [
                              if (_currentSortBy == 'matches') const Icon(Icons.check, color: AppTheme.primary, size: 20),
                              if (_currentSortBy == 'matches') const SizedBox(width: 8),
                              const Text('Coincidencias'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'time',
                          child: Row(
                            children: [
                              if (_currentSortBy == 'time') const Icon(Icons.check, color: AppTheme.primary, size: 20),
                              if (_currentSortBy == 'time') const SizedBox(width: 8),
                              const Text('Tiempo'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'difficulty',
                          child: Row(
                            children: [
                              if (_currentSortBy == 'difficulty') const Icon(Icons.check, color: AppTheme.primary, size: 20),
                              if (_currentSortBy == 'difficulty') const SizedBox(width: 8),
                              const Text('Dificultad'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Results list
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: totalResults == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 60, color: Colors.white70),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron recetas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Intenta con otros filtros o ingredientes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_sortedGeneral.isNotEmpty) ...[
                              Text(
                                'Recetas Generales:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._sortedGeneral.map((recipe) => _buildRecipeCard(recipe)),
                              const SizedBox(height: 24),
                            ],
                            if (_sortedPublic.isNotEmpty) ...[
                              Divider(color: Colors.white38),
                              const SizedBox(height: 8),
                              Text(
                                'Recetas Públicas:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._sortedPublic.map((recipe) => _buildRecipeCard(recipe)),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final imageUrl = recipe['image_url']?.toString().trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final displayImageUrl = hasImage ? imageUrl! : AppConfig.backupPhotoFirebaseUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: hasImage
                ? Image.network(
                    displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildDefaultRecipeImage(),
                  )
                : _buildDefaultRecipeImage(),
          ),
        ),
        title: Text(
          recipe['title'] ?? 'Sin título',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${recipe['time_minutes'] ?? 0} min • ${recipe['difficulty'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.black54),
            ),
            if (widget.selectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Coincidencias: ${_countMatchingIngredients(recipe, widget.selectedIngredients.map((ing) => ing.toLowerCase()).toList())}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultRecipeImage() {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
      child: Opacity(
        opacity: 0.92,
        child: Image.network(
          AppConfig.backupPhotoFirebaseUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              color: AppTheme.primary.withOpacity(0.2),
              child: const Icon(Icons.restaurant, size: 32, color: Color(0xFF4CAF50)),
            );
          },
        ),
      ),
    );
  }
}


