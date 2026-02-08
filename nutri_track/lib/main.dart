import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/firebase_user_service.dart';
import 'config/app_config.dart';
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
    print('⚠️ Firebase no inicializado (ejecuta flutterfire configure en nutri_track): $e');
  }

  // 2. Locale data para DateFormat
  try {
    await initializeDateFormatting('es', null);
    print('✅ Locale data inicializado (español)');
  } catch (e) {
    print('⚠️ Error al inicializar locale data: $e');
  }

  runApp(const NutriTrackApp());
}

class NutriTrackApp extends StatelessWidget {
  const NutriTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'NutriTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          primaryColor: const Color(0xFF4CAF50),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            primary: const Color(0xFF4CAF50),
            secondary: const Color(0xFF26A69A),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
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
    
    // 5. Si hay usuario autenticado, cargar solo SUS datos desde el backend
    if (_isAuthenticated && userId != null) {
      try {
        print('👤 Cargando datos del usuario desde el backend...');
        final authService = AuthService();
        authService.refreshUserDataFromBackend().then((_) {
          print('✅ Datos del usuario actualizados');
        }).catchError((e) {
          print('⚠️ Error cargando datos del usuario: $e');
        });
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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            selectedItemColor: const Color(0xFF4CAF50),
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
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

