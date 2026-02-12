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
import '../utils/nutrition_parser.dart';
import '../main.dart';
import 'recipe_detail_screen.dart';
import 'tracking_screen.dart';
import 'ingredients_screen.dart';
import 'shopping_list_screen.dart';
import 'add_consumption_screen.dart';
import 'recipes_screen.dart';
import 'recipe_finder_screen.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

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
  Map<String, dynamic> _goals = {};
  List<dynamic> _trendingRecipes = [];
  List<dynamic> _quickRecipes = [];
  List<dynamic> _allQuickRecipes = []; // Todas las recetas rápidas disponibles
  List<String> _userIngredients = [];
  Set<String> _failedImageIds = {};
  bool _isLoading = true;
  bool _isLoadingMoreQuickRecipes = false;
  final ScrollController _quickRecipesScrollController = ScrollController();
  static const int _quickRecipesPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quickRecipesScrollController.addListener(_onQuickRecipesScroll);
    notifyGoalsUpdated = _loadData;
  }

  @override
  void dispose() {
    notifyConsumptionAdded = null;
    notifyGoalsUpdated = null;
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
      _loadGoals(),
      _loadUserIngredients(),
      _loadTrendingRecipes(),
      _loadQuickRecipes(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await _trackingService.getGoals();
      setState(() => _goals = goals);
    } catch (e) {
      print('Error loading goals: $e');
    }
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
          final raw = data['ingredients'];
          final List<dynamic> ingredientsList = raw is List
              ? raw
              : (raw is Map ? raw.values.toList() : <dynamic>[]);

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

  bool _hasValidImageUrl(dynamic recipe) {
    final url = (recipe['image_url'] ?? recipe['image'] ?? '').toString().trim();
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower.startsWith('placeholder')) return false;
    return true;
  }

  Future<void> _loadTrendingRecipes() async {
    try {
      final allRecipes = await _recipeService.getAllRecipes();
      // Solo recetas con imagen válida (excluir placeholders, null, etc.)
      final withImage = allRecipes.where(_hasValidImageUrl).toList();
      setState(() {
        _trendingRecipes = withImage.take(10).toList();
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
    ).then((result) {
      if (result == true && mounted) _loadData();
    });
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
      backgroundColor: AppTheme.scaffoldBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Builder(
          builder: (context) {
            final avatarUrl = _authService.avatarUrl;
            return IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        firstLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 225, maxHeight: 58),
          child: Image.network(
            AppConfig.logoFirebaseUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/Cookind.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkScaffoldBackground
                    : AppTheme.scaffoldBackground,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Acciones rápidas (iconos sin título - Index.tsx QuickActions)
                    _buildQuickActionsRow(),
                    const SizedBox(height: 16),
                    // Tu día (calorías, medias, macros - mismo diseño que Index.tsx)
                    _buildProgressCard(),
                    const SizedBox(height: 16),
                    // Tendencias
                    _buildTrendingSection(),
                    const SizedBox(height: 16),
                    // Recetas rápidas
                    _buildQuickRecipesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
                ),
              ),
            ),
    );
  }

  /// Sección "Tu día" - diseño inspirado en Index.tsx, enlazada con los mismos datos de TrackingScreen
  Widget _buildProgressCard() {
    final consumed = (_dailyStats['consumed_calories'] ?? 0).toDouble();
    final goal = (_dailyStats['goal_calories'] ?? (_goals['daily_goals']?['calories'] ?? 2000)).toDouble();
    final weeklyAvg = (_weeklyStats['avg_daily_calories'] ?? 0).toDouble();
    final monthlyAvg = (_monthlyStats['avg_daily_calories'] ?? 0).toDouble();

    final nutrition = _dailyStats['nutrition'] ?? {};
    final protein = (nutrition['protein'] ?? 0).toDouble();
    final carbs = (nutrition['carbohydrates'] ?? 0).toDouble();
    final fat = (nutrition['fat'] ?? 0).toDouble();

    final goalsMap = _goals['daily_goals'] ?? {};
    final proteinGoal = (goalsMap['protein'] ?? 120).toDouble();
    final carbsGoal = (goalsMap['carbohydrates'] ?? 250).toDouble();
    final fatGoal = (goalsMap['fat'] ?? 65).toDouble();

    final today = DateTime.now();
    final dateLabel = 'Hoy, ${today.day} ${_getMonthName(today.month)}';

    return InkWell(
      onTap: _navigateToTracking,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Tu día + fecha (igual que Index.tsx)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tu día',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Calorías: círculo principal a la izquierda, tarjetas semanal/mensual a la derecha (Index.tsx)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCalorieCircle(consumed: consumed, goal: goal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildAverageCard(
                        label: 'media\nsemanal',
                        value: weeklyAvg,
                        color: const Color.fromARGB(255, 18, 63, 44),
                        gradientEnd: AppTheme.ecoSage,
                      ),
                      const SizedBox(height: 12),
                      _buildAverageCard(
                        label: 'media\nmensual',
                        value: monthlyAvg,
                        color: const Color.fromARGB(255, 193, 104, 27),
                        gradientEnd: AppTheme.ecoCream,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Macronutrientes (mismo diseño que Index.tsx)
            Text(
              'Macronutrientes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMacroCard('Proteínas', protein, proteinGoal, AppTheme.primary, Icons.fitness_center)),
                const SizedBox(width: 8),
                Expanded(child: _buildMacroCard('Carbos', carbs, carbsGoal, AppTheme.ecoTerracotta, Icons.grain)),
                const SizedBox(width: 8),
                Expanded(child: _buildMacroCard('Grasas', fat, fatGoal, AppTheme.ecoSage, Icons.water_drop)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Círculo de progreso diario con texto dentro (igual que CalorieCircle de Index.tsx)
  Widget _buildCalorieCircle({required double consumed, required double goal}) {
    const double circleSize = 150;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1.0 ? AppTheme.ecoTerracotta : AppTheme.primary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                consumed.toInt().toString(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                '/${goal.toInt()} kcal',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAverageCard({
    required String label,
    required double value,
    required Color color,
    Color? gradientEnd,
  }) {
    final endColor = gradientEnd ?? color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            endColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.toInt().toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          Text(
            'kcal/día',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String name, double current, double goal, Color color, IconData icon) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${current.toInt()}/${goal.toInt()}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  /// Acciones rápidas: 4 iconos con texto descriptivo
  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildQuickActionIcon('Alimentación', Icons.restaurant, AppTheme.primary, _navigateToIngredients),
              const SizedBox(width: 8),
              _buildQuickActionIconWithTwoIcons('Buscar Recetas', Icons.search, Icons.menu_book, AppTheme.primary, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeFinderScreen()));
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQuickActionIcon('Agregar Consumo', Icons.local_fire_department, AppTheme.primary, _navigateToAddConsumption),
              const SizedBox(width: 8),
              _buildQuickActionIcon('Cesta de la compra', Icons.shopping_cart_outlined, AppTheme.primary, _navigateToShoppingList),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorderColor(context), width: 1),
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
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionIconWithTwoIcons(String label, IconData icon1, IconData icon2, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorderColor(context), width: 1),
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
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon2, color: color.withValues(alpha: 0.6), size: 22),
                      Icon(icon1, color: color, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
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
    bool iconOnly = false, // Para Lista Compra: solo icono
    bool horizontalLayout = false, // Para Alimentación y Registrar: icono al lado del texto
    bool showArrow = false, // Para mostrar flecha a la derecha
    bool isLarge = false, // Para hacer más grande el carrito
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14), // Mismo padding para ambos
        constraints: const BoxConstraints(
          minHeight: 70, // Misma altura para ambos
        ),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorderColor(context), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: iconOnly
            ? Center(
                child: Icon(icon, color: color, size: 28), // Mismo tamaño de icono
              )
            : horizontalLayout
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: color, size: 20), // Icono más pequeño
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showArrow)
                        Icon(Icons.arrow_forward_ios, 
                          color: color.withValues(alpha: 0.6), 
                          size: 16,
                        ),
                    ],
                  )
                : Column(
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
                          fontSize: isSmall ? 12 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
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
                            color: AppTheme.textSecondary(context),
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
    bool isLarge = false,
  }) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    // Círculo diario más grande: circunferencia >= todo el texto dentro
    final size = isLarge ? 200.0 : 100.0;
    final strokeWidth = isLarge ? 14.0 : 10.0;
    final valueFontSize = isLarge ? 34.0 : 20.0;
    final goalFontSize = isLarge ? 16.0 : 12.0;
    final labelFontSize = isLarge ? 16.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: strokeWidth,
                backgroundColor: AppTheme.fillMedium(context),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '/${goal.toInt()} kcal',
                    style: TextStyle(
                      fontSize: goalFontSize,
                      color: AppTheme.textSecondary(context),
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
            fontSize: labelFontSize,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.textSecondary(context),
          ),
          textAlign: isLarge ? TextAlign.left : TextAlign.center,
        ),
      ],
    );
  }

  /// Círculo de progreso con "X/Y kcal" y etiqueta debajo, todo centrado (semanal/mensual).
  Widget _buildProgressCircleWithKcalBelow({
    required double value,
    required double goal,
    required Color color,
    required String label,
  }) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    const double size = 88.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${value.toInt()}/${goal.toInt()} kcal',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary(context),
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
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorderColor(context), width: 1),
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
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buscador de Recetas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Busca por ingredientes, tiempo...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.primary,
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
              Text(
                'Tendencias',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              TextButton(
                onPressed: _navigateToRecipes,
                child: const Text(
                  'Ver todo >',
                  style: TextStyle(
                    color: AppTheme.primary,
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
              Text(
                'Recetas rápidas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
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
                    color: AppTheme.primary,
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
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
    final recipeId = (recipe['id'] ?? recipe['title'] ?? '').toString();
    final title = recipe['title'] ?? 'Sin título';
    final time = recipe['time_minutes'] ?? 0;
    final difficulty = recipe['difficulty'] ?? 'Fácil';
    final calories = recipe['calories'] ?? 0;
    final caloriesPerServing = recipe['calories_per_serving'] ?? 
        (recipe['calories'] != null && recipe['servings'] != null 
            ? (recipe['calories'] / recipe['servings']).round() : 0);
    final recipeImg = (recipe['image_url'] ?? recipe['image'] ?? '').toString().trim();
    final useRecipeImage = recipeImg.isNotEmpty && !_failedImageIds.contains(recipeId);
    final imageUrl = useRecipeImage ? recipeImg : AppConfig.backupPhotoFirebaseUrl;

    return Container(
      width: isHorizontal ? 200 : double.infinity,
      margin: EdgeInsets.only(
        right: isHorizontal ? 12 : 0,
        bottom: isHorizontal ? 0 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: null,
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
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: isHorizontal ? 200 : 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _failedImageIds.add(recipeId));
                          });
                        }
                        return const SizedBox.shrink();
                      },
                    ),
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
                                color: AppTheme.vividOrange,
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
                    color: AppTheme.vividRed,
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
    final recipeId = (recipe['id'] ?? recipe['title'] ?? '').toString();
    final title = recipe['title'] ?? 'Sin título';
    final time = recipe['time_minutes'] ?? 0;
    final recipeImg = (recipe['image_url'] ?? recipe['image'] ?? '').toString().trim();
    final useRecipeImage = recipeImg.isNotEmpty && !_failedImageIds.contains(recipeId);
    final imageUrl = useRecipeImage ? recipeImg : AppConfig.backupPhotoFirebaseUrl;
    // Obtener calorías por porción
    final caloriesPerServing = recipe['calories_per_serving'] ?? 
                               (recipe['calories'] != null && recipe['servings'] != null 
                                 ? (recipe['calories'] / recipe['servings']).round() 
                                 : 0);
    
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
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
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
            ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
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
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
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
                            Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary(context)),
                            const SizedBox(width: 4),
                            Text(
                              '$time min',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                        if (recipe['difficulty'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.fillMedium(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              recipe['difficulty'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                        if (recipe['servings'] != null && recipe['servings'] > 0) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant, size: 14, color: AppTheme.textSecondary(context)),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe['servings']} raciones',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (caloriesPerServing > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.vividOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$caloriesPerServing kcal/ración',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.vividOrange,
                              ),
                            ),
                          ),
                        ],
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
                              color: AppTheme.fillLight(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary(context),
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
