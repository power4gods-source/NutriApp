import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'add_recipe_screen.dart';

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
  bool _isSavingAiRecipe = false;
  bool _isSharing = false;

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

  Future<void> _saveAiRecipeAsPrivate({required bool editFirst}) async {
    if (_isSavingAiRecipe) return;
    setState(() => _isSavingAiRecipe = true);

    try {
      if (editFirst) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRecipeScreen(
              recipeToEdit: widget.recipe,
              recipeType: 'private',
              forceCreate: true,
            ),
          ),
        );
        return;
      }

      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();

      final recipe = widget.recipe;
      final description = (recipe['description'] ?? '').toString();
      final instructions = recipe['instructions'];
      String instructionsText = '';
      if (instructions is List) {
        instructionsText = instructions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
      } else if (instructions != null) {
        instructionsText = instructions.toString();
      }

      final fullDescription = instructionsText.trim().isEmpty
          ? description
          : '${description.trim()}\n\nInstrucciones:\n$instructionsText';

      final body = {
        'title': recipe['title'] ?? 'Receta sin título',
        'ingredients': (recipe['ingredients'] ?? '').toString(),
        'time_minutes': recipe['time_minutes'] ?? 30,
        'difficulty': recipe['difficulty'] ?? 'Media',
        'tags': (recipe['tags'] ?? '').toString(),
        'image_url': '', // sin foto
        'description': fullDescription,
        'nutrients': (recipe['nutrients'] ?? 'calories 0').toString(),
        'servings': recipe['servings'] ?? 4,
        'calories_per_serving': recipe['calories_per_serving'] ?? 0,
        // user_id comes from JWT in backend
      };

      final resp = await http
          .post(
            Uri.parse('$url/recipes/private'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receta guardada en privadas'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: ${resp.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingAiRecipe = false);
    }
  }

  Future<void> _onTapSaveAi() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar receta'),
        content: const Text('¿Deseas editar la receta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    await _saveAiRecipeAsPrivate(editFirst: choice);
  }

  Future<List<Map<String, dynamic>>> _loadConnections() async {
    final url = await AppConfig.getBackendUrl();
    final headers = await _authService.getAuthHeaders();
    final resp = await http.get(Uri.parse('$url/profile/connections'), headers: headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body);
    final list = data['connections'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _shareRecipe() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final connections = await _loadConnections();
      if (!mounted) return;
      if (connections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes conexiones para compartir aún'), backgroundColor: Colors.orange),
        );
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Compartir con...'),
              ),
              ...connections.map((c) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text((c['username'] ?? c['user_id']).toString()),
                    onTap: () => Navigator.pop(ctx, c),
                  )),
            ],
          ),
        ),
      );
      if (selected == null) return;

      final targetUserId = selected['user_id']?.toString();
      if (targetUserId == null || targetUserId.isEmpty) return;

      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http
          .post(
            Uri.parse('$url/recipes/share'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'target_user_id': targetUserId, 'recipe': widget.recipe}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Receta compartida'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al compartir: ${resp.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al compartir: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
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
    final isAi = (recipe['is_ai_generated'] == true);
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
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.share, color: Colors.white),
                onPressed: _isSharing ? null : _shareRecipe,
              ),
              if (isAi)
                IconButton(
                  icon: _isSavingAiRecipe
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bookmark_add, color: Colors.white),
                  onPressed: _isSavingAiRecipe ? null : _onTapSaveAi,
                )
              else
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

