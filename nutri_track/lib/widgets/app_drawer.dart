import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/recipes_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';
import '../main.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final email = authService.email ?? 'Usuario';
    final username = authService.username ?? email.split('@')[0];

    final phone = authService.phone ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : null,
      child: Column(
        children: [
          // Header: foto, nombre, email, teléfono
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
            ),
            child: Column(
              children: [
                _buildAvatar(context, authService.avatarUrl, username),
                const SizedBox(height: 12),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.person,
                  title: 'Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.restaurant_menu,
                  title: 'Mis recetas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecipesScreen(forceFilter: 'private'),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications,
                  title: 'Notificaciones',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Ajustes',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => SwitchListTile(
                    secondary: const Icon(Icons.dark_mode, color: AppTheme.primary),
                    title: const Text(
                      'Modo oscuro',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleDarkMode(),
                    activeColor: AppTheme.primary,
                  ),
                ),
                const Divider(),
                
                // Logout
                _buildDrawerItem(
                  context,
                  icon: Icons.logout,
                  title: 'Cerrar sesión',
                  textColor: AppTheme.vividRed,
                  onTap: () async {
                    Navigator.pop(context);
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl, String username) {
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: 40,
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
      backgroundImage: hasImage ? NetworkImage(avatarUrl!) : null,
      child: hasImage
          ? null
          : Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
    );
  }
}




