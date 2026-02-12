import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_consumption_screen.dart';
import '../main.dart' show MainNavigationScreen, notifyGoalsUpdated;

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final AuthService _authService = AuthService();
  final TrackingService _trackingService = TrackingService();
  String _selectedPeriod = 'day'; // day, week, month
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  DateTime? _monthStartDate; // Start date for monthly range
  DateTime? _monthEndDate; // End date for monthly range
  Map<String, dynamic> _dailyStats = {};
  Map<String, dynamic> _weeklyStats = {};
  Map<String, dynamic> _monthlyStats = {};
  List<dynamic> _consumptionEntries = [];
  Map<String, dynamic> _goals = {};
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  
  // Datos diarios para gráficos semanales y mensuales
  List<Map<String, dynamic>> _weeklyDailyData = []; // Datos por día de la semana
  List<Map<String, dynamic>> _monthlyDailyData = []; // Datos por día del mes

  @override
  void initState() {
    super.initState();
    // Por defecto mostrar diario y semanal
    _selectedPeriod = 'day';
    // Initialize monthly range to current month
    final now = DateTime.now();
    _monthStartDate = DateTime(now.year, now.month, 1);
    _monthEndDate = DateTime(now.year, now.month + 1, 0);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadGoals(),
      _loadProfile(),
      _loadDailyStats(),
      _loadWeeklyStats(),
      _loadMonthlyStats(),
      _loadConsumption(),
    ]);
    
    // Cargar datos diarios para gráficos
    if (_selectedPeriod == 'week') {
      await _loadWeeklyDailyData();
    } else if (_selectedPeriod == 'month') {
      await _loadMonthlyDailyData();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadGoals() async {
    final goals = await _trackingService.getGoals();
    setState(() {
      _goals = goals;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http.get(Uri.parse('$url/profile'), headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        setState(() => _profile = json.decode(resp.body) as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadDailyStats() async {
    final stats = await _trackingService.getDailyStats(_selectedDate);
    setState(() {
      _dailyStats = stats;
    });
  }

  Future<void> _loadWeeklyStats() async {
    final week = _getWeekFromDate(_selectedDate);
    final stats = await _trackingService.getWeeklyStats(week);
    setState(() {
      _weeklyStats = stats;
    });
  }

  Future<void> _loadMonthlyStats() async {
    final month = _selectedDate.substring(0, 7); // yyyy-MM
    final stats = await _trackingService.getMonthlyStats(month);
    setState(() {
      _monthlyStats = stats;
    });
  }

  Future<void> _loadConsumption() async {
    final entries = await _trackingService.getConsumption(date: _selectedDate);
    setState(() {
      _consumptionEntries = entries;
    });
  }
  
  // Obtener datos diarios para la semana actual (lunes a domingo)
  Future<void> _loadWeeklyDailyData() async {
    final selectedDate = DateTime.parse(_selectedDate);
    // Encontrar el lunes de la semana
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final startStr = DateFormat('yyyy-MM-dd').format(monday);
    final endStr = DateFormat('yyyy-MM-dd').format(sunday);
    
    final List<Map<String, dynamic>> dailyData = [];
    
    try {
      // Intentar obtener todos los datos de la semana de una vez
      final allEntries = await _trackingService.getConsumption(start: startStr, end: endStr);
      
      // Agrupar por fecha
      final Map<String, double> caloriesByDate = {};
      for (var entry in allEntries) {
        final date = entry['date'] as String? ?? startStr;
        final calories = (entry['total_calories'] ?? 0.0).toDouble();
        caloriesByDate[date] = (caloriesByDate[date] ?? 0.0) + calories;
      }
      
      // Crear datos para cada día (lunes a domingo)
      for (int i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        
        dailyData.add({
          'date': dayStr,
          'day_name': _getDayName(day.weekday),
          'calories': caloriesByDate[dayStr] ?? 0.0,
          'day_index': i, // 0 = lunes, 6 = domingo
        });
      }
    } catch (e) {
      print('Error cargando datos semanales: $e');
      // Fallback: cargar día por día
      for (int i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        
        try {
          final entries = await _trackingService.getConsumption(date: dayStr);
          double totalCalories = 0.0;
          for (var entry in entries) {
            totalCalories += (entry['total_calories'] ?? 0.0).toDouble();
          }
          dailyData.add({
            'date': dayStr,
            'day_name': _getDayName(day.weekday),
            'calories': totalCalories,
            'day_index': i,
          });
        } catch (e) {
          print('Error cargando datos para $dayStr: $e');
          dailyData.add({
            'date': dayStr,
            'day_name': _getDayName(day.weekday),
            'calories': 0.0,
            'day_index': i,
          });
        }
      }
    }
    
    setState(() {
      _weeklyDailyData = dailyData;
    });
  }
  
  // Obtener datos diarios para el rango mensual seleccionado
  Future<void> _loadMonthlyDailyData() async {
    final startDate = _monthStartDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final endDate = _monthEndDate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    final now = DateTime.now();
    
    final List<Map<String, dynamic>> dailyData = [];
    
    // Obtener datos para cada día del rango de forma más eficiente
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate.isAfter(now) ? now : endDate);
    
    try {
      // Intentar obtener todos los datos del mes de una vez
      final allEntries = await _trackingService.getConsumption(start: startStr, end: endStr);
      
      // Agrupar por fecha
      final Map<String, double> caloriesByDate = {};
      for (var entry in allEntries) {
        final date = entry['date'] ?? _selectedDate;
        final calories = (entry['total_calories'] ?? 0.0).toDouble();
        caloriesByDate[date] = (caloriesByDate[date] ?? 0.0) + calories;
      }
      
      // Crear datos para cada día del rango
      int daysDiff = endDate.difference(startDate).inDays + 1;
      for (int i = 0; i < daysDiff; i++) {
        final day = startDate.add(Duration(days: i));
        
        // No incluir días futuros
        if (day.isAfter(now)) break;
        
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        
        dailyData.add({
          'date': dayStr,
          'day': day.day,
          'month': day.month,
          'year': day.year,
          'calories': caloriesByDate[dayStr] ?? 0.0,
        });
      }
    } catch (e) {
      print('Error cargando datos mensuales: $e');
      // Fallback: cargar día por día
      int daysDiff = endDate.difference(startDate).inDays + 1;
      for (int i = 0; i < daysDiff; i++) {
        final day = startDate.add(Duration(days: i));
        if (day.isAfter(now)) break;
        
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        try {
          final entries = await _trackingService.getConsumption(date: dayStr);
          double totalCalories = 0.0;
          for (var entry in entries) {
            totalCalories += (entry['total_calories'] ?? 0.0).toDouble();
          }
          dailyData.add({
            'date': dayStr,
            'day': day.day,
            'month': day.month,
            'year': day.year,
            'calories': totalCalories,
          });
        } catch (e) {
          dailyData.add({
            'date': dayStr,
            'day': day.day,
            'month': day.month,
            'year': day.year,
            'calories': 0.0,
          });
        }
      }
    }
    
    setState(() {
      _monthlyDailyData = dailyData;
    });
  }
  
  String _getDayName(int weekday) {
    // weekday: 1 = lunes, 7 = domingo
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    if (weekday >= 1 && weekday <= 7) {
      return days[weekday - 1];
    }
    return 'Día';
  }

  String _getWeekFromDate(String date) {
    final dateTime = DateTime.parse(date);
    final year = dateTime.year;
    final week = ((dateTime.difference(DateTime(year, 1, 1)).inDays) / 7).ceil();
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> get _currentStats {
    switch (_selectedPeriod) {
      case 'week':
        return _weeklyStats;
      case 'month':
        return _monthlyStats;
      default:
        return _dailyStats;
    }
  }

  double get _consumedCalories {
    return (_currentStats['consumed_calories'] ?? _currentStats['avg_daily_calories'] ?? 0).toDouble();
  }

  double get _goalCalories {
    return (_goals['daily_goals']?['calories'] ?? 2000).toDouble();
  }

  /// Media kcal/día solo de los días en que se añadió consumo (periodo día/semana/mes)
  double get _avgCaloriesDaysWithConsumption {
    switch (_selectedPeriod) {
      case 'day':
        return _consumedCalories;
      case 'week':
        final withData = _weeklyDailyData.where((d) => (d['calories'] as double) > 0).toList();
        if (withData.isEmpty) return 0;
        return withData.map((d) => d['calories'] as double).reduce((a, b) => a + b) / withData.length;
      case 'month':
        final withData = _monthlyDailyData.where((d) => (d['calories'] as double) > 0).toList();
        if (withData.isEmpty) return 0;
        return withData.map((d) => d['calories'] as double).reduce((a, b) => a + b) / withData.length;
      default:
        return _consumedCalories;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Volver a la homepage (MainNavigationScreen index 2)
            final mainNavState = MainNavigationScreen.of(context);
            if (mainNavState != null) {
              mainNavState.setCurrentIndex(2); // Inicio
            } else {
              // Fallback: intentar pop si no hay MainNavigationScreen
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          },
        ),
        title: const Text(
          'Seguimiento',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department, color: Colors.white),
            tooltip: 'Agregar consumo',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddConsumptionScreen()),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 20),
                  
                  // Día / Semana / Mes: cada uno combina calorías + macronutrientes en la misma tarjeta
                  if (_selectedPeriod == 'day') ...[
                    _buildDailyCalorieCard(),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedPeriod == 'week') ...[
                    _buildWeeklyChart(),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedPeriod == 'month') ...[
                    _buildMonthlyChartWidget(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Consumption list
                  _buildConsumptionList(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AppTheme.cardColor(context),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('Día', 'day', Icons.today),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPeriodButton('Semana', 'week', Icons.calendar_view_week),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPeriodButton('Mes', 'month', Icons.calendar_month),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period, IconData icon) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.fillLight(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary(context), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Día: Mi día (círculo kcal) + Macronutrientes en la misma tarjeta
  Widget _buildDailyCalorieCard() {
    final goal = _goalCalories;
    final consumed = _consumedCalories;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tu día',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Hoy, ${DateTime.now().day} ${_getMonthName(DateTime.now().month)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF2D6A4F)),
                onPressed: _showCalorieGoalDialog,
                tooltip: 'Editar objetivo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(child: _buildCalorieCircle(consumed, goal, progress)),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildMacronutrientsContent(),
        ],
      ),
    );
  }

  Widget _buildCalorieCircle(double value, double goal, double progress, {String? subtitle}) {
    const double size = 150;
    final bottomText = subtitle ?? '/${goal.toInt()} kcal';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
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
            children: [
              Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
              ),
              Text(bottomText, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Contenido de Macronutrientes (para incluir dentro de otras tarjetas)
  Widget _buildMacronutrientsContent() {
    final nutrition = _currentStats['nutrition'] ?? _currentStats['avg_daily_nutrition'] ?? {};
    final goals = _goals['daily_goals'] ?? {};
    final protein = (nutrition['protein'] ?? 0.0).toDouble();
    final carbs = (nutrition['carbohydrates'] ?? 0.0).toDouble();
    final fat = (nutrition['fat'] ?? 0.0).toDouble();
    final proteinGoal = (goals['protein'] ?? 120.0).toDouble();
    final carbsGoal = (goals['carbohydrates'] ?? 250.0).toDouble();
    final fatGoal = (goals['fat'] ?? 65.0).toDouble();
    final weightKg = (_profile['weight_kg'] ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Macronutrientes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
            TextButton.icon(
              onPressed: () => _showGoalsAndWeightDialog(),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Editar'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMacroCard('Proteínas', protein, proteinGoal, AppTheme.primary, Icons.fitness_center)),
            const SizedBox(width: 8),
            Expanded(child: _buildMacroCard('Carbos', carbs, carbsGoal, AppTheme.ecoTerracotta, Icons.grain)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMacroCard('Grasas', fat, fatGoal, AppTheme.ecoSage, Icons.water_drop)),
            const SizedBox(width: 8),
            Expanded(child: _buildWeightCard(weightKg)),
          ],
        ),
      ],
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
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            '${current.toInt()}/${goal.toInt()} g',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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

  Widget _buildWeightCard(double weightKg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.monitor_weight, size: 20, color: Colors.blue[700]),
          const SizedBox(height: 6),
          Text('Peso actual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            weightKg > 0 ? '${weightKg.toStringAsFixed(1)} kg' : '-- kg',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  void _showGoalsAndWeightDialog() {
    final goals = _goals['daily_goals'] ?? {};
    final caloriesController = TextEditingController(text: (goals['calories'] ?? 2000).toString());
    final proteinController = TextEditingController(text: (goals['protein'] ?? 150).toString());
    final carbsController = TextEditingController(text: (goals['carbohydrates'] ?? 250).toString());
    final fatController = TextEditingController(text: (goals['fat'] ?? 65).toString());
    final weightController = TextEditingController(
      text: (_profile['weight_kg'] != null && (_profile['weight_kg'] as num) > 0)
          ? (_profile['weight_kg'] as num).toString()
          : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar objetivos y peso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías (kcal)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Proteínas (g)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbohidratos (g)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grasas (g)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Peso actual (kg)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newCal = double.tryParse(caloriesController.text) ?? 2000.0;
              final newProt = double.tryParse(proteinController.text) ?? 150.0;
              final newCarbs = double.tryParse(carbsController.text) ?? 250.0;
              final newFat = double.tryParse(fatController.text) ?? 65.0;
              final newWeight = double.tryParse(weightController.text);
              final success = await _trackingService.updateGoals({
                'calories': newCal,
                'protein': newProt,
                'carbohydrates': newCarbs,
                'fat': newFat,
              });
              if (success) {
                if (newWeight != null && newWeight > 0) {
                  try {
                    final url = await AppConfig.getBackendUrl();
                    final headers = await _authService.getAuthHeaders();
                    await http.put(
                      Uri.parse('$url/profile'),
                      headers: {...headers, 'Content-Type': 'application/json'},
                      body: json.encode({'weight_kg': newWeight}),
                    );
                  } catch (e) {
                    print('Error updating weight: $e');
                  }
                }
                Navigator.pop(context);
                await _loadGoals();
                await _loadProfile();
                await _loadDailyStats();
                await _loadWeeklyStats();
                await _loadMonthlyStats();
                if (mounted) setState(() {});
                notifyGoalsUpdated?.call();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Objetivos actualizados'), backgroundColor: AppTheme.primary),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesCard() {
    final consumed = _consumedCalories;
    final goal = _goalCalories;
    final remaining = goal - consumed;
    final percentage = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calorías',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF4CAF50)),
                onPressed: () => _showCalorieGoalDialog(),
                tooltip: 'Editar objetivo de calorías',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${consumed.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  Text(
                    'de ${goal.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    remaining > 0 ? '${remaining.toStringAsFixed(0)}' : '0',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: remaining > 0 ? Colors.grey[700] : AppTheme.vividOrange,
                    ),
                  ),
                  Text(
                    'restantes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 1.0 ? AppTheme.vividOrange : AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gráfico diario
  Widget _buildDailyChart() {
    final consumed = _consumedCalories;
    final goal = _goalCalories;
    final avg = consumed; // For daily view, average is the same as consumed
    final maxY = (goal * 1.2).clamp(consumed * 1.1, goal * 1.5);
    final barHeight = 250.0;
    final goalBarWidth = 60.0; // Tamaño fijo para barras de meta/media
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Text(
            'Calorías del Día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: barHeight,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Consumidas',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: consumed,
                              color: consumed > goal ? AppTheme.vividOrange : AppTheme.accent,
                              width: goalBarWidth, // Mismo tamaño que barras de meta/media
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Barra lateral: altura = meta (gris), relleno = media días con consumo (verde grisáceo), sin texto
              _buildSideProgressBar(goal, _avgCaloriesDaysWithConsumption, goalBarWidth, barHeight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideProgressBar(double goal, double avg, double width, double height) {
    final fillRatio = goal > 0 ? (avg / goal).clamp(0.0, 1.0) : 0.0;
    final fillHeight = height * fillRatio;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Fondo gris (altura = meta)
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Relleno verde grisáceo (media de días con consumo)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: width,
              height: fillHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF84A98C), // eco-sage, verde grisáceo
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gráfico semanal (lunes a domingo + objetivo)
  Widget _buildWeeklyChart() {
    if (_weeklyDailyData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final goal = _goalCalories;
    const marginKcal = 500.0;
    final maxDayCalories = _weeklyDailyData.map((d) => d['calories'] as double).fold<double>(0, (a, b) => a > b ? a : b);
    // Eje Y: base = objetivo + 500; si algún día lo supera, se autoajusta
    final baseMax = goal + marginKcal;
    final maxY = maxDayCalories > baseMax ? maxDayCalories + 100 : baseMax;
    final barHeight = 250.0;
    final barWidth = 35.0;
    
    // Barra extra para Objetivo al final (7 días + Objetivo = 8 grupos)
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _weeklyDailyData.length; i++) {
      final dayData = _weeklyDailyData[i];
      final calories = dayData['calories'] as double;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: calories,
            color: calories > goal ? AppTheme.vividOrange : AppTheme.accent,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }
    barGroups.add(BarChartGroupData(
      x: _weeklyDailyData.length,
      barRods: [
        BarChartRodData(
          toY: goal,
          color: Colors.grey[400]!,
          width: barWidth,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    ));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Text(
            'Calorías Semanales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: barHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < _weeklyDailyData.length) {
                        final dayData = _weeklyDailyData[groupIndex];
                        return BarTooltipItem(
                          '${dayData['day_name']}\n${dayData['calories'].toStringAsFixed(0)} kcal',
                          TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      if (groupIndex == _weeklyDailyData.length) {
                        return BarTooltipItem(
                          'Objetivo\n${goal.toInt()} kcal',
                          TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return BarTooltipItem('', const TextStyle());
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _weeklyDailyData.length) {
                          final dayName = _weeklyDailyData[value.toInt()]['day_name'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dayName,
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                          );
                        }
                        if (value.toInt() == _weeklyDailyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Objetivo',
                              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildMacronutrientsContent(),
        ],
      ),
    );
  }
  
  // Gráfico mensual (días del mes + objetivo)
  Widget _buildMonthlyChartWidget() {
    if (_monthlyDailyData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final goal = _goalCalories;
    const marginKcal = 500.0;
    final maxDayCalories = _monthlyDailyData.map((d) => d['calories'] as double).fold<double>(0, (a, b) => a > b ? a : b);
    // Eje Y: base = objetivo + 500; si algún día lo supera, se autoajusta
    final baseMax = goal + marginKcal;
    final maxY = maxDayCalories > baseMax ? maxDayCalories + 100 : baseMax;
    final barHeight = 250.0;
    
    final availableWidth = MediaQuery.of(context).size.width - 80;
    final totalGroups = _monthlyDailyData.length + 1; // días + Objetivo
    final dailyBarWidth = totalGroups > 0 ? (availableWidth / totalGroups).clamp(6.0, 16.0) : 8.0;
    
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _monthlyDailyData.length; i++) {
      final dayData = _monthlyDailyData[i];
      final calories = dayData['calories'] as double;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: calories,
            color: calories > goal ? AppTheme.vividOrange : AppTheme.accent,
            width: dailyBarWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      ));
    }
    barGroups.add(BarChartGroupData(
      x: _monthlyDailyData.length,
      barRods: [
        BarChartRodData(
          toY: goal,
          color: Colors.grey[400]!,
          width: dailyBarWidth * 1.5, // Barra objetivo un poco más ancha
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ],
    ));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calorías Mensuales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              // Selector de rango de fechas (día inicio - día fin)
              TextButton.icon(
                onPressed: () async {
                  // Show dialog to select date range (day start - day end)
                  final startDate = _monthStartDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
                  final endDate = _monthEndDate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
                  
                  final startPicked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    helpText: 'Día inicio',
                  );
                  
                  if (startPicked != null) {
                    final endPicked = await showDatePicker(
                      context: context,
                      initialDate: endDate.isBefore(startPicked) ? startPicked : endDate,
                      firstDate: startPicked,
                      lastDate: DateTime.now(),
                      helpText: 'Día fin',
                    );
                    
                    if (endPicked != null) {
                      setState(() {
                        _monthStartDate = startPicked;
                        _monthEndDate = endPicked;
                        _selectedDate = DateFormat('yyyy-MM-dd').format(startPicked);
                      });
                      _loadData();
                    }
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(
                  _monthStartDate != null && _monthEndDate != null
                      ? '${DateFormat('d MMM', 'es').format(_monthStartDate!)} - ${DateFormat('d MMM yyyy', 'es').format(_monthEndDate!)}'
                      : DateFormat('MMMM yyyy', 'es').format(DateTime.parse(_selectedDate)),
                  style: const TextStyle(color: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: barHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < _monthlyDailyData.length) {
                        final dayData = _monthlyDailyData[groupIndex];
                        return BarTooltipItem(
                          'Día ${dayData['day']}\n${dayData['calories'].toStringAsFixed(0)} kcal',
                          TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      if (groupIndex == _monthlyDailyData.length) {
                        return BarTooltipItem(
                          'Objetivo\n${goal.toInt()} kcal',
                          TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return BarTooltipItem('', const TextStyle());
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _monthlyDailyData.length) {
                          final dayData = _monthlyDailyData[value.toInt()];
                          final day = dayData['day'] as int;
                          final month = dayData['month'] as int;
                          final isFirstOfMonth = day == 1;
                          final isEvery5Days = day % 5 == 0;
                          final isLast = value.toInt() == _monthlyDailyData.length - 1;
                          if (isFirstOfMonth || isEvery5Days || isLast) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                isFirstOfMonth && day == 1 ? '${day}/${month}' : day.toString(),
                                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                              ),
                            );
                          }
                        }
                        if (value.toInt() == _monthlyDailyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              ' ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildMacronutrientsContent(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
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

  Widget _buildNutritionBreakdown() {
    final nutrition = _currentStats['nutrition'] ?? _currentStats['avg_daily_nutrition'] ?? {};
    final goals = _goals['daily_goals'] ?? {};
    
    final protein = (nutrition['protein'] ?? 0.0).toDouble();
    final carbs = (nutrition['carbohydrates'] ?? 0.0).toDouble();
    final fat = (nutrition['fat'] ?? 0.0).toDouble();
    final fiber = (nutrition['fiber'] ?? 0.0).toDouble();
    
    final proteinGoal = (goals['protein'] ?? 150.0).toDouble();
    final carbsGoal = (goals['carbohydrates'] ?? 250.0).toDouble();
    final fatGoal = (goals['fat'] ?? 65.0).toDouble();
    final fiberGoal = (goals['fiber'] ?? 25.0).toDouble();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Macronutrientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showGoalsDialog(),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar objetivos'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNutritionItemWithProgress('Proteínas', protein, proteinGoal, 'g', Colors.blue),
          const SizedBox(height: 12),
          _buildNutritionItemWithProgress('Carbohidratos', carbs, carbsGoal, 'g', AppTheme.vividOrange),
          const SizedBox(height: 12),
          _buildNutritionItemWithProgress('Grasas', fat, fatGoal, 'g', Colors.purple),
          const SizedBox(height: 12),
          _buildNutritionItemWithProgress('Fibra', fiber, fiberGoal, 'g', Colors.green),
        ],
      ),
    );
  }
  
  void _showCalorieGoalDialog() {
    final goals = _goals['daily_goals'] ?? {};
    final caloriesController = TextEditingController(text: (goals['calories'] ?? 2000).toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Objetivo de Calorías'),
        content: TextField(
          controller: caloriesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Calorías diarias (kcal)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCalories = double.tryParse(caloriesController.text) ?? 2000.0;
              final success = await _trackingService.updateGoals({
                'calories': newCalories,
                'protein': (goals['protein'] ?? 150.0).toDouble(),
                'carbohydrates': (goals['carbohydrates'] ?? 250.0).toDouble(),
                'fat': (goals['fat'] ?? 65.0).toDouble(),
                'fiber': (goals['fiber'] ?? 25.0).toDouble(),
              });
              
              if (success) {
                Navigator.pop(context);
                await _loadGoals();
                await _loadDailyStats();
                await _loadWeeklyStats();
                await _loadMonthlyStats();
                if (mounted) setState(() {});
                notifyGoalsUpdated?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Objetivo de calorías actualizado'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al actualizar objetivo'),
                    backgroundColor: AppTheme.vividRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
  
  void _showGoalsDialog() {
    final goals = _goals['daily_goals'] ?? {};
    final caloriesController = TextEditingController(text: (goals['calories'] ?? 2000).toString());
    final proteinController = TextEditingController(text: (goals['protein'] ?? 150).toString());
    final carbsController = TextEditingController(text: (goals['carbohydrates'] ?? 250).toString());
    final fatController = TextEditingController(text: (goals['fat'] ?? 65).toString());
    final fiberController = TextEditingController(text: (goals['fiber'] ?? 25).toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Objetivos Nutricionales'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorías (kcal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Proteínas (g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carbohidratos (g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Grasas (g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fiberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fibra (g)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _trackingService.updateGoals({
                'calories': double.tryParse(caloriesController.text) ?? 2000.0,
                'protein': double.tryParse(proteinController.text) ?? 150.0,
                'carbohydrates': double.tryParse(carbsController.text) ?? 250.0,
                'fat': double.tryParse(fatController.text) ?? 65.0,
                'fiber': double.tryParse(fiberController.text) ?? 25.0,
              });
              
              if (success) {
                Navigator.pop(context);
                await _loadGoals();
                await _loadDailyStats();
                await _loadWeeklyStats();
                await _loadMonthlyStats();
                if (mounted) setState(() {});
                notifyGoalsUpdated?.call();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Objetivos actualizados'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al actualizar objetivos'),
                      backgroundColor: AppTheme.vividRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutritionItemWithProgress(String label, double value, double goal, String unit, Color color) {
    final percentage = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} $unit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: percentage > 1.0 ? AppTheme.vividOrange : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 1.0 ? AppTheme.vividOrange : color,
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildConsumptionList() {
    if (_consumptionEntries.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay alimentos registrados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega alimentos consumidos para ver tu historial',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
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
          Text(
            'Alimentos Consumidos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          ..._consumptionEntries.map((entry) => _buildConsumptionEntry(entry)),
        ],
      ),
    );
  }

  Widget _buildConsumptionEntry(Map<String, dynamic> entry) {
    final mealType = entry['meal_type'] ?? 'comida';
    final foods = entry['foods'] ?? [];
    final totalCalories = entry['total_calories'] ?? 0.0;
    final totalNutrition = entry['total_nutrition'] ?? {};
    
    final mealTypeLabels = {
      'desayuno': 'Desayuno',
      'comida': 'Comida',
      'cena': 'Cena',
      'snack': 'Snack',
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mealTypeLabels[mealType.toLowerCase()] ?? mealType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('HH:mm').format(DateTime.parse(entry['timestamp'] ?? DateTime.now().toIso8601String())),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${totalCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  if (totalNutrition.isNotEmpty)
                    Text(
                      'P: ${(totalNutrition['protein'] ?? 0).toStringAsFixed(1)}g | C: ${(totalNutrition['carbohydrates'] ?? 0).toStringAsFixed(1)}g | G: ${(totalNutrition['fat'] ?? 0).toStringAsFixed(1)}g',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...foods.map((food) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16, color: Color(0xFF4CAF50))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food['name'] ?? 'Alimento',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${food['quantity']} ${food['unit']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${food['calories']?.toStringAsFixed(0) ?? 0} kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Custom painter para dibujar el área de fondo gris que representa el objetivo
class _GoalAreaPainter extends CustomPainter {
  final double goal;
  final double maxY;
  final Color color;

  _GoalAreaPainter({
    required this.goal,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calcular la posición Y del objetivo en el canvas
    // Nota: El eje Y en canvas es invertido (0 está arriba)
    final goalY = size.height - (goal / maxY) * size.height;
    
    // Dibujar un rectángulo gris desde el objetivo hasta el máximo (abajo)
    final rect = Rect.fromLTWH(0, goalY, size.width, size.height - goalY);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GoalAreaPainter oldDelegate) {
    return oldDelegate.goal != goal || oldDelegate.maxY != maxY;
  }
}

/// Custom painter para dibujar las líneas horizontales de objetivo y media diaria
class _GoalLinesPainter extends CustomPainter {
  final double goal;
  final double avgCalories;
  final double maxY;
  final int dataLength;

  _GoalLinesPainter({
    required this.goal,
    required this.avgCalories,
    required this.maxY,
    required this.dataLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calcular posiciones Y (el eje Y en canvas es invertido)
    final goalY = size.height - (goal / maxY) * size.height;
    final avgY = size.height - (avgCalories / maxY) * size.height;
    
    // Dibujar línea del objetivo (verde, punteada)
    final goalPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    final goalPath = Path();
    goalPath.moveTo(0, goalY);
    goalPath.lineTo(size.width, goalY);
    canvas.drawPath(goalPath, goalPaint);
    
    // Dibujar línea de la media (naranja, punteada)
    final avgPaint = Paint()
      ..color = AppTheme.vividOrange
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    final avgPath = Path();
    avgPath.moveTo(0, avgY);
    avgPath.lineTo(size.width, avgY);
    canvas.drawPath(avgPath, avgPaint);
  }

  @override
  bool shouldRepaint(_GoalLinesPainter oldDelegate) {
    return oldDelegate.goal != goal || 
           oldDelegate.avgCalories != avgCalories || 
           oldDelegate.maxY != maxY;
  }
}
