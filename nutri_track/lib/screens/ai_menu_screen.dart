import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class AIMenuScreen extends StatefulWidget {
  final List<String> ingredients;

  const AIMenuScreen({super.key, required this.ingredients});

  @override
  State<AIMenuScreen> createState() => _AIMenuScreenState();
}

class _AIMenuScreenState extends State<AIMenuScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _menuSuggestions;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateMenu();
  }

  Future<void> _generateMenu() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('http://localhost:8000/ai/generate-menu'),
        headers: headers,
        body: jsonEncode({
          'ingredients': widget.ingredients,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _menuSuggestions = data;
          _isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _error = errorData['detail'] ?? 'Error al generar menú';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMenuAsFavorites() async {
    if (_menuSuggestions == null || _menuSuggestions!['menu'] == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('http://localhost:8000/ai/save-menu'),
        headers: headers,
        body: jsonEncode({
          'menu': _menuSuggestions!['menu'],
          'menu_name': 'Menú generado por IA',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menú guardado en favoritos'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['detail'] ?? 'Error al guardar menú'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Menú Generado por IA',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_menuSuggestions != null && !_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite, color: Colors.red),
              onPressed: _isSaving ? null : _saveMenuAsFavorites,
              tooltip: 'Guardar menú en favoritos',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _generateMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generando menú con IA...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateMenu,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _menuSuggestions == null
                  ? const Center(child: Text('No hay sugerencias'))
                  : Column(
                      children: [
                        // Save button at top
                        if (_menuSuggestions!['menu'] != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.white,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveMenuAsFavorites,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.favorite),
                                label: Text(_isSaving ? 'Guardando...' : 'Guardar Menú en Favoritos'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Menu content
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Ingredients used
                              Card(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (_menuSuggestions!['ai_generated'] == true)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'IA',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (_menuSuggestions!['ai_generated'] == true)
                                            const SizedBox(width: 8),
                                          const Text(
                                            'Ingredientes utilizados:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: widget.ingredients.map((ing) {
                                          return Chip(
                                            label: Text(ing),
                                            backgroundColor: Colors.white,
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Menu suggestions
                              if (_menuSuggestions!['menu'] != null)
                                ...(_menuSuggestions!['menu'] as List).map((meal) {
                                  return _buildMealCard(meal);
                                }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getMealIcon(meal['meal_type'] ?? ''),
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meal['meal_type'] ?? 'Comida',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              meal['name'] ?? 'Sin nombre',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (meal['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                meal['description'],
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            if (meal['ingredients'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Ingredientes:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: (meal['ingredients'] as List).map((ing) {
                  return Chip(
                    label: Text(ing),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: Colors.grey[200],
                  );
                }).toList(),
              ),
            ],
            if (meal['instructions'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Instrucciones:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meal['instructions'],
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
            if (meal['time_minutes'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${meal['time_minutes']} minutos',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'desayuno':
        return Icons.wb_sunny;
      case 'almuerzo':
      case 'comida':
        return Icons.lunch_dining;
      case 'cena':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }
}
