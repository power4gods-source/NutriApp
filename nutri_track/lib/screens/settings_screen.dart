import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/pronto_badge.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Cuenta'),
          _buildSettingsTile(
            context,
            icon: Icons.lock,
            title: 'Contraseña',
            subtitle: 'Cambiar contraseña',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
            showPronto: false,
          ),
          
          const Divider(),
          
          // Soporte / Donaciones
          _buildSectionHeader('Soporte'),
          _buildSettingsTile(
            context,
            icon: Icons.volunteer_activism,
            title: 'Donar a la app',
            subtitle: 'Apoyar el desarrollo de NutriTrack',
            onTap: () => _showProntoSnack(context),
            showPronto: true,
          ),
          
          const Divider(),
          
          // App Section
          _buildSectionHeader('Aplicación'),
          _buildSettingsTile(
            context,
            icon: Icons.info,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('NutriTrack'),
                  content: const Text('Aplicación de recetas y nutrición\nVersión 1.0.0'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: 'Más info',
            subtitle: 'Preguntas frecuentes y sugerencias',
            onTap: () => _showMoreInfo(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.shield,
            title: 'Términos y condiciones',
            subtitle: 'Legales y uso de la app',
            onTap: () => _showProntoSnack(context),
            showPronto: true,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.share,
            title: 'Invitar amigos',
            subtitle: 'Comparte NutriTrack',
            onTap: () => _showProntoSnack(context),
            showPronto: true,
          ),
          
          const Divider(),
          
          // Danger Zone
          _buildSectionHeader('Zona de peligro'),
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            title: 'Eliminar cuenta',
            subtitle: 'Eliminar permanentemente tu cuenta',
            textColor: Colors.red,
            onTap: () => _showProntoSnack(context, msg: 'Pronto...'),
            showPronto: true,
          ),
          
          const SizedBox(height: 24),
          
          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
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
          
          const SizedBox(height: 32),
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

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    bool showPronto = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? const Color(0xFF4CAF50)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPronto) const ProntoBadge(),
          if (showPronto) const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showProntoSnack(BuildContext context, {String msg = 'Pronto...'}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  void _showMoreInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Más información',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildQaItem(
                '¿Qué es NutriTrack?',
                'NutriTrack es una aplicación para gestionar tu nutrición: recetas, seguimiento de calorías, ingredientes favoritos y lista de la compra.',
              ),
              _buildQaItem(
                '¿Cómo añado consumo?',
                'Desde el icono de calorías en la barra superior, o en Seguimiento > Agregar consumo. Puedes registrar comidas por fecha y tipo.',
              ),
              _buildQaItem(
                '¿Dónde están mis favoritos?',
                'Tus recetas favoritas están en Perfil > Favoritos, y también en Recetas > Filtro Favoritas.',
              ),
              _buildQaItem(
                '¿Cómo cambio mi foto de perfil?',
                'Ve a Perfil > Editar perfil. Pulsa el icono de cámara sobre tu foto para seleccionar una imagen nueva.',
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Necesitas ayuda o tienes sugerencias?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escríbenos y te responderemos lo antes posible.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Escribe tu consulta, sugerencia o lo que necesites...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gracias. Recibiremos tu mensaje pronto.'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQaItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D6A4F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _showProntoSnack(context, msg: 'Pronto...');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}







