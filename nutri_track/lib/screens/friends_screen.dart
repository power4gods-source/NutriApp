import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../main.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> _followingProfiles = [];
  bool _isLoading = true;
  
  int _followersCount = 0;
  int _connectionsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadAllProfiles(),
        _loadFollowingProfiles(),
        _loadStats(),
      ]);
    } catch (e) {
      print('❌ Error cargando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllProfiles() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('$url/profiles/all'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> profilesList = [];
        
        if (data is List) {
          profilesList = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['profiles'] != null) {
          profilesList = List<Map<String, dynamic>>.from(data['profiles']);
        }
        
        setState(() {
          _allProfiles = profilesList;
        });
      }
    } catch (e) {
      print('❌ Error cargando perfiles: $e');
    }
  }

  Future<void> _loadFollowingProfiles() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('$url/profile/following'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> followingList = [];
        
        if (data is Map && data['following'] != null) {
          followingList = List<Map<String, dynamic>>.from(data['following']);
        }
        
        setState(() {
          _followingProfiles = followingList;
        });
      }
    } catch (e) {
      print('❌ Error cargando seguidos: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('$url/profile/stats'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _followersCount = data['followers_count'] ?? 0;
          _connectionsCount = data['connections_count'] ?? 0;
        });
      }
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
    }
  }

  Future<void> _toggleFollow(String targetUserId, bool currentlyFollowing) async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      
      final endpoint = currentlyFollowing 
          ? 'DELETE' 
          : 'POST';
      
      final response = endpoint == 'POST'
          ? await http.post(
              Uri.parse('$url/profile/follow/$targetUserId'),
              headers: headers,
            ).timeout(const Duration(seconds: 10))
          : await http.delete(
              Uri.parse('$url/profile/follow/$targetUserId'),
              headers: headers,
            ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Recargar datos
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(currentlyFollowing ? 'Dejaste de seguir' : 'Ahora sigues a este usuario'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error al seguir/dejar de seguir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar seguimiento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];
    
    final hash = userId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Widget _buildAvatar(String? avatarUrl, String username, String userId) {
    final avatarColor = _getAvatarColor(userId);
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {
          // Fallback to colored avatar
        },
        backgroundColor: avatarColor,
        child: avatarUrl.isEmpty ? Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ) : null,
      );
    }
    
    return CircleAvatar(
      radius: 28,
      backgroundColor: avatarColor,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final username = profile['username'] ?? 
                     profile['display_name'] ?? 
                     profile['email']?.split('@')[0] ?? 
                     'Usuario';
    final userId = profile['user_id'] ?? '';
    final avatarUrl = profile['avatar_url'] ?? '';
    final followersCount = profile['followers_count'] ?? 0;
    final publicRecipesCount = profile['public_recipes_count'] ?? 0;
    final isFollowing = profile['is_following'] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatar(avatarUrl, username, userId),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$followersCount seguidores',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(Icons.restaurant_menu, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$publicRecipesCount recetas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _toggleFollow(userId, isFollowing),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey[300] : const Color(0xFF4CAF50),
                foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: isFollowing ? 0 : 2,
              ),
              child: Text(
                isFollowing ? 'Siguiendo' : 'Seguir',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildStatItem('Te siguen', _followersCount),
          const SizedBox(width: 24),
          _buildStatItem('Conexiones', _connectionsCount),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 2),
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
              mainNavState.setCurrentIndex(2);
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
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              _buildStatsHeader(),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4CAF50),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF4CAF50),
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Amigos'),
                  Tab(text: 'Explorar'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab: Amigos (Following)
                _followingProfiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aún no sigues a nadie',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Explora usuarios y comienza a seguir',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _followingProfiles.length,
                          itemBuilder: (context, index) {
                            final profile = _followingProfiles[index];
                            profile['is_following'] = true;
                            return _buildProfileCard(profile);
                          },
                        ),
                      ),
                
                // Tab: Explorar (All Profiles)
                _allProfiles.isEmpty
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
                                fontWeight: FontWeight.w500,
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
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _allProfiles.length,
                          itemBuilder: (context, index) {
                            return _buildProfileCard(_allProfiles[index]);
                          },
                        ),
                      ),
              ],
            ),
    );
  }
}
