import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://localhost:8000/profile/notifications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _settings = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final updatedSettings = Map<String, dynamic>.from(_settings);
      updatedSettings[key] = value;

      final response = await http.put(
        Uri.parse('http://localhost:8000/profile/notifications'),
        headers: headers,
        body: jsonEncode(updatedSettings),
      );

      if (response.statusCode == 200) {
        setState(() {
          _settings = updatedSettings;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuración actualizada')),
          );
        }
      }
    } catch (e) {
      print('Error updating setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar')),
        );
      }
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
          'Notificaciones',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('General'),
                _buildSwitchTile(
                  'Notificaciones push',
                  'Recibe notificaciones en tu dispositivo',
                  _settings['push_notifications'] ?? true,
                  (value) => _updateSetting('push_notifications', value),
                ),
                _buildSwitchTile(
                  'Notificaciones por email',
                  'Recibe notificaciones por correo electrónico',
                  _settings['email_notifications'] ?? true,
                  (value) => _updateSetting('email_notifications', value),
                ),
                
                const Divider(),
                
                _buildSectionHeader('Recetas'),
                _buildSwitchTile(
                  'Nuevas recetas',
                  'Notificaciones cuando se publiquen nuevas recetas',
                  _settings['new_recipes'] ?? true,
                  (value) => _updateSetting('new_recipes', value),
                ),
                _buildSwitchTile(
                  'Recetas favoritas',
                  'Notificaciones sobre tus recetas favoritas',
                  _settings['favorite_recipes'] ?? true,
                  (value) => _updateSetting('favorite_recipes', value),
                ),
                
                const Divider(),
                
                _buildSectionHeader('Social'),
                _buildSwitchTile(
                  'Comentarios',
                  'Notificaciones cuando alguien comente',
                  _settings['comments'] ?? true,
                  (value) => _updateSetting('comments', value),
                ),
                _buildSwitchTile(
                  'Seguimientos',
                  'Notificaciones cuando alguien te siga',
                  _settings['follows'] ?? true,
                  (value) => _updateSetting('follows', value),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4CAF50),
    );
  }
}
