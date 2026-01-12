import 'package:flutter/material.dart';
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
              const Color(0xFF4CAF50),
              const Color(0xFF4CAF50).withOpacity(0.7),
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
                    Expanded(
                      child: Text(
                        'Resultados de Búsqueda',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Results count and sort
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalResults recetas encontradas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ordenar por:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Coincidencias'),
                            selected: _currentSortBy == 'matches',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _currentSortBy = 'matches');
                                _sortRecipes();
                              }
                            },
                            selectedColor: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Tiempo'),
                            selected: _currentSortBy == 'time',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _currentSortBy = 'time');
                                _sortRecipes();
                              }
                            },
                            selectedColor: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Dificultad'),
                            selected: _currentSortBy == 'difficulty',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _currentSortBy = 'difficulty');
                                _sortRecipes();
                              }
                            },
                            selectedColor: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Results list
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: totalResults == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron recetas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Intenta con otros filtros o ingredientes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
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
                              const Text(
                                'Recetas Generales:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._sortedGeneral.map((recipe) => _buildRecipeCard(recipe)),
                              const SizedBox(height: 24),
                            ],
                            if (_sortedPublic.isNotEmpty) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Recetas Públicas:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: recipe['image_url'] != null && recipe['image_url'].toString().isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recipe['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.restaurant, size: 40, color: Color(0xFF4CAF50));
                  },
                ),
              )
            : const Icon(Icons.restaurant, size: 40, color: Color(0xFF4CAF50)),
        title: Text(
          recipe['title'] ?? 'Sin título',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${recipe['time_minutes'] ?? 0} min • ${recipe['difficulty'] ?? 'N/A'}',
            ),
            if (widget.selectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Coincidencias: ${_countMatchingIngredients(recipe, widget.selectedIngredients.map((ing) => ing.toLowerCase()).toList())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
}


