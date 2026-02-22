import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/firebase_user_service.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipe_finder_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/coming_soon_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase (Spark) - inicializar antes que nada
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics no está soportado en web; solo registrar errores en móvil/desktop
    if (!kIsWeb) {
      FlutterError.onError = (error) {
        try {
          if (!kIsWeb) FirebaseCrashlytics.instance.recordFlutterFatalError(error);
        } catch (_) {}
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        try {
          if (!kIsWeb) FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {}
        return true;
      };
    }
    print('✅ Firebase inicializado (Spark)');
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}
  } catch (e) {
    print('⚠️ Firebase no inicializado (ejecuta flutterfire configure en Cookind): $e');
  }

  // 2. Supabase Auth (Google OAuth)
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    print('✅ Supabase inicializado');
  } catch (e) {
    print('⚠️ Supabase no inicializado (verifica supabaseUrl y supabaseAnonKey en AppConfig): $e');
  }

  // 3. Locale data para DateFormat
  try {
    await initializeDateFormatting('es', null);
    print('✅ Locale data inicializado (español)');
  } catch (e) {
    print('⚠️ Error al inicializar locale data: $e');
  }

  runApp(const CooKindApp());
}

class CooKindApp extends StatelessWidget {
  const CooKindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'CooKind',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppTheme.primary,
          scaffoldBackgroundColor: AppTheme.scaffoldBackground,
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            secondary: AppTheme.ecoSage,
            onSecondary: Colors.white,
            surface: AppTheme.surface,
            onSurface: Colors.white,  // Para AppBar y barras sobre fondo verde
            onSurfaceVariant: Colors.white70,
            error: AppTheme.vividRed,
            onError: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.surface,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          cardTheme: CardThemeData(
            color: AppTheme.cardBackground,
            elevation: 2,
            shadowColor: AppTheme.primary.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.cardBorder, width: 1),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppTheme.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppTheme.primary,
          scaffoldBackgroundColor: AppTheme.darkScaffoldBackground,
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            secondary: AppTheme.ecoSage,
            surface: AppTheme.darkSurface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppTheme.darkTextPrimary,
            onSurfaceVariant: AppTheme.darkTextSecondary,
            onError: Colors.white,
            error: AppTheme.vividRed,
            outline: AppTheme.darkCardBorder,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.darkSurface,
            foregroundColor: AppTheme.darkTextPrimary,
            elevation: 0,
            scrolledUnderElevation: 2,
          ),
          cardTheme: CardThemeData(
            color: AppTheme.darkCardBackground,
            elevation: 2,
            shadowColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.darkCardBorder, width: 1),
            ),
          ),
          dividerColor: AppTheme.darkDivider,
          listTileTheme: const ListTileThemeData(
            textColor: AppTheme.darkTextPrimary,
            iconColor: AppTheme.darkTextSecondary,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: AppTheme.darkSurface,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: AppTheme.darkCardBackground,
            labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
            hintStyle: TextStyle(color: AppTheme.darkTextTertiary),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppTheme.darkCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppTheme.darkTextPrimary),
            bodyMedium: TextStyle(color: AppTheme.darkTextPrimary),
            bodySmall: TextStyle(color: AppTheme.darkTextSecondary),
            titleLarge: TextStyle(color: AppTheme.darkTextPrimary, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(color: AppTheme.darkTextPrimary, fontWeight: FontWeight.w600),
            titleSmall: TextStyle(color: AppTheme.darkTextPrimary),
            labelLarge: TextStyle(color: AppTheme.darkTextPrimary),
            labelMedium: TextStyle(color: AppTheme.darkTextSecondary),
            labelSmall: TextStyle(color: AppTheme.darkTextTertiary),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        themeMode: ThemeMode.light,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔄 Inicializando aplicación...');
    
    // 1. Intentar detectar y conectar con el backend PRIMERO
    print('🌐 Intentando detectar backend...');
    try {
      final detectedUrl = await AppConfig.detectBackendUrl();
      if (detectedUrl != null) {
        print('✅ Backend detectado y configurado: $detectedUrl');
      } else {
        print('⚠️ Backend no detectado - la app funcionará en modo offline');
      }
    } catch (e) {
      print('⚠️ Error detectando backend: $e');
    }
    
    // 2. Verificar autenticación
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final email = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
    
    print('📱 Estado de autenticación: ${_isAuthenticated ? "Autenticado" : "No autenticado"}');
    if (email != null) {
      print('📧 Email del usuario: $email');
    }
    
    // 3. Si hay usuario autenticado, verificar token con backend
    if (_isAuthenticated) {
      final authService = AuthService();
      try {
        print('🔄 Verificando conexión con backend...');
        final backendAvailable = await authService.isBackendAvailable();
        
        if (backendAvailable) {
          print('✅ Backend disponible - token será validado en la primera petición');
        } else {
          print('⚠️ Backend no disponible - usando datos locales y Firebase');
        }
      } catch (e) {
        print('⚠️ Error verificando backend: $e');
      }
    }
    
    // 4. Sincronizar solo datos generales (recetas, foods) desde Firestore para cache
    try {
      final firebaseSyncService = FirebaseSyncService();
      print('☁️ Sincronizando datos generales (recetas, alimentos)...');
      firebaseSyncService.downloadGeneralJsonFiles().then((data) {
        if (data.isNotEmpty) {
          print('✅ Datos generales sincronizados: ${data.length} archivos');
          firebaseSyncService.saveToLocalCache(data);
        }
      }).catchError((e) {
        print('⚠️ Error sincronizando datos generales: $e');
      });
    } catch (e) {
      print('⚠️ Error al inicializar FirebaseSyncService: $e');
    }
    
    // 5. Si hay usuario autenticado, cargar datos y registrar FCM
    if (_isAuthenticated && userId != null) {
      try {
        print('👤 Cargando datos del usuario desde el backend...');
        final authService = AuthService();
        authService.refreshUserDataFromBackend().then((_) {
          print('✅ Datos del usuario actualizados');
        }).catchError((e) {
          print('⚠️ Error cargando datos del usuario: $e');
        });
        FcmService.registerFcmToken(authService);
      } catch (e) {
        print('⚠️ Error al cargar datos del usuario: $e');
      }
    }
    
    setState(() {
      _isLoading = false;
    });
    
    print('✅ Inicialización completada');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return _isAuthenticated 
        ? const MainNavigationScreen()
        : const LoginScreen();
  }
}

/// Llamar cuando se añade consumo para que HomeScreen refresque
void Function()? notifyConsumptionAdded;

/// Llamar cuando se actualizan objetivos para que HomeScreen y TrackingScreen refresquen
void Function()? notifyGoalsUpdated;

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();

  static _MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationScreenState>();
  }
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Start at "Inicio" (index 2)

  final List<Widget> _screens = [
    const RecipesScreen(),        // Index 0: Recetas
    const TrackingScreen(),       // Index 1: Seguimiento
    const HomeScreen(),           // Index 2: Inicio
    const FriendsScreen(),        // Index 3: Amigos
    const ComingSoonScreen(title: 'Compartir', subtitle: 'Comparte recetas y fotos. Disponible en una próxima actualización.'),  // Index 4: Compartir
  ];

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book),
                label: 'Recetas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.track_changes),
                label: 'Seguimiento',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Amigos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt),
                label: 'Compartir',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

