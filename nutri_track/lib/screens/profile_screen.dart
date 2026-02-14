import 'package:flutter/material.dart';
import '../config/app_theme.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      backgroundColor: AppTheme.primary,
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
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Más información',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _buildFeatureBlockIcon(
                context,
                Icons.info_outline,
                '¿Qué es CooKind?',
                'Cookind es el asistente definitivo que transforma tu cocina en un espacio de creatividad e inteligencia nutricional. Con un catálogo infinito de recetas y una IA avanzada, hacemos que conviertas cualquier ingrediente olvidado en un banquete digno de restaurante. Olvídate de las conjeturas: cada bocado se traduce en un seguimiento preciso de tus macronutrientes para que alcances tus metas físicas sin sacrificar el sabor. Podrás construir tu propia biblioteca culinaria digital, diciendo adiós para siempre al caos de las capturas de pantalla perdidas. Además, la experiencia se vuelve social al permitirte influir en tu comunidad y descubrir las recomendaciones favoritas de tu círculo cercano. Es la herramienta perfecta para quienes buscan variedad, control total sobre sus objetivos y una pizca de inspiración diaria. Todo lo que necesitas para dominar tu alimentación está a un solo toque de distancia. Cocina con propósito, come con placer y comparte tu éxito con el mundo.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.restaurant_menu,
                'De ingredientes a banquete',
                '"Vacía tu nevera sin tirar nada." Solo dinos qué tienes muerto de risa en el cajón de las verduras o la nevera, y nuestra IA cocinará por ti. Convierte tres ingredientes olvidados en una cena digna de restaurante en segundos. Encuéntralo en Inicio > Buscador de recetas o en la pestaña Recetas.',
              ),
              _buildFeatureBlockIcon(
                context,
                Icons.pie_chart_outline,
                'Tu cuerpo, bajo control',
                '"Come con propósito, no con dudas." Olvídate de las conjeturas; obtén un desglose preciso de proteínas, grasas y carbohidratos en cada bocado. Registra lo que comes para alcanzar tus metas físicas mientras disfrutas de la comida, sabiendo exactamente qué hay en tu plato. Ve a Seguimiento > Agregar consumo. Busca o escanea alimentos y registra tus comidas para ver el desglose al instante.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.menu_book,
                'Tu recetario personal',
                '"Crea la biblioteca culinaria de tus sueños." Despídete de los pantallazos perdidos en la galería de fotos. Guarda, organiza y revive esos platos que te enamoraron con un solo toque, listos para cuando el hambre apriete.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.group,
                'Cocina en comunidad',
                '"Presume de plato y contagia el sabor." No guardes el secreto de esa salsa increíble solo para ti. Envía tus mejores descubrimientos a tus amigos o familia con un clic y disfruta con tu grupo.',
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Necesitas ayuda o tienes sugerencias?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escríbenos y te responderemos lo antes posible.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Escribe tu consulta, sugerencia o lo que necesites...',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                        backgroundColor: AppTheme.primary,
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

  Widget _buildFeatureBlockIcon(BuildContext context, IconData icon, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreInfoDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Colors.white24, thickness: 1, height: 1),
    );
  }
}


