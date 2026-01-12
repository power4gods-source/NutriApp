import 'package:flutter/material.dart';
import '../screens/recipes_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/ingredients_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../main.dart';

class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchSuggestion> _suggestions = [];
  final List<SearchSuggestion> _allSuggestions = [
    SearchSuggestion(
      keyword: 'ingredientes',
      title: 'Ingredientes',
      subtitle: 'Gestiona tus ingredientes',
      icon: Icons.restaurant,
      route: (context) => const IngredientsScreen(),
      aliases: ['ingred', 'ingrediente', 'alimentacion', 'alimentación', 'comida'],
    ),
    SearchSuggestion(
      keyword: 'recetas',
      title: 'Recetas',
      subtitle: 'Explora recetas',
      icon: Icons.menu_book,
      route: (context) => const RecipesScreen(),
      aliases: ['receta', 'cocina', 'platos'],
    ),
    SearchSuggestion(
      keyword: 'seguimiento',
      title: 'Seguimiento',
      subtitle: 'Rastrea tu nutrición',
      icon: Icons.track_changes,
      route: (context) => const TrackingScreen(),
      aliases: ['tracking', 'nutricion', 'nutrición', 'calorias', 'calorías'],
    ),
    SearchSuggestion(
      keyword: 'favoritos',
      title: 'Favoritos',
      subtitle: 'Tus recetas favoritas',
      icon: Icons.favorite,
      route: (context) => const FavoritesScreen(),
      aliases: ['favorito', 'guardados'],
    ),
    SearchSuggestion(
      keyword: 'perfil',
      title: 'Perfil',
      subtitle: 'Tu perfil de usuario',
      icon: Icons.person,
      route: (context) => const ProfileScreen(),
      aliases: ['usuario', 'cuenta'],
    ),
    SearchSuggestion(
      keyword: 'notificaciones',
      title: 'Notificaciones',
      subtitle: 'Configura notificaciones',
      icon: Icons.notifications,
      route: (context) => const NotificationsScreen(),
      aliases: ['notificacion', 'avisos'],
    ),
    SearchSuggestion(
      keyword: 'ajustes',
      title: 'Ajustes',
      subtitle: 'Configuración de la app',
      icon: Icons.settings,
      route: (context) => const SettingsScreen(),
      aliases: ['configuracion', 'configuración', 'opciones'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _suggestions = _allSuggestions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = _allSuggestions;
      });
      return;
    }

    setState(() {
      _suggestions = _allSuggestions.where((suggestion) {
        // Check keyword
        if (suggestion.keyword.toLowerCase().contains(query)) {
          return true;
        }
        // Check title
        if (suggestion.title.toLowerCase().contains(query)) {
          return true;
        }
        // Check aliases
        if (suggestion.aliases.any((alias) => alias.toLowerCase().contains(query))) {
          return true;
        }
        return false;
      }).toList();
    });
  }

  void _navigateToSuggestion(SearchSuggestion suggestion) {
    Navigator.pop(context);
    
    // Check if we need to navigate to a bottom nav screen
    final mainNavState = MainNavigationScreen.of(context);
    
    if (suggestion.keyword == 'recetas' && mainNavState != null) {
      mainNavState.setCurrentIndex(0); // Recetas is index 0
    } else if (suggestion.keyword == 'seguimiento' && mainNavState != null) {
      mainNavState.setCurrentIndex(1); // Seguimiento is index 1
    } else if (suggestion.keyword == 'ingredientes') {
      // Navigate to HomeScreen first, then to IngredientsScreen
      if (mainNavState != null) {
        mainNavState.setCurrentIndex(2); // Inicio is index 2
      }
      // Wait a bit then navigate to ingredients
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IngredientsScreen()),
          );
        }
      });
      return;
    } else {
      // Navigate to other screens normally
      Navigator.push(
        context,
        MaterialPageRoute(builder: suggestion.route),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Suggestions list
            Expanded(
              child: _suggestions.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron resultados',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              suggestion.icon,
                              color: const Color(0xFF4CAF50),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            suggestion.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            suggestion.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => _navigateToSuggestion(suggestion),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchSuggestion {
  final String keyword;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext) route;
  final List<String> aliases;

  SearchSuggestion({
    required this.keyword,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.aliases,
  });
}

