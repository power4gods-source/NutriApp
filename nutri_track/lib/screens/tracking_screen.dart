import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_consumption_screen.dart';
import '../main.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
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
                  
                  // Vista diaria
                  if (_selectedPeriod == 'day') ...[
                    _buildCaloriesCard(),
                    const SizedBox(height: 20),
                    _buildDailyChart(),
                    const SizedBox(height: 20),
                    _buildNutritionBreakdown(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Vista semanal
                  if (_selectedPeriod == 'week') ...[
                    _buildWeeklyChart(),
                    const SizedBox(height: 20),
                    _buildNutritionBreakdown(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Vista mensual
                  if (_selectedPeriod == 'month') ...[
                    _buildMonthlyChartWidget(),
                    const SizedBox(height: 20),
                    _buildNutritionBreakdown(),
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
      color: Colors.white,
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
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
                      color: remaining > 0 ? Colors.grey[700] : Colors.orange,
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
                percentage > 1.0 ? Colors.orange : const Color(0xFF4CAF50),
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
                              color: consumed > goal ? Colors.orange : const Color(0xFF4CAF50),
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
              // Barra gris con objetivo y media (más oscura) - mismo tamaño que las barras de consumo
              SizedBox(
                width: goalBarWidth,
                height: barHeight,
                child: Stack(
                  children: [
                    // Barra gris completa (objetivo)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (goal / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Barra más oscura dentro (media)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (avg / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Etiquetas
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'Meta: ${goal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Media: ${avg.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Gráfico semanal (lunes a domingo)
  Widget _buildWeeklyChart() {
    if (_weeklyDailyData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final goal = _goalCalories;
    final maxCalories = _weeklyDailyData.map((d) => d['calories'] as double).reduce((a, b) => a > b ? a : b);
    final maxY = ((maxCalories * 1.2).clamp(goal * 1.1, goal * 1.5)).toDouble();
    final avgCalories = _weeklyDailyData.map((d) => d['calories'] as double).reduce((a, b) => a + b) / _weeklyDailyData.length;
    final barHeight = 250.0;
    final goalBarWidth = 35.0; // Tamaño fijo para barras de meta/media
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
          Text(
            'Calorías Semanales',
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
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
                      barGroups: _weeklyDailyData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dayData = entry.value;
                        final calories = dayData['calories'] as double;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: calories,
                              color: calories > goal ? Colors.orange : const Color(0xFF4CAF50),
                              width: goalBarWidth, // Mismo tamaño que barras de meta/media
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Barra gris con objetivo y media (más oscura) - mismo tamaño que las barras de consumo
              SizedBox(
                width: goalBarWidth,
                height: barHeight,
                child: Stack(
                  children: [
                    // Barra gris completa (objetivo)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (goal / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Barra más oscura dentro (media)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (avgCalories / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Etiquetas
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'Meta: ${goal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Media: ${avgCalories.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Gráfico mensual (días del mes)
  Widget _buildMonthlyChartWidget() {
    if (_monthlyDailyData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final goal = _goalCalories;
    final maxCalories = _monthlyDailyData.map((d) => d['calories'] as double).reduce((a, b) => a > b ? a : b);
    final maxY = ((maxCalories * 1.2).clamp(goal * 1.1, goal * 1.5)).toDouble();
    final avgCalories = _monthlyDailyData.map((d) => d['calories'] as double).reduce((a, b) => a + b) / _monthlyDailyData.length;
    final barHeight = 250.0;
    final goalBarWidth = 12.0; // Tamaño fijo para barras de meta/media
    
    // Calcular ancho de barras diarias basado en espacio disponible
    // Mantener tamaño fijo de barras de meta/media, ajustar barras diarias al espacio restante
    final availableWidth = MediaQuery.of(context).size.width - 80; // Ancho disponible menos márgenes
    final goalBarSpace = goalBarWidth + 16; // Ancho de barra de meta + espacio
    final dailyBarsSpace = availableWidth - goalBarSpace;
    final dailyBarWidth = (_monthlyDailyData.length > 0) 
        ? (dailyBarsSpace / _monthlyDailyData.length).clamp(8.0, 20.0) 
        : 12.0; // Ancho dinámico pero con límites
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                    helpText: 'Seleccionar día inicio',
                  );
                  
                  if (startPicked != null) {
                    final endPicked = await showDatePicker(
                      context: context,
                      initialDate: endDate.isBefore(startPicked) ? startPicked : endDate,
                      firstDate: startPicked,
                      lastDate: DateTime.now(),
                      helpText: 'Seleccionar día fin',
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
                                    // Mostrar día y mes si cambia de mes, o cada 5 días
                                    final isFirstOfMonth = day == 1;
                                    final isEvery5Days = day % 5 == 0;
                                    final isLast = value.toInt() == _monthlyDailyData.length - 1;
                                    
                                    if (isFirstOfMonth || isEvery5Days || isLast) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          isFirstOfMonth && day == 1
                                              ? '${day}/${month}'
                                              : day.toString(),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    }
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
                      barGroups: _monthlyDailyData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dayData = entry.value;
                        final calories = dayData['calories'] as double;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: calories,
                              color: calories > goal ? Colors.orange : const Color(0xFF4CAF50),
                              width: dailyBarWidth, // Ancho dinámico ajustado al espacio disponible
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Barra gris con objetivo y media (más oscura) - tamaño fijo
              SizedBox(
                width: goalBarWidth,
                height: barHeight,
                child: Stack(
                  children: [
                    // Barra gris completa (objetivo)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (goal / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Barra más oscura dentro (media)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: goalBarWidth,
                        height: (avgCalories / maxY) * barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Etiquetas
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'Meta: ${goal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Media: ${avgCalories.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          _buildNutritionItemWithProgress('Carbohidratos', carbs, carbsGoal, 'g', Colors.orange),
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
                _loadGoals();
                setState(() {}); // Refresh UI
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Objetivo de calorías actualizado'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al actualizar objetivo'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
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
                _loadGoals();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Objetivos actualizados'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al actualizar objetivos'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
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
                color: percentage > 1.0 ? Colors.orange : Colors.grey[600],
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
              percentage > 1.0 ? Colors.orange : color,
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
          color: Colors.white,
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
      ..color = Colors.orange
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
