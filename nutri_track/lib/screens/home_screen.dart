import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/search_dialog.dart';
import '../widgets/app_drawer.dart';
import '../services/recipe_service.dart';
import '../services/tracking_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../main.dart';
import 'recipe_detail_screen.dart';
import 'tracking_screen.dart';
import 'ingredients_screen.dart';
import 'shopping_list_screen.dart';
import 'add_consumption_screen.dart';
import 'recipes_screen.dart';
import 'recipe_finder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecipeService _recipeService = RecipeService();
  final TrackingService _trackingService = TrackingService();
  final AuthService _authService = AuthService();
  
  Map<String, dynamic> _dailyStats = {};
  Map<String, dynamic> _weeklyStats = {};
  Map<String, dynamic> _monthlyStats = {};
  List<dynamic> _trendingRecipes = [];
  List<dynamic> _quickRecipes = [];
  List<dynamic> _allQuickRecipes = []; // Todas las recetas rápidas disponibles
  List<String> _userIngredients = [];
  bool _isLoading = true;
  bool _isLoadingMoreQuickRecipes = false;
  final ScrollController _quickRecipesScrollController = ScrollController();
  static const int _quickRecipesPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quickRecipesScrollController.addListener(_onQuickRecipesScroll);
  }

  @override
  void dispose() {
    _quickRecipesScrollController.dispose();
    super.dispose();
  }

  void _onQuickRecipesScroll() {
    if (_quickRecipesScrollController.position.pixels >=
        _quickRecipesScrollController.position.maxScrollExtent - 200) {
      _loadMoreQuickRecipes();
    }
  }

  Future<void> _loadMoreQuickRecipes() async {
    if (_isLoadingMoreQuickRecipes) return;
    if (_quickRecipes.length >= _allQuickRecipes.length) return;

    setState(() => _isLoadingMoreQuickRecipes = true);

    // Simular carga (en realidad ya tenemos todas las recetas)
    await Future.delayed(const Duration(milliseconds: 500));

    final nextIndex = _quickRecipes.length;
    final endIndex = (nextIndex + _quickRecipesPageSize).clamp(0, _allQuickRecipes.length);
    
    setState(() {
      _quickRecipes = _allQuickRecipes.sublist(0, endIndex);
      _isLoadingMoreQuickRecipes = false;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDailyStats(),
      _loadWeeklyStats(),
      _loadMonthlyStats(),
      _loadUserIngredients(),
      _loadTrendingRecipes(),
      _loadQuickRecipes(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadDailyStats() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final stats = await _trackingService.getDailyStats(today);
      setState(() {
        _dailyStats = stats;
      });
    } catch (e) {
      print('Error loading daily stats: $e');
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final today = DateTime.now();
      final week = '${today.year}-W${((today.difference(DateTime(today.year, 1, 1)).inDays) / 7).ceil().toString().padLeft(2, '0')}';
      final stats = await _trackingService.getWeeklyStats(week);
      setState(() {
        _weeklyStats = stats;
      });
    } catch (e) {
      print('Error loading weekly stats: $e');
    }
  }

  Future<void> _loadMonthlyStats() async {
    try {
      final today = DateTime.now();
      final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
      final stats = await _trackingService.getMonthlyStats(month);
      setState(() {
        _monthlyStats = stats;
      });
    } catch (e) {
      print('Error loading monthly stats: $e');
    }
  }

  Future<void> _loadUserIngredients() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      try {
        final response = await http.get(
          Uri.parse('$url/profile/ingredients'),
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final ingredientsList = data['ingredients'] ?? [];
          
          setState(() {
            _userIngredients = ingredientsList.map((ing) {
              if (ing is Map) {
                return (ing['name'] ?? '').toString().toLowerCase();
              }
              return ing.toString().toLowerCase();
            }).where((ing) => ing.isNotEmpty).toList();
          });
        }
      } catch (e) {
        print('Error loading user ingredients: $e');
      }
    } catch (e) {
      print('Error loading user ingredients: $e');
    }
  }

  Future<void> _loadTrendingRecipes() async {
    try {
      // Obtener todas las recetas y tomar las primeras como tendencias
      final allRecipes = await _recipeService.getAllRecipes();
      // Para tendencias, tomar las primeras 10 recetas
      setState(() {
        _trendingRecipes = allRecipes.take(10).toList();
      });
    } catch (e) {
      print('Error loading trending recipes: $e');
    }
  }

  Future<void> _loadQuickRecipes() async {
    try {
      // Obtener todas las recetas y filtrar por tiempo (menos de 30 minutos)
      final allRecipes = await _recipeService.getAllRecipes();
      final quick = allRecipes.where((recipe) {
        final time = recipe['time_minutes'];
        if (time == null) return false;
        final timeInt = time is int ? time : (int.tryParse(time.toString()) ?? 999);
        return timeInt <= 30;
      }).toList();
      
      // Ordenar por ingredientes que coinciden con los del usuario
      if (_userIngredients.isNotEmpty) {
        quick.sort((a, b) {
          final aScore = _calculateIngredientMatch(a);
          final bScore = _calculateIngredientMatch(b);
          return bScore.compareTo(aScore); // Mayor score primero
        });
      }
      
      setState(() {
        _allQuickRecipes = quick; // Guardar todas las recetas
        _quickRecipes = quick.take(_quickRecipesPageSize).toList(); // Cargar solo las primeras
      });
    } catch (e) {
      print('Error loading quick recipes: $e');
    }
  }

  int _calculateIngredientMatch(Map<String, dynamic> recipe) {
    if (_userIngredients.isEmpty) return 0;
    
    try {
      final recipeIngredients = recipe['ingredients'] ?? [];
      int matches = 0;
      
      if (recipeIngredients is List) {
        for (var ing in recipeIngredients) {
          String ingName = '';
          if (ing is Map) {
            ingName = (ing['name'] ?? '').toString().toLowerCase();
          } else if (ing is String) {
            ingName = ing.toLowerCase();
          }
          
          if (ingName.isNotEmpty) {
            for (var userIng in _userIngredients) {
              if (ingName.contains(userIng) || userIng.contains(ingName)) {
                matches++;
                break;
              }
            }
          }
        }
      } else if (recipeIngredients is String) {
        // Si ingredients es un String, buscar coincidencias
        final ingStr = recipeIngredients.toLowerCase();
        for (var userIng in _userIngredients) {
          if (ingStr.contains(userIng.toLowerCase())) {
            matches++;
          }
        }
      }
      
      return matches;
    } catch (e) {
      print('Error calculating ingredient match: $e');
      return 0;
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

  void _navigateToTracking() {
    final mainNavState = MainNavigationScreen.of(context);
    if (mainNavState != null) {
      mainNavState.setCurrentIndex(1); // Seguimiento
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrackingScreen()),
      );
    }
  }

  void _navigateToIngredients() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IngredientsScreen()),
    );
  }

  void _navigateToShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
    );
  }

  void _navigateToAddConsumption() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddConsumptionScreen()),
    );
  }

  void _navigateToRecipes() {
    final mainNavState = MainNavigationScreen.of(context);
    if (mainNavState != null) {
      mainNavState.setCurrentIndex(0); // Recetas
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecipesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.email ?? 'Usuario';
    final username = _authService.username ?? email.split('@')[0];
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Builder(
          builder: (context) => IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF4CAF50),
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const SizedBox.shrink(),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Sección de Alimentación, Registrar Comida y Lista Compra
                    _buildTopActionsSection(),
                    const SizedBox(height: 16),
                    // Tu progreso
                    _buildProgressCard(),
                    const SizedBox(height: 24),
                    // Tendencias
                    _buildTrendingSection(),
                    const SizedBox(height: 16),
                    // Buscador de Recetas
                    _buildRecipeSearchSection(),
                    const SizedBox(height: 24),
                    // Recetas rápidas
                    _buildQuickRecipesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProgressCard() {
    final consumed = (_dailyStats['consumed_calories'] ?? 0).toDouble();
    final goal = (_dailyStats['goal_calories'] ?? 2000).toDouble();
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    
    final nutrition = _dailyStats['nutrition'] ?? {};
    final protein = (nutrition['protein'] ?? 0).toDouble();
    final carbs = (nutrition['carbohydrates'] ?? 0).toDouble();
    final fat = (nutrition['fat'] ?? 0).toDouble();

    return InkWell(
      onTap: _navigateToTracking,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
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
              'Tu progreso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // Tres círculos: Diaria, Media Semanal, Media Mensual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressCircle(
                  label: 'Diaria',
                  value: consumed,
                  goal: goal,
                  color: Colors.orange,
                ),
                _buildProgressCircle(
                  label: 'Media Semanal',
                  value: (_weeklyStats['avg_daily_calories'] ?? 0).toDouble(),
                  goal: goal,
                  color: Colors.blue,
                ),
                _buildProgressCircle(
                  label: 'Media Mensual',
                  value: (_monthlyStats['avg_daily_calories'] ?? 0).toDouble(),
                  goal: goal,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Macronutrientes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroIndicator('Proteína', protein, Colors.purple),
                _buildMacroIndicator('Carbos', carbs, Colors.orange),
                _buildMacroIndicator('Grasas', fat, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroIndicator(String label, double value, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.5, // Valor fijo para visualización
                strokeWidth: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Alimentación (3/4)
          Expanded(
            flex: 3,
            child: _buildActionCard(
              icon: Icons.restaurant,
              title: 'Alimentación',
              subtitle: 'Ingredientes y compra',
              color: const Color(0xFF4CAF50),
              onTap: _navigateToIngredients,
            ),
          ),
          const SizedBox(width: 12),
          // Registrar Comida (3/4)
          Expanded(
            flex: 3,
            child: _buildActionCard(
              icon: Icons.local_fire_department,
              title: 'Registrar Comida',
              subtitle: 'Añadir consumo',
              color: Colors.orange,
              onTap: _navigateToAddConsumption,
            ),
          ),
          const SizedBox(width: 12),
          // Lista Compra (1/4)
          Expanded(
            flex: 1,
            child: _buildActionCard(
              icon: Icons.shopping_cart,
              title: 'Lista Compra',
              subtitle: '',
              color: Colors.blue,
              onTap: _navigateToShoppingList,
              isSmall: true, // Indicar que es más pequeño
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minHeight: 100), // Altura mínima igual para todos
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isSmall ? 18 : 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 12 : 20, // Texto más pequeño para Lista Compra
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCircle({
    required String label,
    required double value,
    required double goal,
    required Color color,
  }) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      children: [
        SizedBox(
          width: 120, // Aumentado de 80 a 120
          height: 120, // Aumentado de 80 a 120
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 12, // Aumentado de 8 a 12
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 24, // Aumentado de 18 a 24
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '/ ${goal.toInt()}',
                    style: TextStyle(
                      fontSize: 12, // Aumentado de 10 a 12
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // Aumentado de 11 a 12
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  Widget _buildRecipeSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RecipeFinderScreen(),
            ),
          );
        },
        child: Container(
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buscador de Recetas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Busca por ingredientes, tiempo...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF4CAF50),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    if (_trendingRecipes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tendencias',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: _navigateToRecipes,
                child: const Text(
                  'Ver todo >',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trendingRecipes.length,
            itemBuilder: (context, index) {
              final recipe = _trendingRecipes[index];
              return _buildRecipeCard(recipe, isHorizontal: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRecipesSection() {
    if (_quickRecipes.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recetas rápidas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecipeFinderScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Ver todo >',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400, // Altura fija para el scroll
          child: ListView.builder(
            controller: _quickRecipesScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickRecipes.length + (_isLoadingMoreQuickRecipes ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _quickRecipes.length) {
                // Mostrar indicador de carga al final
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  ),
                );
              }
              final recipe = _quickRecipes[index];
              return _buildQuickRecipeCard(recipe);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, {bool isHorizontal = false}) {
    final title = recipe['title'] ?? 'Sin título';
    final time = recipe['time_minutes'] ?? 0;
    final difficulty = recipe['difficulty'] ?? 'Fácil';
    final calories = recipe['calories'] ?? 0;
    final imageUrl = recipe['image_url'] ?? recipe['image'] ?? '';

    return Container(
      width: isHorizontal ? 200 : double.infinity,
      margin: EdgeInsets.only(
        right: isHorizontal ? 12 : 0,
        bottom: isHorizontal ? 0 : 12,
      ),
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
                  height: isHorizontal ? 200 : 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: isHorizontal ? 200 : 150,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    );
                  },
                )
              else
                Container(
                  width: double.infinity,
                  height: isHorizontal ? 200 : 150,
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
                      Row(
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
                          const SizedBox(width: 12),
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
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$calories',
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
              // Heart icon
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRecipeCard(Map<String, dynamic> recipe) {
    final title = recipe['title'] ?? 'Sin título';
    final time = recipe['time_minutes'] ?? 0;
    final imageUrl = recipe['image_url'] ?? recipe['image'] ?? '';
    
    // Manejar ingredients de forma segura
    List<String> tags = [];
    try {
      final ingredients = recipe['ingredients'];
      if (ingredients != null) {
        if (ingredients is List) {
          tags = ingredients.take(2).map((ing) {
            if (ing is Map) {
              return (ing['name'] ?? '').toString();
            }
            return ing.toString();
          }).where((tag) => tag.isNotEmpty).toList();
        } else if (ingredients is String) {
          // Si es un String, dividir por comas y tomar los primeros 2
          final parts = ingredients.split(',').take(2).toList();
          tags = parts.map((p) => p.trim()).where((tag) => tag.isNotEmpty).toList();
        }
      }
    } catch (e) {
      print('Error procesando ingredientes de receta: $e');
      tags = [];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToRecipe(recipe),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 30, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 30, color: Colors.grey),
                    ),
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$time min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }).toList(),
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
}
