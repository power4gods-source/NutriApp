import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/firebase_user_service.dart';
import '../config/app_config.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final AuthService _authService = AuthService();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  final TextEditingController _itemController = TextEditingController();
  List<ShoppingItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.userId;
      
      // 1. Intentar cargar desde Firebase primero
      if (userId != null) {
        try {
          final userData = await _firebaseUserService.getUserData(userId);
          if (userData != null && userData['shopping_list'] != null) {
            final itemsList = userData['shopping_list'] as List;
            setState(() {
              _items = itemsList.map<ShoppingItem>((item) {
                if (item is Map<String, dynamic>) {
                  return ShoppingItem.fromJson(item);
                } else {
                  return ShoppingItem.fromJson(Map<String, dynamic>.from(item as Map));
                }
              }).toList();
              _isLoading = false;
            });
            
            // Guardar localmente como backup
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('shopping_list_$userId', jsonEncode(itemsList));
            return;
          }
        } catch (e) {
          print('Error cargando desde Firebase: $e');
        }
      }
      
      // 2. Intentar cargar desde el backend
      try {
        final headers = await _authService.getAuthHeaders();
        final url = await AppConfig.getBackendUrl();
        final response = await http.get(
          Uri.parse('$url/profile/shopping-list'),
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final itemsList = data['shopping_list'] ?? [];
          setState(() {
            _items = itemsList.map<ShoppingItem>((item) {
              if (item is Map<String, dynamic>) {
                return ShoppingItem.fromJson(item);
              } else {
                return ShoppingItem.fromJson(Map<String, dynamic>.from(item as Map));
              }
            }).toList();
            _isLoading = false;
          });
          
          // Sincronizar con Firebase
          if (userId != null) {
            await _firebaseUserService.syncUserShoppingList(userId, itemsList);
          }
          return;
        }
      } catch (e) {
        print('Error cargando desde backend: $e');
      }
      
      // 3. Fallback a SharedPreferences local
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = userId != null 
          ? prefs.getString('shopping_list_$userId') ?? prefs.getString('shopping_list') ?? '[]'
          : prefs.getString('shopping_list') ?? '[]';
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      setState(() {
        _items = itemsList.map<ShoppingItem>((item) {
          if (item is Map<String, dynamic>) {
            return ShoppingItem.fromJson(item);
          } else {
            return ShoppingItem.fromJson(Map<String, dynamic>.from(item as Map));
          }
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading shopping list: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveItems() async {
    try {
      final userId = _authService.userId;
      final itemsJson = _items.map((item) => item.toJson()).toList();
      
      // Guardar localmente primero
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setString('shopping_list_$userId', jsonEncode(itemsJson));
      }
      await prefs.setString('shopping_list', jsonEncode(itemsJson));
      
      // Sincronizar con Firebase
      if (userId != null) {
        await _firebaseUserService.syncUserShoppingList(userId, itemsJson);
      }
      
      // Intentar guardar en el backend también
      try {
        final headers = await _authService.getAuthHeaders();
        final url = await AppConfig.getBackendUrl();
        final response = await http.put(
          Uri.parse('$url/profile/shopping-list'),
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'shopping_list': itemsJson}),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          print('✅ Cesta de la compra guardada en backend');
        }
      } catch (e) {
        print('⚠️ Backend no disponible, guardado solo en Firebase/local: $e');
      }
    } catch (e) {
      print('Error saving shopping list: $e');
    }
  }

  void _addItem() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _items.add(ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isChecked: false,
        createdAt: DateTime.now(),
      ));
    });
    _itemController.clear();
    _saveItems();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index].isChecked = !_items[index].isChecked;
    });
    _saveItems();
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _saveItems();
  }

  void _editItem(int index) {
    final item = _items[index];
    _itemController.text = item.text;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar item'),
        content: TextField(
          controller: _itemController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre del item',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _itemController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = _itemController.text.trim();
              if (newText.isNotEmpty) {
                setState(() {
                  _items[index].text = newText;
                });
                _saveItems();
              }
              _itemController.clear();
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lista de Compra',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_items.any((item) => item.isChecked))
            TextButton(
              onPressed: () {
                setState(() {
                  _items.removeWhere((item) => item.isChecked);
                });
                _saveItems();
              },
              child: const Text(
                'Limpiar',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add item field
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemController,
                          decoration: InputDecoration(
                            hintText: 'Agregar item a la lista...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                // Items list
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tu lista está vacía',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Agrega items para comenzar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _deleteItem(index),
                              child: Container(
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
                                child: ListTile(
                                  leading: Checkbox(
                                    value: item.isChecked,
                                    onChanged: (_) => _toggleItem(index),
                                    activeColor: const Color(0xFF4CAF50),
                                  ),
                                  title: Text(
                                    item.text,
                                    style: TextStyle(
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isChecked
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editItem(index),
                                        color: Colors.grey[600],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () => _deleteItem(index),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class ShoppingItem {
  final String id;
  String text;
  bool isChecked;
  final DateTime createdAt;

  ShoppingItem({
    required this.id,
    required this.text,
    required this.isChecked,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isChecked': isChecked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      text: json['text'],
      isChecked: json['isChecked'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}



