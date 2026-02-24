import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'dart:convert';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../utils/nutrition_parser.dart';
import '../utils/ingredient_normalizer.dart';
import '../utils/snackbar_utils.dart';
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
  Map<String, dynamic>? _calculatedPerServing;
  Map<String, dynamic>? _calculatedTotal;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadCalculatedNutrition();
  }

  Future<void> _loadCalculatedNutrition() async {
    final ingredients = widget.recipe['ingredients_detailed'] as List?;
    if (ingredients == null || ingredients.isEmpty) return;
    try {
      final result = await _recipeService.calculateRecipeNutrition(widget.recipe);
      if (mounted && result != null) {
        setState(() {
          _calculatedPerServing = result['per_serving'] != null
              ? Map<String, dynamic>.from(result['per_serving'] as Map)
              : null;
          _calculatedTotal = result['total'] != null
              ? Map<String, dynamic>.from(result['total'] as Map)
              : null;
        });
      }
    } catch (e) {
      print('Error loading calculated nutrition: $e');
    }
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
            backgroundColor: AppTheme.primary,
          ),
        );
      } else {
        if (!mounted) return;
        showErrorSnackBar(context, '❌ Error al guardar: ${resp.body}');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, '❌ Error al guardar: $e');
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
          const SnackBar(
            content: Text('No tienes conexiones para compartir aún'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
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
          const SnackBar(content: Text('✅ Receta compartida'), backgroundColor: AppTheme.primary),
        );
      } else {
        showErrorSnackBar(context, '❌ Error al compartir: ${resp.body}');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, '❌ Error al compartir: $e');
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
            backgroundColor: AppTheme.primary,
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

    final recipeImageUrl = recipe['image_url']?.toString().trim() ?? '';
    final imageUrl = recipeImageUrl.isNotEmpty ? recipeImageUrl : AppConfig.backupPhotoUrl;
    final hasValidImage = true; // Siempre hay imagen: receta o backup_photo

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen (si no hay foto válida, barra mínima sin espacio vacío)
          // Para recetas IA: recortar parte superior (alignment bottom) y no dejar espacio vacío
          SliverAppBar(
            expandedHeight: hasValidImage ? 250 : 56,
            pinned: true,
            flexibleSpace: hasValidImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: isAi ? Alignment(0, 1) : Alignment.center,
                      errorBuilder: (context, error, stackTrace) => Image.network(
                        AppConfig.backupPhotoUrl,
                        fit: BoxFit.cover,
                        alignment: isAi ? Alignment(0, 1) : Alignment.center,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF0F4F0)),
                      ),
                    ),
                  )
                : null,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: hasValidImage ? null : AppTheme.cardBackground,
            actions: [
              IconButton(
                icon: _isSharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: hasValidImage ? Colors.white : Colors.black87,
                        ),
                      )
                    : Icon(Icons.share, color: hasValidImage ? Colors.white : Colors.black87),
                onPressed: _isSharing ? null : _shareRecipe,
              ),
              if (isAi)
                IconButton(
                  icon: _isSavingAiRecipe
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: hasValidImage ? Colors.white : Colors.black87,
                          ),
                        )
                      : Icon(Icons.bookmark_add, color: hasValidImage ? Colors.white : Colors.black87),
                  onPressed: _isSavingAiRecipe ? null : _onTapSaveAi,
                )
              else
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? AppTheme.vividRed : (hasValidImage ? Colors.white : Colors.black87),
                  ),
                  onPressed: _toggleFavorite,
                ),
            ],
          ),
          
          // Contenido
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título (siempre visible, color negro)
                    Text(
                      recipe['title'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Info básica
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          Icons.access_time,
                          '${recipe['time_minutes'] ?? 0} min',
                        ),
                        _buildInfoChip(
                          Icons.trending_up,
                          recipe['difficulty'] ?? 'N/A',
                        ),
                        if (recipe['servings'] != null)
                          _buildInfoChip(
                            Icons.people,
                            '${recipe['servings']} porciones',
                          ),
                        // Calorías por ración (prioridad: calculado desde ingredientes, luego parseado)
                        Builder(
                          builder: (context) {
                            final nutrition = _calculatedPerServing != null
                                ? _calculatedPerServing!
                                : NutritionParser.getNutritionPerServing(recipe);
                            var cal = nutrition['calories'];
                            int caloriesPerServing = (cal is num ? (cal as num).round() : double.tryParse(cal?.toString() ?? '0')?.round() ?? 0);
                            if (caloriesPerServing <= 0) {
                              final cps = recipe['calories_per_serving'];
                              caloriesPerServing = cps is int ? cps : (cps is num ? (cps as num).round() : int.tryParse(cps?.toString() ?? '0') ?? 0);
                            }
                            if (caloriesPerServing > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.vividOrange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.vividOrange.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department, size: 16, color: AppTheme.vividOrange),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$caloriesPerServing kcal/ración',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.vividOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
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
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
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
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ingredientsDetailed != null && ingredientsDetailed.isNotEmpty)
                      ...ingredientsDetailed.map((ing) {
                        final name = IngredientNormalizer.toSingular((ing['name'] ?? '').toString());
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
                                  style: const TextStyle(fontSize: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      ...ingredients.map((ing) {
                        final singular = IngredientNormalizer.toSingular(ing.trim());
                        if (singular.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  singular,
                                  style: const TextStyle(fontSize: 14, color: Colors.black),
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
                          color: Colors.black,
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
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                    
                    // Información nutricional (total + por ración)
                    Builder(
                      builder: (context) {
                        final perServing = _calculatedPerServing ?? NutritionParser.getNutritionPerServing(recipe);
                        final totalMap = _calculatedTotal;
                        double _v(Map<String, dynamic> m, String k) =>
                            (m[k] is num ? (m[k] as num).toDouble() : 0.0) ?? 0.0;
                        final sc = _v(perServing, 'calories');
                        final sp = _v(perServing, 'protein');
                        final scarb = _v(perServing, 'carbohydrates');
                        final sf = _v(perServing, 'fat');
                        final sfib = _v(perServing, 'fiber');
                        final hasPerServing = sc > 0 || sp > 0 || scarb > 0 || sf > 0;
                        final hasTotal = totalMap != null && (_v(totalMap, 'calories') > 0 || _v(totalMap, 'protein') > 0);
                        if (!hasPerServing && !hasTotal) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            if (hasTotal) ...[
                              const Text(
                                'Total receta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildNutritionCards(totalMap!),
                              const SizedBox(height: 20),
                            ],
                            const Text(
                              'Por ración',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildNutritionCards(perServing),
                          ],
                        );
                      },
                    ),
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
  
  Widget _buildNutritionCards(Map<String, dynamic> nutrition) {
    double v(String k) => (nutrition[k] is num ? (nutrition[k] as num).toDouble() : 0.0) ?? 0.0;
    final c = v('calories');
    final p = v('protein');
    final carb = v('carbohydrates');
    final f = v('fat');
    final fib = v('fiber');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (c > 0) _buildNutritionCard('Calorías', '${c.round()}', 'kcal', Colors.orange, Icons.local_fire_department),
        if (p > 0) _buildNutritionCard('Proteína', p.toStringAsFixed(1), 'g', Colors.purple, Icons.fitness_center),
        if (carb > 0) _buildNutritionCard('Carbohidratos', carb.toStringAsFixed(1), 'g', Colors.blue, Icons.energy_savings_leaf),
        if (f > 0) _buildNutritionCard('Grasas', f.toStringAsFixed(1), 'g', Colors.red, Icons.water_drop),
        if (fib > 0) _buildNutritionCard('Fibra', fib.toStringAsFixed(1), 'g', Colors.green, Icons.eco),
      ],
    );
  }

  Widget _buildNutritionCard(String label, String value, String unit, Color color, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

