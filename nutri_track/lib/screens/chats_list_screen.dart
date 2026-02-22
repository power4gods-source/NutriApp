import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'chat_screen.dart';

/// Pantalla que muestra la lista de todos los chats abiertos (conversaciones).
class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() => _loading = true);
    try {
      final url = await AppConfig.getBackendUrl();
      final headers = await _authService.getAuthHeaders();
      final resp = await http
          .get(Uri.parse('$url/chat/inbox'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        final list = (data['conversations'] as List?) ?? [];
        setState(() {
          _conversations = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        setState(() => _conversations = []);
      }
    } catch (e) {
      if (mounted) setState(() => _conversations = []);
    } finally {
      if (mounted) setState(() => _loading = false);
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
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Conversaciones',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
            onPressed: _loadInbox,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes conversaciones',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conecta con alguien y empieza a chatear',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInbox,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      return _buildChatTile(_conversations[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> conv) {
    final otherUserId = (conv['other_user_id'] ?? '').toString();
    final otherUsername = (conv['other_username'] ?? 'Usuario').toString();
    final avatarUrl = conv['other_avatar_url']?.toString() ?? '';
    final lastMessage = conv['last_message'] as Map<String, dynamic>?;
    final unreadCount = (conv['unread_count'] ?? 0) as int;

    String lastText = '';
    if (lastMessage != null) {
      final type = (lastMessage['type'] ?? 'text').toString();
      if (type == 'recipe') {
        lastText = '📖 ${lastMessage['recipe_title'] ?? 'Receta compartida'}';
      } else {
        lastText = (lastMessage['text'] ?? '').toString();
      }
    }
    if (lastText.isEmpty) lastText = 'Sin mensajes';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: _getAvatarColor(otherUserId),
        backgroundImage: (avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                otherUsername.isNotEmpty ? otherUsername[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              )
            : null,
      ),
      title: Text(
        otherUsername,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        lastText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
        ),
      ),
      trailing: unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: otherUserId,
              otherUsername: otherUsername,
            ),
          ),
        ).then((_) => _loadInbox());
      },
    );
  }
}
