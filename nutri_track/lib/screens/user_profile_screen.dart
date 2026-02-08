import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'recipe_detail_screen.dart';
import 'chat_screen.dart';

/// Pantalla que muestra el perfil público de otro usuario y sus recetas publicadas.
class UserProfileScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
    this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _recipes = [];
  Set<String> _failedImageIds = {};
  bool _loading = true;
  bool _isConnection = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRecipes();
  }

  Future<void> _loadProfile() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http
          .get(
            Uri.parse('$url/profiles/${widget.targetUserId}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        setState(() {
          _profile = Map<String, dynamic>.from(data['profile'] ?? {});
          _isConnection = _profile?['is_connection'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando perfil: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecipes() async {
    try {
      final url = await AppConfig.getBackendUrl();
      final resp = await http
          .get(
            Uri.parse('$url/recipes/public/user/${widget.targetUserId}'),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        final list = (data['recipes'] as List?) ?? [];
        setState(() {
          _recipes = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Perfil', style: TextStyle(color: Colors.black87)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final username = _profile?['username'] ?? _profile?['display_name'] ?? widget.targetUsername;
    final avatarUrl = _profile?['avatar_url'] ?? widget.avatarUrl ?? '';
    final followersCount = _profile?['followers_count'] ?? 0;
    final recipesCount = _recipes.length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          username,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadRecipes();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header del perfil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Colors.white,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: _getAvatarColor(widget.targetUserId),
                      backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                          ? NetworkImage(avatarUrl.toString())
                          : null,
                      child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                          ? Text(
                              username.toString().isNotEmpty ? username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(Icons.people, '$followersCount seguidores'),
                        const SizedBox(width: 24),
                        _buildStatChip(Icons.restaurant_menu, '$recipesCount recetas'),
                      ],
                    ),
                    if (_isConnection) ...[
                      const SizedBox(height: 16),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4CAF50), size: 32),
                        tooltip: 'Chatear',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: widget.targetUserId,
                                otherUsername: username.toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Recetas publicadas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recetas publicadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_recipes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Sin recetas publicadas',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    return _buildRecipeCard(_recipes[index]);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final recipeId = (recipe['id'] ?? recipe['title'] ?? '').toString();
    final title = (recipe['title'] ?? 'Receta').toString();
    final time = recipe['time_minutes'] ?? '-';
    final difficulty = (recipe['difficulty'] ?? '-').toString();
    final imageUrl = (recipe['image_url']?.toString() ?? '').trim();
    final hasValidImage = imageUrl.isNotEmpty && !_failedImageIds.contains(recipeId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: hasValidImage
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          if (mounted) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _failedImageIds.add(recipeId));
                            });
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$time min · $difficulty',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$time min · $difficulty',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
