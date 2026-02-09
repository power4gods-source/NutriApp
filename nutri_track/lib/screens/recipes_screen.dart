import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_recipe_service.dart';
import '../utils/nutrition_parser.dart';
import '../main.dart';
import 'add_recipe_screen.dart';
import 'recipe_finder_screen.dart';

class RecipesScreen extends StatefulWidget {
  /// Si se especifica, fuerza el filtro y oculta los chips de filtro (ej. 'private' para Mis recetas)
  final String? forceFilter;
  const RecipesScreen({super.key, this.forceFilter});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final RecipeService _recipeService = RecipeService();
  final AuthService _authService = AuthService();
  List<dynamic> _recipes = [];
  Set<String> _favoriteIds = {};
  Set<String> _failedImageIds = {}; // IDs de recetas cuya imagen no cargó
  bool _isLoading = true;
  String? _expandedRecipeId;
  String _selectedFilter = 'general';
  final TextEditingController _nameSearchController = TextEditingController();
  String _nameQuery = '';
  String _sortBy = 'relevance'; // relevance, duration, az

  @override
  void initState() {
    super.initState();
    if (widget.forceFilter != null) {
      _selectedFilter = widget.forceFilter!;
    }
    _nameSearchController.addListener(() {
      setState(() => _nameQuery = _nameSearchController.text.trim().toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredRecipes {
    var list = _recipes.where((r) {
      if (_nameQuery.isEmpty) return true;
      final query = _nameQuery;
      final title = (r['title'] ?? '').toString().toLowerCase();
      final ingList = r['ingredients'];
      String ingStr = '';
      if (ingList is List) {
        ingStr = ingList.map((e) => (e is Map ? e['name'] ?? '' : e).toString().toLowerCase()).join(' ');
      } else if (ingList != null) {
        ingStr = ingList.toString().toLowerCase();
      }
      // Prioridad: coincidencias exactas en título, luego ingredientes
      final titleMatch = title == query || title.contains(query);
      final ingMatch = ingStr.contains(query);
      return titleMatch || ingMatch;
    }).toList();

    // Ordenar: prioridad título, luego ingredientes (coincidencias exactas primero)
    if (_nameQuery.isNotEmpty) {
      list = list.toList()..sort((a, b) {
        final scoreA = _relevanceScore(a);
        final scoreB = _relevanceScore(b);
        return scoreB.compareTo(scoreA);
      });
    } else {
      switch (_sortBy) {
        case 'az':
          list = list.toList()..sort((a, b) => ((a['title'] ?? '').toString().toLowerCase())
              .compareTo((b['title'] ?? '').toString().toLowerCase()));
          break;
        case 'duration':
          list = list.toList()..sort((a, b) {
            final ta = a['time_minutes'] is int ? a['time_minutes'] : (int.tryParse(a['time_minutes']?.toString() ?? '') ?? 999);
            final tb = b['time_minutes'] is int ? b['time_minutes'] : (int.tryParse(b['time_minutes']?.toString() ?? '') ?? 999);
            return (ta as int).compareTo(tb as int);
          });
          break;
        case 'relevance':
        default:
          break;
      }
    }
    return list;
  }

  int _relevanceScore(dynamic r) {
    final title = (r['title'] ?? '').toString().toLowerCase();
    final ingList = r['ingredients'];
    String ingStr = '';
    if (ingList is List) {
      ingStr = ingList.map((e) => (e is Map ? e['name'] ?? '' : e).toString().toLowerCase()).join(' ');
    } else if (ingList != null) {
      ingStr = ingList.toString().toLowerCase();
    }
    // Prioridad: título exacto > título contiene > ingredientes
    if (title == _nameQuery) return 100;
    if (title.contains(_nameQuery)) return 80;
    if (ingStr.contains(_nameQuery)) return 50;
    return 0;
  }

  bool get _isMyRecipesMode => widget.forceFilter == 'private';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Mostrar cache al instante si hay, para que la pestaña no tarde
    final cached = await _recipeService.getCachedRecipes(_selectedFilter);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _recipes = cached;
        _isLoading = false;
      });
      // Actualizar favoritos y recetas en segundo plano
      _loadFavorites().then((_) => _loadRecipes()).then((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    await Future.wait([
      _loadRecipes(),
      _loadFavorites(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  /// Invalida el cache de recetas para forzar recarga
  Future<void> _invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _selectedFilter == 'general' ? 'recipes_general' :
                      _selectedFilter == 'public' ? 'recipes_public' :
                      _selectedFilter == 'private' ? 'recipes_private' : null;
      if (cacheKey != null) {
        await prefs.remove(cacheKey);
        await prefs.remove('${cacheKey}_timestamp');
        print('✅ Cache invalidado para $cacheKey');
      }
    } catch (e) {
      print('Error invalidating cache: $e');
    }
  }

  Future<void> _loadRecipes() async {
    print('📋 _loadRecipes() llamado con filtro: $_selectedFilter');
    // Cache-first: mostrar cache al instante (excepto favoritos que no tiene cache de lista)
    if (_selectedFilter != 'favorites') {
      final cached = await _recipeService.getCachedRecipes(_selectedFilter);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _recipes = cached;
          _isLoading = false;
        });
      }
    }

    List<dynamic> recipes = [];
    try {
      switch (_selectedFilter) {
        case 'general':
          recipes = await _recipeService.getGeneralRecipes();
          print('Loaded ${recipes.length} general recipes');
          break;
        case 'favorites':
          recipes = await _recipeService.getFavorites();
          print('Loaded ${recipes.length} favorite recipes');
          break;
        case 'public':
          recipes = await _recipeService.getPublicRecipes();
          print('Loaded ${recipes.length} public recipes');
          break;
        case 'private':
          print('📋 Cargando recetas privadas...');
          recipes = await _recipeService.getPrivateRecipes();
          print('📋 Loaded ${recipes.length} private recipes');
          break;
        default:
          recipes = await _recipeService.getAllRecipes();
          print('Loaded ${recipes.length} total recipes');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading recipes: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar recetas: $e'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _recipes = recipes;
        _isLoading = false;
        print('Recipes state updated: ${_recipes.length} recipes');
      });
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
    // Usar título como ID único (o puedes usar un hash)
    return recipe['title'] ?? '';
  }

  Future<void> _toggleFavorite(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    final isFavorite = _favoriteIds.contains(recipeId);

    bool success;
    if (isFavorite) {
      success = await _recipeService.removeFromFavorites(recipeId);
    } else {
      success = await _recipeService.addToFavorites(recipeId);
    }

    if (success) {
      // Recargar favoritos para asegurar sincronización
      await _loadFavorites();
      
      // Si estamos en la pestaña de favoritos, recargar recetas también
      if (_selectedFilter == 'favorites') {
        await _loadRecipes();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Favorito eliminado' : 'Agregado a favoritos'),
            backgroundColor: AppTheme.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ${isFavorite ? 'quitar' : 'agregar'} favorito'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }
  }

  void _toggleExpand(String recipeId) {
    setState(() {
      _expandedRecipeId = _expandedRecipeId == recipeId ? null : recipeId;
    });
  }

  Future<void> _editRecipe(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    final recipeType = _selectedFilter;
    
    // Buscar el índice de la receta en la lista correspondiente
    int? recipeIndex;
    
    try {
      List<dynamic> recipesList = [];
      if (recipeType == 'general') {
        recipesList = await _recipeService.getGeneralRecipes();
      } else if (recipeType == 'public') {
        recipesList = await _recipeService.getPublicRecipes();
      } else if (recipeType == 'private') {
        recipesList = await _recipeService.getPrivateRecipes();
      }
      
      for (int i = 0; i < recipesList.length; i++) {
        if (_getRecipeId(recipesList[i]) == recipeId) {
          recipeIndex = i;
          break;
        }
      }
      
      print('🔍 Receta encontrada para editar: índice=$recipeIndex, tipo=$recipeType');
      
      if (recipeIndex != null) {
        // Navegar a la pantalla de edición
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRecipeScreen(
              recipeToEdit: recipe,
              recipeType: recipeType,
              recipeIndex: recipeIndex,
            ),
          ),
        );
        
        // Si se actualizó la receta, recargar datos
        if (result != null && result is Map) {
          if (result['saved'] == true || result['updated'] == true) {
            // Cerrar la vista expandida
            setState(() {
              _expandedRecipeId = null;
            });
            // Invalidar cache y recargar
            await _invalidateCache();
            await _loadData();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo encontrar la receta para editar'),
              backgroundColor: AppTheme.vividRed,
            ),
          );
        }
      }
    } catch (e) {
      print('Error editando receta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al editar la receta: $e'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecipe(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    
    // Confirmar acción
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Receta'),
        content: Text('¿Estás seguro de que quieres eliminar "${recipe['title']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.vividRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Cerrar la vista expandida inmediatamente después de confirmar
    setState(() {
      _expandedRecipeId = null;
    });
    
    // Intentar eliminar usando el backend
    bool success = false;
    
    try {
      if (_selectedFilter == 'general') {
        // Buscar el índice de la receta en generales
        final generalRecipes = await _recipeService.getGeneralRecipes();
        int? recipeIndex;
        for (int i = 0; i < generalRecipes.length; i++) {
          if (_getRecipeId(generalRecipes[i]) == recipeId) {
            recipeIndex = i;
            break;
          }
        }
        
        if (recipeIndex != null) {
          success = await _recipeService.deleteGeneralRecipe(recipeIndex.toString());
        }
      } else if (_selectedFilter == 'public') {
        // Buscar el índice de la receta en públicas
        final publicRecipes = await _recipeService.getPublicRecipes();
        int? recipeIndex;
        for (int i = 0; i < publicRecipes.length; i++) {
          if (_getRecipeId(publicRecipes[i]) == recipeId) {
            recipeIndex = i;
            break;
          }
        }
        
        if (recipeIndex != null) {
          success = await _recipeService.deletePublicRecipe(recipeIndex.toString());
        }
      } else if (_selectedFilter == 'private') {
        // Buscar el índice de la receta en privadas
        final privateRecipes = await _recipeService.getPrivateRecipes();
        int? recipeIndex;
        for (int i = 0; i < privateRecipes.length; i++) {
          if (_getRecipeId(privateRecipes[i]) == recipeId && 
              privateRecipes[i]['user_id'] == _authService.userId) {
            recipeIndex = i;
            break;
          }
        }
        
        if (recipeIndex != null) {
          success = await _recipeService.deletePrivateRecipe(recipeIndex.toString());
        } else {
          print('⚠️ No se encontró la receta privada o no pertenece al usuario');
        }
      }
    } catch (e) {
      print('Error eliminando receta: $e');
    }
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Receta eliminada correctamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Recargar datos
        await _loadData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la receta'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }
  }

  Future<void> _publishRecipe(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    
    // Confirmar acción
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar Receta'),
        content: const Text('¿Estás seguro de que quieres publicar esta receta? Será visible para todos los usuarios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Intentar publicar usando el backend primero, si está disponible
    bool success = false;
    String? finalUserId; // Declarar fuera del try para que esté disponible en todo el método
    
    try {
      // Buscar la receta en el backend por título y user_id para obtener el índice correcto
      final recipeTitle = recipe['title'] as String;
      final authService = AuthService();
      
      // Asegurar que los datos de autenticación estén cargados
      await authService.reloadAuthData();
      var userId = authService.userId;
      
      print('🔍 Buscando receta en backend: título="$recipeTitle", userId="$userId"');
      
      // Si userId es null, intentar obtenerlo desde SharedPreferences
      if (userId == null) {
        print('❌ Error: userId es null. Verificando autenticación...');
        // Intentar recargar desde SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        print('📋 userId desde SharedPreferences: $savedUserId');
        if (savedUserId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No se pudo identificar al usuario. Por favor, inicia sesión nuevamente.'),
                backgroundColor: AppTheme.vividRed,
              ),
            );
          }
          return;
        }
        userId = savedUserId;
      }
      
      finalUserId = userId; // Asignar valor
      
      if (finalUserId != null) {
        // Obtener todas las recetas privadas del backend para encontrar el índice correcto
        final allPrivateRecipes = await _recipeService.getAllPrivateRecipesFromBackend();
        int? recipeIndex;
        
        print('📋 Total recetas privadas en backend: ${allPrivateRecipes.length}');
        
        for (int i = 0; i < allPrivateRecipes.length; i++) {
          final r = allPrivateRecipes[i];
          final rTitle = r['title'] as String? ?? '';
          final rUserId = r['user_id'] as String? ?? '';
          print('📋 Receta $i: título="$rTitle", userId="$rUserId"');
          if (rTitle == recipeTitle && rUserId == finalUserId) {
            recipeIndex = i;
            print('✅ Receta encontrada en backend con índice: $recipeIndex');
            break;
          }
        }

        if (recipeIndex != null) {
          // Intentar con backend usando el índice
          print('📤 Publicando receta con índice: $recipeIndex');
          success = await _recipeService.publishRecipe(recipeIndex.toString());
        
          // Si se publicó desde el backend, también sincronizar con Firebase
          // para mantener la receta en privadas y públicas
          if (success) {
            if (finalUserId != null) {
              // Sincronizar con Firebase manteniendo en privadas y agregando a públicas
              try {
                final firebaseRecipeService = FirebaseRecipeService();
                await firebaseRecipeService.publishPrivateRecipe(recipe, finalUserId);
                print('✅ Receta sincronizada con Firebase después de publicar desde backend');
              } catch (e) {
                print('⚠️ Error sincronizando con Firebase después de publicar: $e');
              }
            }
          }
        } else {
          print('⚠️ Receta no encontrada en backend. Intentando con Firebase...');
        }
      }
    } catch (e) {
      print('Error publicando con backend, intentando Firebase: $e');
    }
    
    // Si el backend no está disponible, usar Firebase directamente
    if (!success) {
      // Usar finalUserId que ya fue obtenido anteriormente
      if (finalUserId != null) {
        // Usar FirebaseRecipeService directamente
        final firebaseRecipeService = FirebaseRecipeService();
        success = await firebaseRecipeService.publishPrivateRecipe(recipe, finalUserId);
      }
    }
    
    if (success) {
      if (mounted) {
        // Invalidar cache de recetas públicas para forzar recarga
        await _invalidateCache();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Receta publicada correctamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Recargar datos para actualizar la lista
        await _loadData();
        // Cerrar la vista expandida
        setState(() {
          _expandedRecipeId = null;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al publicar la receta'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }
  }

  Future<void> _unpublishRecipe(dynamic recipe) async {
    final recipeId = _getRecipeId(recipe);
    
    // Confirmar acción
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar de Públicas'),
        content: const Text('¿Estás seguro de que quieres quitar esta receta de las públicas? La receta se mantendrá en tus recetas privadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.vividOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Intentar despublicar usando el backend primero
    bool success = false;
    
    try {
      // Buscar la receta en públicas del backend
      final recipeTitle = recipe['title'] as String;
      final authService = AuthService();
      final userId = authService.userId;
      
      if (userId != null) {
        // Obtener todas las recetas públicas del backend para encontrar el índice correcto
        final allPublicRecipes = await _recipeService.getPublicRecipes();
        int? recipeIndex;
        
        for (int i = 0; i < allPublicRecipes.length; i++) {
          final r = allPublicRecipes[i];
          final rTitle = r['title'] as String? ?? '';
          final rUserId = r['user_id'] as String? ?? '';
          if (rTitle == recipeTitle && rUserId == userId) {
            recipeIndex = i;
            break;
          }
        }

        if (recipeIndex != null) {
          success = await _recipeService.unpublishRecipe(recipeIndex.toString());
        }
      }
    } catch (e) {
      print('Error despublicando receta: $e');
    }
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Receta quitada de públicas correctamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Recargar datos para actualizar la lista
        await _loadData();
        // Cerrar la vista expandida
        setState(() {
          _expandedRecipeId = null;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al quitar la receta de públicas'),
            backgroundColor: AppTheme.vividRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _expandedRecipeId != null
          ? null // Ocultar AppBar cuando hay receta expandida
          : AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (_isMyRecipesMode && Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              final mainNavState = MainNavigationScreen.of(context);
              if (mainNavState != null) {
                mainNavState.setCurrentIndex(2); // Inicio
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          },
        ),
        title: Text(
          _isMyRecipesMode ? 'Mis recetas' : 'Recetas',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.onSurface),
            tooltip: 'Buscador de recetas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecipeFinderScreen()),
              );
            },
          ),
        ],
      ),
      body: _expandedRecipeId != null
          ? Stack(
              children: [
                // Overlay oscuro
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedRecipeId = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                // Tarjeta expandida ocupando toda la pantalla
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () {}, // Prevenir cierre al tocar la tarjeta
                      child: _buildExpandedCard(
                        _filteredRecipes.firstWhere(
                          (r) => _getRecipeId(r) == _expandedRecipeId,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // Buscador por texto + filtros (ocultos en modo Mis recetas)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _nameSearchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar recetas...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppTheme.fillLight(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                if (!_isMyRecipesMode)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      children: [
                        _buildFilterChip('Generales', 'general'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Favoritas', 'favorites'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Privadas', 'private'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Publicadas', 'public'),
                      ],
                    ),
                  ),
                // Ordenar + resultados
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredRecipes.length} recetas',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          Text('Ordenar: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 'relevance', child: Text('Relevancia')),
                                DropdownMenuItem(value: 'duration', child: Text('Duración')),
                                DropdownMenuItem(value: 'az', child: Text('A-Z')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _sortBy = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Recipes list
                Expanded(
                  child: Stack(
                    children: [
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredRecipes.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restaurant_menu,
                                          size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay recetas disponibles',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredRecipes.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _filteredRecipes[index];
                                    return _buildRecipeCard(recipe, false);
                                  },
                                ),
                      // Botón flotante para añadir receta (solo en privadas)
                      if (_selectedFilter == 'private')
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: FloatingActionButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddRecipeScreen(),
                                ),
                              );
                              
                              // Si se guardó una receta, cambiar a filtro private y recargar
                              if (result != null && result is Map) {
                                if (result['saved'] == true) {
                                  setState(() {
                                    _selectedFilter = result['filter'] ?? 'private';
                                    _expandedRecipeId = null; // Cerrar cualquier receta expandida
                                  });
                                  // Recargar favoritos primero (la receta se agregó automáticamente)
                                  await _loadFavorites();
                                  // Esperar más tiempo para que el backend procese y guarde el archivo
                                  print('⏳ Esperando 2 segundos para que el backend guarde el archivo...');
                                  await Future.delayed(const Duration(milliseconds: 2000));
                                  // Invalidar cache y recargar
                                  await _invalidateCache();
                                  print('🔄 Primera recarga de recetas privadas...');
                                  await _loadRecipes();
                                  // Recargar una vez más después de un delay para asegurar que se cargue desde backend
                                  print('⏳ Esperando 3 segundos más...');
                                  await Future.delayed(const Duration(milliseconds: 3000));
                                  await _invalidateCache();
                                  print('🔄 Segunda recarga de recetas privadas...');
                                  await _loadRecipes();
                                  // Una última recarga para asegurar
                                  print('⏳ Esperando 2 segundos más...');
                                  await Future.delayed(const Duration(milliseconds: 2000));
                                  await _invalidateCache();
                                  print('🔄 Tercera recarga de recetas privadas...');
                                  await _loadRecipes();
                                  print('✅ Finalizada la recarga de recetas privadas');
                                } else {
                                  // Solo recargar si no se guardó pero hubo cambios
                                  await _invalidateCache();
                                  await _loadRecipes();
                                }
                              } else if (result == true) {
                                // Compatibilidad con código anterior
                                setState(() {
                                  _selectedFilter = 'private';
                                  _expandedRecipeId = null;
                                });
                                await _loadFavorites();
                                await Future.delayed(const Duration(milliseconds: 2000));
                                await _invalidateCache();
                                await _loadRecipes();
                                await Future.delayed(const Duration(milliseconds: 3000));
                                await _invalidateCache();
                                await _loadRecipes();
                                await Future.delayed(const Duration(milliseconds: 2000));
                                await _invalidateCache();
                                await _loadRecipes();
                              }
                            },
                            backgroundColor: AppTheme.primary,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Builder(
      builder: (context) {
        final textColor = isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface;
        return FilterChip(
          label: Text(label, style: TextStyle(color: textColor)),
          selected: isSelected,
          onSelected: (selected) async {
            if (selected) {
              await _invalidateCache();
              setState(() {
                _selectedFilter = value;
                _expandedRecipeId = null;
              });
              await _loadRecipes();
            }
          },
          selectedColor: AppTheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          labelStyle: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, bool isExpanded) {
    final recipeId = _getRecipeId(recipe);
    final isFavorite = _favoriteIds.contains(recipeId);
    final ingredients = (recipe['ingredients'] ?? '').toString().split(',');
    final description = recipe['description'] ?? '';

    return GestureDetector(
      onTap: () {
        // Si es favorita, abrir en primer plano automáticamente
        if (isFavorite) {
          _toggleExpand(recipeId);
        } else {
          _toggleExpand(recipeId);
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Builder(
          builder: (context) {
            final imageUrl = recipe['image_url']?.toString().trim() ?? '';
            final hasValidImage = imageUrl.isNotEmpty && !_failedImageIds.contains(recipeId);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasValidImage) ...[
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
                      if (_selectedFilter == 'private' || _isMyRecipesMode)
                        Positioned(
                          top: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              (recipe['is_public'] ?? false) ? Icons.visibility : Icons.visibility_off,
                              color: (recipe['is_public'] ?? false) ? AppTheme.primary : Colors.grey[600],
                              size: 22,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 12, right: 12,
                        child: GestureDetector(
                          onTap: () => _toggleFavorite(recipe),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? AppTheme.vividRed : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
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
                        if (_selectedFilter == 'private' || _isMyRecipesMode)
                          GestureDetector(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                (recipe['is_public'] ?? false) ? Icons.visibility : Icons.visibility_off,
                                color: (recipe['is_public'] ?? false) ? AppTheme.primary : Colors.grey[600],
                                size: 22,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => _toggleFavorite(recipe),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? AppTheme.vividRed : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Content
                Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasValidImage) ...[
                    Text(
                      recipe['title'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Time, difficulty, servings, and calories per serving
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['time_minutes'] ?? 0} min',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            recipe['difficulty'] ?? 'N/A',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      if (recipe['servings'] != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe['servings']} porciones',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                      // Calorías por ración
                      Builder(
                        builder: (context) {
                          final nutrition = NutritionParser.getNutritionPerServing(recipe);
                          final fromParser = nutrition['calories']?.round();
                          final fromRecipe = recipe['calories_per_serving'];
                          final int caloriesPerServing = fromParser ??
                              (fromRecipe is num ? fromRecipe.round() : (int.tryParse(fromRecipe?.toString() ?? '') ?? 0));
                          if (caloriesPerServing > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  // Ingredients (collapsed view)
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
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  ),
  );
  }

  Widget _buildExpandedCard(Map<String, dynamic> recipe) {
    final recipeId = _getRecipeId(recipe);
    final isFavorite = _favoriteIds.contains(recipeId);
    final ingredients = (recipe['ingredients'] ?? '').toString().split(',');
    final instructions = recipe['instructions'] as List<dynamic>?;
    final description = recipe['description'] ?? '';
    final ingredientsDetailed = recipe['ingredients_detailed'] as List<dynamic>?;
    final imageUrl = recipe['image_url']?.toString().trim() ?? '';
    final hasValidImage = imageUrl.isNotEmpty && !_failedImageIds.contains(recipeId);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasValidImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      imageUrl,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: 250,
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
                  // Close button (arriba a la izquierda)
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedRecipeId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 28, color: Colors.black87),
                    ),
                  ),
                ),
                // Favorite button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(recipe),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppTheme.vividRed : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _expandedRecipeId = null),
                      child: const Icon(Icons.close, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe['title'] ?? 'Sin título',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleFavorite(recipe),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppTheme.vividRed : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            // Content (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            recipe['title'] ?? 'Sin título',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Action buttons row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Publish button (for private recipes or favorites that are private)
                            if ((_selectedFilter == 'private' || _selectedFilter == 'favorites') && 
                                !(recipe['is_public'] ?? false) &&
                                recipe['user_id'] == _authService.userId)
                              ElevatedButton.icon(
                                onPressed: () => _publishRecipe(recipe),
                                icon: const Icon(Icons.public, size: 18),
                                label: const Text('Publicar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            // Unpublish button (for public recipes that belong to the user)
                            if ((_selectedFilter == 'public' || _selectedFilter == 'favorites') && 
                                (recipe['is_public'] ?? false) &&
                                recipe['user_id'] == _authService.userId)
                              ElevatedButton.icon(
                                onPressed: () => _unpublishRecipe(recipe),
                                icon: const Icon(Icons.public_off, size: 18),
                                label: const Text('Quitar de públicas'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.vividOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            // Edit button
                            // - Admin puede editar general/public
                            // - Usuarios pueden editar sus propias recetas privadas
                            if ((_authService.isAdmin && 
                                 (_selectedFilter == 'general' || _selectedFilter == 'public')) ||
                                (_selectedFilter == 'private' && 
                                 recipe['user_id'] == _authService.userId))
                              IconButton(
                                onPressed: () => _editRecipe(recipe),
                                icon: const Icon(Icons.edit, color: AppTheme.primary),
                                tooltip: 'Editar receta',
                              ),
                            // Delete button
                            // - Admin puede eliminar general/public
                            // - Usuarios pueden eliminar sus propias recetas privadas
                            if ((_authService.isAdmin && 
                                 (_selectedFilter == 'general' || _selectedFilter == 'public')) ||
                                (_selectedFilter == 'private' && 
                                 recipe['user_id'] == _authService.userId))
                              IconButton(
                                onPressed: () => _deleteRecipe(recipe),
                                icon: Icon(Icons.delete, color: AppTheme.vividRed),
                                tooltip: 'Eliminar receta',
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Time, difficulty, servings, and calories per serving
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe['time_minutes'] ?? 0} min',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              recipe['difficulty'] ?? 'N/A',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                        if (recipe['servings'] != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe['servings']} porciones',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                        // Calorías por ración
                        Builder(
                          builder: (context) {
                            final nutrition = NutritionParser.getNutritionPerServing(recipe);
                            final fromParser = nutrition['calories']?.round();
                            final fromRecipe = recipe['calories_per_serving'];
                            final int caloriesPerServing = fromParser ??
                                (fromRecipe is num ? fromRecipe.round() : (int.tryParse(fromRecipe?.toString() ?? '') ?? 0));
                            if (caloriesPerServing > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    // Información nutricional completa (si está disponible)
                    Builder(
                      builder: (context) {
                        final nutrition = NutritionParser.getNutritionPerServing(recipe);
                        final hasNutrition = nutrition['protein']! > 0 || 
                                           nutrition['carbohydrates']! > 0 || 
                                           nutrition['fat']! > 0;
                        if (hasNutrition) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              const Text(
                                'Información nutricional (por ración)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (nutrition['calories']! > 0)
                                    _buildNutritionChip(
                                      'Calorías',
                                      '${nutrition['calories']!.round()}',
                                      AppTheme.vividOrange,
                                    ),
                                  if (nutrition['protein']! > 0)
                                    _buildNutritionChip(
                                      'Proteína',
                                      '${nutrition['protein']!.toStringAsFixed(1)}g',
                                      Colors.purple,
                                    ),
                                  if (nutrition['carbohydrates']! > 0)
                                    _buildNutritionChip(
                                      'Carbohidratos',
                                      '${nutrition['carbohydrates']!.toStringAsFixed(1)}g',
                                      Colors.blue,
                                    ),
                                  if (nutrition['fat']! > 0)
                                    _buildNutritionChip(
                                      'Grasas',
                                      '${nutrition['fat']!.toStringAsFixed(1)}g',
                                      AppTheme.vividRed,
                                    ),
                                ],
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // Description
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Descripción',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[700], fontSize: 15),
                      ),
                    ],
                    // Ingredients
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Ingredientes',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ingredientsDetailed != null && ingredientsDetailed.isNotEmpty)
                      ...ingredientsDetailed.map((ing) {
                        final name = ing['name'] ?? '';
                        final quantity = ing['quantity'] ?? 0;
                        final unit = ing['unit'] ?? '';
                        final notes = ing['notes'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 18)),
                              Expanded(
                                child: Text(
                                  '$name: $quantity $unit${notes.isNotEmpty ? ' ($notes)' : ''}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      ...ingredients.map((ing) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 18)),
                              Expanded(
                                child: Text(
                                  ing.trim(),
                                  style: TextStyle(color: Colors.grey[700], fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    // Instructions
                    if (instructions != null && instructions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Instrucciones',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...instructions.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final instruction = entry.value.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$index',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  instruction,
                                  style: TextStyle(color: Colors.grey[700], fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    // Nutrients
                    if (recipe['nutrients'] != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Información Nutricional',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe['nutrients'].toString(),
                        style: TextStyle(color: Colors.grey[700], fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNutritionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
