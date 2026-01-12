import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../main.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    
    try {
      // Intentar cargar desde el backend primero
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      try {
        final response = await http.get(
          Uri.parse('$url/profiles/all'),
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List) {
            setState(() {
              _profiles = List<Map<String, dynamic>>.from(data);
              _isLoading = false;
            });
            return;
          } else if (data is Map && data['profiles'] != null) {
            setState(() {
              _profiles = List<Map<String, dynamic>>.from(data['profiles']);
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('Error cargando perfiles desde backend: $e');
      }
      
      // Fallback: cargar desde profiles.json local si está disponible
      // En producción, esto se haría desde Firebase
      setState(() {
        _profiles = [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando perfiles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAvatar(String? avatarUrl, String username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {
          // Si falla la carga, mostrar inicial
        },
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF4CAF50),
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
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
            final mainNavState = MainNavigationScreen.of(context);
            if (mainNavState != null) {
              mainNavState.setCurrentIndex(2); // Volver a Inicio
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Amigos',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
            onPressed: _loadProfiles,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay perfiles disponibles',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los perfiles de usuarios aparecerán aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];
                      final username = profile['username'] ?? 
                                     profile['display_name'] ?? 
                                     profile['email']?.split('@')[0] ?? 
                                     'Usuario';
                      final avatarUrl = profile['avatar_url'];
                      
                      // Omitir el perfil del usuario actual
                      if (profile['user_id'] == _authService.userId) {
                        return const SizedBox.shrink();
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: _buildAvatar(avatarUrl, username),
                          title: Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: profile['bio'] != null && 
                                   (profile['bio'] as String).isNotEmpty
                              ? Text(
                                  profile['bio'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            // TODO: Navegar al perfil del usuario
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Perfil de $username'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
