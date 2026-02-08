import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/pronto_badge.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refrescar datos del perfil al abrir (foto, teléfono, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).refreshUserDataFromBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // Avatar (misma imagen que en la homepage)
                  Builder(
                    builder: (context) {
                      final avatarUrl = authService.avatarUrl;
                      final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                          color: hasImage ? null : const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          image: hasImage
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: hasImage
                            ? null
                            : Center(
                                child: Text(
                                  (authService.username ?? 'U').isNotEmpty
                                      ? (authService.username!.substring(0, 1).toUpperCase())
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authService.username ?? 'mabalfor',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authService.email ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        if ((authService.phone ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            authService.phone!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Cuenta Section
            _buildSection(
              context,
              'Cuenta',
              [
                _buildMenuItem(
                  context,
                  'Editar perfil',
                  Icons.person,
                  const Color(0xFF4CAF50),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ),
                ),
                _buildMenuItem(
                  context,
                  'Favoritos',
                  Icons.favorite,
                  const Color(0xFF4CAF50),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ),
                ),
                _buildMenuItem(
                  context,
                  'Notificaciones',
                  Icons.notifications,
                  const Color(0xFF4CAF50),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ],
            ),
            
            // General Section
            _buildSection(
              context,
              'General',
              [
                _buildMenuItem(
                  context,
                  'Más info',
                  Icons.info,
                  const Color(0xFF4CAF50),
                  () => _showMoreInfo(context),
                ),
                _buildMenuItem(
                  context,
                  'Términos y condiciones',
                  Icons.shield,
                  const Color(0xFF4CAF50),
                  () => _showPronto(context),
                  showPronto: true,
                ),
                _buildMenuItem(
                  context,
                  'Invitar amigos',
                  Icons.share,
                  const Color(0xFF4CAF50),
                  () => _showPronto(context),
                  showPronto: true,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Logout button (más grande)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
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
                  icon: const Icon(Icons.logout, size: 24),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    Color iconColor,
    VoidCallback onTap, {
    bool showPronto = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPronto) const ProntoBadge(),
            if (showPronto) const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showPronto(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pronto...'),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                'Tus recetas favoritas están en Perfil > Favoritos, y también en Recetas > Filtro Favoritas. Puedes editar o quitar favoritos desde cada receta.',
              ),
              _buildQaItem(
                '¿Cómo cambio mi foto de perfil?',
                'Ve a Perfil > Editar perfil. Pulsa el icono de cámara sobre tu foto para seleccionar una imagen nueva.',
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Necesitas ayuda o tienes sugerencias?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}


