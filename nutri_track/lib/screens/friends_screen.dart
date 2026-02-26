import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../main.dart';
import '../config/app_theme.dart';
import '../utils/snackbar_utils.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'chats_list_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> _followingProfiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  int _followersCount = 0;
  int _connectionsCount = 0;
  Set<String> _connectionIds = {};
  bool _isPublic = true;  // true = público (visible en Explorar), false = oculto
  /// user_id -> número de mensajes no leídos en ese chat
  Map<String, int> _unreadByUserId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterProfiles(List<Map<String, dynamic>> profiles) {
    if (_searchQuery.isEmpty) return profiles;
    return profiles.where((p) {
      final username = (p['username'] ?? p['display_name'] ?? p['email']?.split('@')[0] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      return username.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadAllProfiles(),
        _loadFollowingProfiles(),
        _loadStats(),
        _loadConnections(),
        _loadMyVisibility(),
        _loadChatInbox(),
      ]);
    } catch (e) {
      print('❌ Error cargando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChatInbox() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http.get(Uri.parse('$url/chat/inbox'), headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final list = (data['conversations'] as List?) ?? [];
        final map = <String, int>{};
        for (final c in list) {
          final m = c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{};
          final otherId = (m['other_user_id'] ?? '').toString();
          final unread = (m['unread_count'] ?? 0) as int;
          if (otherId.isNotEmpty) map[otherId] = unread;
        }
        setState(() => _unreadByUserId = map);
      }
    } catch (e) {
      print('❌ Error cargando inbox: $e');
    }
  }

  Future<void> _loadConnections() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http.get(Uri.parse('$url/profile/connections'), headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final conns = (data['connections'] as List?) ?? [];
        setState(() {
          _connectionIds = conns
              .map((e) => (e as Map)['user_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        });
      }
    } catch (e) {
      print('❌ Error cargando conexiones: $e');
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
        
        // Filtrar admin (power4gods@gmail.com) de la lista
        profilesList = profilesList.where((profile) {
          final email = (profile['email'] ?? '').toString().toLowerCase();
          final role = (profile['role'] ?? 'user').toString().toLowerCase();
          return email != 'power4gods@gmail.com' && role != 'admin';
        }).toList();
        
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

  Future<void> _loadMyVisibility() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http.get(Uri.parse('$url/profile'), headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final v = (data['visibility'] ?? 'public').toString().toLowerCase();
        setState(() => _isPublic = v != 'hidden');
      }
    } catch (e) {
      print('❌ Error cargando visibilidad: $e');
    }
  }

  Future<void> _updateVisibility(bool isPublic) async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http.put(
        Uri.parse('$url/profile'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'visibility': isPublic ? 'public' : 'hidden'}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        setState(() => _isPublic = isPublic);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPublic ? 'Ahora otros pueden encontrarte en Explorar' : 'Ahora estás oculto en Explorar'),
              backgroundColor: Colors.green,
              duration: kErrorSnackBarDuration,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Error al actualizar visibilidad');
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
        showErrorSnackBar(context, 'Error al actualizar seguimiento');
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

  void _openProfile(Map<String, dynamic> profile) {
    final username = profile['username'] ??
        profile['display_name'] ??
        profile['email']?.split('@')[0] ??
        'Usuario';
    final userId = profile['user_id'] ?? '';
    final avatarUrl = profile['avatar_url'] ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          targetUserId: userId,
          targetUsername: username.toString(),
          avatarUrl: avatarUrl.toString().isNotEmpty ? avatarUrl.toString() : null,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openChat(String userId, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: userId,
          otherUsername: username,
        ),
      ),
    ).then((_) {
      _loadData();
      MainNavigationScreen.of(context)?.refreshUnreadChatsCount();
    });
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
    final isConnection = _connectionIds.contains(userId);
    final unreadCount = _unreadByUserId[userId] ?? 0;

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
            InkWell(
              onTap: () => _openProfile(profile),
              borderRadius: BorderRadius.circular(28),
              child: _buildAvatar(avatarUrl, username, userId),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _openProfile(profile),
                borderRadius: BorderRadius.circular(12),
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
            ),
            // Acciones: si es conexión → Siguiendo + icono chat (con badge); si no → Seguir/Siguiendo
            if (isConnection)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _toggleFollow(userId, isFollowing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textTertiary(context),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Siguiendo',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4CAF50), size: 28),
                        tooltip: 'Chatear',
                        onPressed: () => _openChat(userId, username.toString()),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => _toggleFollow(userId, isFollowing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? AppTheme.textTertiary(context) : AppTheme.primary,
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

  Widget _buildStatsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Izquierda: switch activar/desactivar
          Switch.adaptive(
            value: _isPublic,
            onChanged: (v) => _updateVisibility(v),
            activeColor: Colors.white,
          ),
          const SizedBox(width: 8),
          // Centro: texto Abierto/Privado
          Text(
            _isPublic ? 'Abierto' : 'Privado',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Derecha: contadores
          _buildStatItem(context, 'Te siguen', _followersCount),
          const SizedBox(width: 20),
          _buildStatItem(context, 'Conexiones', _connectionsCount),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
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
            final mainNavState = MainNavigationScreen.of(context);
            if (mainNavState != null) {
              mainNavState.setCurrentIndex(2);
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Comunidad',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsHeader(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar amigos o explorar...',
                hintStyle: const TextStyle(color: Color(0xFF333333)),
                prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4CAF50),
            unselectedLabelColor: const Color(0xFFE8E8E8),
            indicatorColor: const Color(0xFF4CAF50),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Tu círculo'),
              Tab(text: 'Explorar'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                // Tab: Amigos (Following)
                _filterProfiles(_followingProfiles).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty ? Icons.person_add_outlined : Icons.search_off,
                              size: 80,
                              color: const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'Aún no sigues a nadie' : 'No hay coincidencias',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFFE8E8E8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty ? 'Explora usuarios y comienza a seguir' : 'Prueba con otro término de búsqueda',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE8E8E8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filterProfiles(_followingProfiles).length,
                          itemBuilder: (context, index) {
                            final profile = _filterProfiles(_followingProfiles)[index];
                            profile['is_following'] = true;
                            return _buildProfileCard(profile);
                          },
                        ),
                      ),
                
                // Tab: Explorar (All Profiles)
                _filterProfiles(_allProfiles).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                              size: 80,
                              color: const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No hay perfiles disponibles' : 'No hay coincidencias',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFFE8E8E8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty ? 'Los perfiles de usuarios aparecerán aquí' : 'Prueba con otro término de búsqueda',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE8E8E8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filterProfiles(_allProfiles).length,
                          itemBuilder: (context, index) {
                            return _buildProfileCard(_filterProfiles(_allProfiles)[index]);
                          },
                        ),
                      ),
                  ],
                ),
                // FAB para abrir lista de chats
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatsListScreen()),
                      ).then((_) => _loadData());
                    },
                    backgroundColor: AppTheme.primary,
                    tooltip: 'Conversaciones',
                    child: const Icon(Icons.chat_bubble, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
