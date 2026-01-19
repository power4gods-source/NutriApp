import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../config/app_config.dart';
import 'supabase_user_service.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _email;
  String? _username;
  String? _role;
  
  static const String _localUsersKey = 'local_users';
  final SupabaseUserService _supabaseUserService = SupabaseUserService();
  
  /// Obtiene la URL del backend configurada
  Future<String> get baseUrl async => await AppConfig.getBackendUrl();
  
  String? get token => _token;
  String? get userId => _userId;
  String? get email => _email;
  String? get username => _username;
  String? get role => _role;
  bool get isAuthenticated => _token != null;
  bool get isAdmin => _role == 'admin';

  AuthService() {
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _email = prefs.getString('user_email');
    _username = prefs.getString('username');
    _role = prefs.getString('user_role');
    // Si el email es power4gods@gmail.com, asegurar que sea admin
    if (_email == 'power4gods@gmail.com' && _role != 'admin') {
      _role = 'admin';
      await prefs.setString('user_role', 'admin');
    }
    print('🔄 Datos de autenticación recargados: userId=$_userId, email=$_email, token=${_token != null ? "${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}..." : "null"}');
    notifyListeners();
  }
  
  // Método público para recargar datos de autenticación
  Future<void> reloadAuthData() async {
    await _loadAuthData();
  }

  Future<void> _saveAuthData(String token, String userId, String email, String? username, {String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    print('💾 Guardando datos de autenticación: userId=$userId, email=$email');
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('user_email', email);
    if (username != null) {
      await prefs.setString('username', username);
    }
    // Determinar el rol: admin para power4gods@gmail.com, user para el resto
    final userRole = role ?? (email == 'power4gods@gmail.com' ? 'admin' : 'user');
    await prefs.setString('user_role', userRole);
    _token = token;
    _userId = userId;
    _email = email;
    _username = username;
    _role = userRole;
    print('✅ Datos de autenticación guardados: token=${token.substring(0, token.length > 20 ? 20 : token.length)}..., role=$userRole');
    notifyListeners();
  }

  /// Verifica si el backend está disponible
  Future<bool> isBackendAvailable() async {
    try {
      final url = await baseUrl;
      final response = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 3)); // Reducido a 3 segundos para respuesta más rápida
      return response.statusCode == 200;
    } catch (e) {
      // Backend no disponible - esto es normal en móvil sin PC encendido
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    // Siempre intentar primero con el backend
    final backendAvailable = await isBackendAvailable();
    
    if (backendAvailable) {
      // Usar backend si está disponible
      try {
        final url = await baseUrl;
        final response = await http
            .post(
              Uri.parse('$url/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email,
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _saveAuthData(
            data['access_token'],
            data['user_id'],
            data['email'],
            null,
            role: data['role'] ?? (data['email'] == 'power4gods@gmail.com' ? 'admin' : 'user'),
          );
          return {'success': true, 'data': data};
        } else {
          final error = jsonDecode(response.body);
          return {'success': false, 'error': error['detail'] ?? 'Login failed'};
        }
      } catch (e) {
        // Si hay un error de conexión, verificar si hay credenciales guardadas
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('user_email');
        if (savedEmail == email && _token != null) {
          // Usar credenciales guardadas
          await _loadAuthData();
          return {
            'success': true,
            'data': {
              'email': _email,
              'user_id': _userId,
              'message': 'Modo offline: usando credenciales guardadas'
            },
            'offline': true
          };
        }
        // Si falla el backend, intentar con Supabase primero, luego local
        return await _loginSupabase(email, password);
      }
    } else {
      // Backend no disponible, intentar Supabase primero, luego local
      return await _loginSupabase(email, password);
    }
  }
  
  /// Login desde Supabase (sin backend)
  Future<Map<String, dynamic>> _loginSupabase(String email, String password) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final passwordHash = _hashPassword(password);
      
      // Verificar credenciales en Supabase Storage
      // Usamos el hash de la contraseña para mantener compatibilidad
      final isValid = await _supabaseUserService.verifyUser(normalizedEmail, passwordHash);
      
      if (isValid) {
        // Obtener userId
        final userId = await _supabaseUserService.getUserIdFromEmail(normalizedEmail);
        if (userId == null) {
          throw Exception('Usuario no encontrado en Supabase');
        }
        
        // Obtener datos del usuario
        final userData = await _supabaseUserService.getUser(userId);
        final username = userData?['username'] ?? normalizedEmail.split('@')[0];
        
        // Intentar hacer login en el backend para obtener JWT válido
        String? jwtToken;
        try {
          final url = await baseUrl;
          print('🔄 Intentando login en backend después de login en Supabase...');
          final loginResponse = await http.post(
            Uri.parse('$url/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': normalizedEmail,
              'password': password,
            }),
          ).timeout(const Duration(seconds: 5));
          
          if (loginResponse.statusCode == 200) {
            final loginData = jsonDecode(loginResponse.body);
            jwtToken = loginData['access_token'];
            print('✅ Login en backend exitoso, JWT obtenido');
          } else {
            print('⚠️ Login en backend falló: ${loginResponse.statusCode}');
            // Si el usuario no existe, intentar registrar
            if (loginResponse.statusCode == 401 || loginResponse.statusCode == 404) {
              print('🔄 Usuario no existe en backend, intentando registrar...');
              try {
                final registerResponse = await http.post(
                  Uri.parse('$url/auth/register'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': normalizedEmail,
                    'password': password,
                    'username': username,
                  }),
                ).timeout(const Duration(seconds: 5));
                
                if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
                  final registerData = jsonDecode(registerResponse.body);
                  jwtToken = registerData['access_token'];
                  print('✅ Usuario registrado en backend, JWT obtenido');
                }
              } catch (e) {
                print('⚠️ Error al registrar en backend: $e');
              }
            }
          }
        } catch (e) {
          print('⚠️ No se pudo hacer login/registro en backend: $e');
        }
        
        // Usar JWT del backend si está disponible, sino usar token local
        final token = jwtToken ?? _generateLocalToken(userId, normalizedEmail);
        
        if (jwtToken == null) {
          print('❌ ADVERTENCIA: No se pudo obtener JWT del backend');
          print('❌ El token local NO funcionará para endpoints protegidos');
        }
        
        final role = normalizedEmail == 'power4gods@gmail.com' ? 'admin' : 'user';
        await _saveAuthData(token, userId, normalizedEmail, username, role: role);
        
        // Cargar datos del usuario desde Supabase
        await _loadUserDataFromSupabase(userId);
        
        return {
          'success': true,
          'data': {
            'email': normalizedEmail,
            'user_id': userId,
            'username': username,
            'access_token': token,
          },
          'supabase': true,
          'jwt_token': jwtToken != null,  // Indicar si se obtuvo JWT válido
        };
      } else {
        // Si no es válido en Supabase, intentar login local
        return await _loginLocal(email, password);
      }
    } catch (e) {
      print('Error en login Supabase: $e');
      // Fallback a login local
      return await _loginLocal(email, password);
    }
  }
  
  /// Carga datos del usuario desde Supabase
  Future<void> _loadUserDataFromSupabase(String userId) async {
    try {
      final userData = await _supabaseUserService.getUser(userId);
      if (userData != null) {
        print('✅ Datos del usuario cargados desde Supabase');
        // Guardar datos localmente para acceso rápido
        final prefs = await SharedPreferences.getInstance();
        
        // Guardar ingredientes
        if (userData['ingredients'] != null) {
          await prefs.setString('ingredients_$userId', jsonEncode(userData['ingredients']));
          print('✅ Ingredientes cargados: ${(userData['ingredients'] as List).length}');
        }
        
        // Guardar favoritos
        if (userData['favorites'] != null) {
          await prefs.setString('favorites_$userId', jsonEncode(userData['favorites']));
          print('✅ Favoritos cargados: ${(userData['favorites'] as List).length}');
        }
        
        // Guardar objetivos
        if (userData['goals'] != null) {
          await prefs.setString('goals_$userId', jsonEncode(userData['goals']));
          print('✅ Objetivos cargados');
        }
        
        // Guardar cesta de la compra
        if (userData['shopping_list'] != null) {
          await prefs.setString('shopping_list_$userId', jsonEncode(userData['shopping_list']));
          print('✅ Lista de compra cargada: ${(userData['shopping_list'] as List).length}');
        }
        
        // Guardar recetas privadas (referencias)
        if (userData['private_recipes'] != null) {
          await prefs.setString('private_recipes_$userId', jsonEncode(userData['private_recipes']));
          print('✅ Recetas privadas cargadas: ${(userData['private_recipes'] as List).length}');
        }
        
        print('✅ Datos del usuario cargados desde Supabase');
      }
    } catch (e) {
      print('Error cargando datos del usuario desde Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, {String? username}) async {
    // Siempre intentar primero con el backend
    final backendAvailable = await isBackendAvailable();
    
    if (backendAvailable) {
      // Usar backend si está disponible
      try {
        final url = await baseUrl;
        print('🔄 Intentando registrar en backend: $url/auth/register');
        
        // Intentar con timeout más largo y reintentos
        http.Response? response;
        Exception? lastError;
        
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            print('🔄 Intento $attempt/3 de registro en backend...');
            response = await http
                .post(
                  Uri.parse('$url/auth/register'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': email,
                    'password': password,
                    if (username != null) 'username': username,
                  }),
                )
                .timeout(const Duration(seconds: 60)); // Timeout más largo para Render
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              break; // Éxito, salir del loop
            } else if (response.statusCode != 500 && response.statusCode != 502 && response.statusCode != 503) {
              // Si no es un error de servidor, no reintentar
              break;
            }
            print('⚠️ Intento $attempt falló con status ${response.statusCode}, reintentando...');
            await Future.delayed(Duration(seconds: attempt * 2)); // Esperar antes de reintentar
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            print('⚠️ Error en intento $attempt: $e');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2)); // Esperar antes de reintentar
            }
          }
        }
        
        if (response == null) {
          throw lastError ?? Exception('No se pudo conectar al backend después de 3 intentos');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final userId = data['user_id'];
          final accessToken = data['access_token'];
          final userEmail = data['email'] ?? email;
          final userName = data['username'] ?? username ?? email.split('@')[0];
          final userRole = data['role'] ?? (data['email'] == 'power4gods@gmail.com' ? 'admin' : 'user');
          
          print('✅ Registro exitoso en backend:');
          print('   - userId: $userId');
          print('   - email: $userEmail');
          print('   - username: $userName');
          print('   - role: $userRole');
          print('   - token (primeros 30 chars): ${accessToken.substring(0, accessToken.length > 30 ? 30 : accessToken.length)}...');
          
          // Guardar datos de autenticación PRIMERO
          await _saveAuthData(
            accessToken,
            userId,
            userEmail,
            userName,
            role: userRole,
          );
          
          // CRÍTICO: Recargar el token inmediatamente para que esté disponible
          await _loadAuthData();
          
          // Verificar que el token se guardó correctamente
          final prefs = await SharedPreferences.getInstance();
          final savedToken = prefs.getString('auth_token');
          if (savedToken == accessToken) {
            print('✅ Token guardado y verificado correctamente');
          } else {
            print('⚠️ ADVERTENCIA: Token guardado no coincide con el recibido');
          }
          
          // Registrar también en Supabase (en segundo plano, no bloquea)
          final passwordHash = _hashPassword(password);
          _supabaseUserService.registerUser(
            userId: userId,
            email: email,
            passwordHash: passwordHash,
            username: username ?? userName,
          ).then((success) {
            if (success) {
              print('✅ Usuario también registrado en Supabase Storage');
            } else {
              print('⚠️ No se pudo registrar en Supabase Storage (el backend ya lo tiene)');
            }
          }).catchError((e) {
            print('⚠️ Error al registrar en Supabase (no crítico, el backend ya lo tiene): $e');
          });
          
          print('✅ Usuario registrado correctamente, token guardado y recargado');
          
          return {'success': true, 'data': data};
        } else {
          print('❌ Registro falló con status: ${response.statusCode}');
          print('❌ Response body: ${response.body}');
          final error = jsonDecode(response.body);
          return {'success': false, 'error': error['detail'] ?? 'Registration failed'};
        }
      } catch (e) {
        print('❌ Error al registrar en backend: $e');
        print('🔄 Intentando registro en Supabase como fallback...');
        // Si falla el backend, intentar registro en Supabase directamente
        return await _registerSupabase(email, password, username: username);
      }
    } else {
      // Backend no disponible, registrar directamente en Supabase
      return await _registerSupabase(email, password, username: username);
    }
  }
  
  /// Registro en Supabase (sin backend)
  Future<Map<String, dynamic>> _registerSupabase(String email, String password, {String? username}) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      
      // Verificar si el usuario ya existe en Supabase
      final existingUserId = await _supabaseUserService.getUserIdFromEmail(normalizedEmail);
      if (existingUserId != null) {
        return {
          'success': false,
          'error': 'Este email ya está registrado. Por favor, inicia sesión.'
        };
      }
      
      // Validar contraseña
      if (password.length < 6) {
        return {
          'success': false,
          'error': 'La contraseña debe tener al menos 6 caracteres.'
        };
      }
      
      // Crear nuevo usuario
      final userId = _generateUserId(normalizedEmail);
      final passwordHash = _hashPassword(password);
      
      // Registrar en Supabase (con timeout extendido para operaciones críticas)
      bool supabaseSuccess = false;
      try {
        print('🔄 Registrando en Supabase con timeout extendido (60s)...');
        supabaseSuccess = await _supabaseUserService.registerUser(
          userId: userId,
          email: normalizedEmail,
          passwordHash: passwordHash,
          username: username ?? normalizedEmail.split('@')[0],
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('⚠️ Timeout al registrar en Supabase (60s)');
            return false;
          },
        );
        
        if (supabaseSuccess) {
          print('✅ Usuario registrado exitosamente en Supabase');
        } else {
          print('⚠️ Fallo al registrar en Supabase, pero continuando con registro local y backend');
        }
      } catch (e) {
        print('❌ Error al registrar en Supabase: $e');
        supabaseSuccess = false;
      }
      
      // Continuar con el registro local y backend incluso si Supabase falla
      // Esto asegura que el usuario pueda usar la app aunque Supabase tenga problemas
      
      // Guardar también localmente para acceso rápido
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_localUsersKey);
      Map<String, dynamic> users = {};
      if (usersJson != null) {
        users = jsonDecode(usersJson) as Map<String, dynamic>;
      }
      
      users[normalizedEmail] = {
        'email': normalizedEmail,
        'password': passwordHash,
        'user_id': userId,
        'username': username ?? normalizedEmail.split('@')[0],
        'created_at': DateTime.now().toIso8601String(),
        'supabase_synced': true,
      };
      await prefs.setString(_localUsersKey, jsonEncode(users));
      
      // CRÍTICO: Intentar registrar en el backend para obtener JWT válido
      // Aumentar timeout y manejar errores mejor con reintentos
      String? backendToken;
      try {
        final url = await baseUrl;
        print('🔄 Registrando en backend para obtener JWT válido: $url/auth/register');
        
        // Intentar con reintentos
        http.Response? registerResponse;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            print('🔄 Intento $attempt/3 de registro en backend...');
            registerResponse = await http.post(
              Uri.parse('$url/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': normalizedEmail,
                'password': password,
                if (username != null) 'username': username,
              }),
            ).timeout(
              const Duration(seconds: 60),  // Timeout más largo para Render
              onTimeout: () {
                throw TimeoutException('Timeout al registrar en backend (60s)');
              },
            );
            
            if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
              break; // Éxito
            } else if (registerResponse.statusCode == 400 || registerResponse.statusCode == 409) {
              // Usuario ya existe, no reintentar
              break;
            } else if (registerResponse.statusCode != 500 && registerResponse.statusCode != 502 && registerResponse.statusCode != 503) {
              // Otro error no relacionado con servidor, no reintentar
              break;
            }
            print('⚠️ Intento $attempt falló con status ${registerResponse.statusCode}, reintentando...');
            await Future.delayed(Duration(seconds: attempt * 2));
          } catch (e) {
            print('⚠️ Error en intento $attempt: $e');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          }
        }
        
        if (registerResponse != null) {
          if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
            final registerData = jsonDecode(registerResponse.body);
            backendToken = registerData['access_token'];
            print('✅ Usuario registrado en backend, JWT obtenido: ${backendToken?.substring(0, 20)}...');
          } else {
            print('⚠️ Registro en backend falló: ${registerResponse.statusCode} - ${registerResponse.body}');
            // Si el usuario ya existe (400/409), intentar login
            if (registerResponse.statusCode == 400 || registerResponse.statusCode == 409) {
              print('🔄 Usuario ya existe, intentando login...');
              try {
                final loginResponse = await http.post(
                  Uri.parse('$url/auth/login'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': normalizedEmail,
                    'password': password,
                  }),
                ).timeout(const Duration(seconds: 60));
                
                if (loginResponse.statusCode == 200) {
                  final loginData = jsonDecode(loginResponse.body);
                  backendToken = loginData['access_token'];
                  print('✅ Login exitoso, JWT obtenido: ${backendToken?.substring(0, 20)}...');
                } else {
                  print('❌ Login falló: ${loginResponse.statusCode} - ${loginResponse.body}');
                }
              } catch (e) {
                print('❌ Error al hacer login: $e');
              }
            }
          }
        }
      } catch (e) {
        print('❌ ERROR: No se pudo registrar/login en el backend después de 3 intentos: $e');
        print('❌ El usuario tendrá un token local que NO funcionará con el backend');
      }
      
      // CRÍTICO: Si no hay token del backend, NO guardar token local
      // En su lugar, forzar al usuario a hacer login cuando el backend esté disponible
      if (backendToken == null) {
        print('❌ CRÍTICO: No se obtuvo token JWT del backend');
        print('❌ El usuario NO podrá usar funciones que requieren autenticación');
        print('ℹ️ SOLUCIÓN: El usuario debe hacer LOGIN cuando el backend esté disponible');
        print('ℹ️ El backend puede estar "spinning down" - espera 30-60 segundos y vuelve a intentar');
        
        // NO guardar token local - forzar login
        return {
          'success': false,
          'error': 'Backend no disponible. Por favor, intenta hacer login cuando el backend esté disponible.',
          'requires_login': true,
        };
      }
      
      // Usar el token del backend (ya verificado que existe)
      print('✅ Token JWT válido obtenido del backend');
      final role = normalizedEmail == 'power4gods@gmail.com' ? 'admin' : 'user';
      await _saveAuthData(backendToken, userId, normalizedEmail, username ?? normalizedEmail.split('@')[0], role: role);
      
      return {
        'success': true,
        'data': {
          'email': normalizedEmail,
          'user_id': userId,
          'username': username ?? normalizedEmail.split('@')[0],
          'access_token': token,
        },
        'supabase': true,
        'jwt_token': backendToken != null,  // Indicar si se obtuvo token JWT válido
        'offline_mode': backendToken == null, // Indicar que está en modo offline
      };
    } catch (e) {
      print('Error en registro Supabase: $e');
      // Fallback a registro local
      return await _registerLocal(email, password, username: username);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('username');
    await prefs.remove('user_role');
    _token = null;
    _userId = null;
    _email = null;
    _username = null;
    _role = null;
    notifyListeners();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    
    if (token == null) {
      print('⚠️ No hay token disponible en getAuthHeaders');
      return {
        'Content-Type': 'application/json',
      };
    }
    
    print('🔑 Token disponible para usuario: $userId (primeros 20 chars: ${token.substring(0, token.length > 20 ? 20 : token.length)}...)');
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Intenta refrescar el token automáticamente cuando expira
  /// Retorna true si se pudo refrescar, false si no
  /// Nota: Actualmente no se puede refrescar sin contraseña, pero este método
  /// puede ser extendido en el futuro si se implementa un endpoint de refresh token
  Future<bool> tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      
      if (email == null) {
        print('❌ No hay email guardado para refrescar token');
        return false;
      }
      
      // Verificar que el usuario existe en Firebase
      final normalizedEmail = email.toLowerCase().trim();
      final userId = await _supabaseUserService.getUserIdFromEmail(normalizedEmail);
      
      if (userId == null) {
        print('❌ Usuario no encontrado en Supabase');
        return false;
      }
      
      // Por ahora, no podemos refrescar el token sin la contraseña original
      // En el futuro, se podría implementar un endpoint de refresh token en el backend
      print('⚠️ No se puede refrescar token automáticamente sin contraseña');
      print('ℹ️ El usuario debe cerrar sesión y volver a iniciar sesión');
      
      return false;
    } catch (e) {
      print('❌ Error en tryRefreshToken: $e');
      return false;
    }
  }

  /// Login local (sin backend)
  Future<Map<String, dynamic>> _loginLocal(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar usuarios locales
      final usersJson = prefs.getString(_localUsersKey);
      if (usersJson == null) {
        return {
          'success': false,
          'error': 'No hay usuarios registrados localmente. Por favor, regístrate primero.'
        };
      }
      
      final users = jsonDecode(usersJson) as Map<String, dynamic>;
      final normalizedEmail = email.toLowerCase().trim();
      
      // Buscar usuario
      if (!users.containsKey(normalizedEmail)) {
        return {
          'success': false,
          'error': 'Email o contraseña incorrectos.'
        };
      }
      
      final userData = users[normalizedEmail] as Map<String, dynamic>;
      final savedPassword = userData['password'] as String;
      
      // Verificar contraseña (SHA256 hash)
      final passwordHash = _hashPassword(password);
      if (passwordHash != savedPassword) {
        return {
          'success': false,
          'error': 'Email o contraseña incorrectos.'
        };
      }
      
      // Login exitoso - crear token local
      final userId = userData['user_id'] as String;
      final username = userData['username'] as String?;
      final localToken = _generateLocalToken(userId, email);
      
      final role = email == 'power4gods@gmail.com' ? 'admin' : 'user';
      await _saveAuthData(localToken, userId, email, username, role: role);
      
      return {
        'success': true,
        'data': {
          'email': email,
          'user_id': userId,
          'username': username,
          'access_token': localToken,
        },
        'offline': true
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al iniciar sesión: $e'
      };
    }
  }

  /// Registro local (sin backend)
  Future<Map<String, dynamic>> _registerLocal(String email, String password, {String? username}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedEmail = email.toLowerCase().trim();
      
      // Cargar usuarios locales
      final usersJson = prefs.getString(_localUsersKey);
      Map<String, dynamic> users = {};
      if (usersJson != null) {
        users = jsonDecode(usersJson) as Map<String, dynamic>;
      }
      
      // Verificar si el usuario ya existe
      if (users.containsKey(normalizedEmail)) {
        return {
          'success': false,
          'error': 'Este email ya está registrado. Por favor, inicia sesión.'
        };
      }
      
      // Validar contraseña
      if (password.length < 6) {
        return {
          'success': false,
          'error': 'La contraseña debe tener al menos 6 caracteres.'
        };
      }
      
      // Crear nuevo usuario
      final userId = _generateUserId(normalizedEmail);
      final passwordHash = _hashPassword(password);
      
      users[normalizedEmail] = {
        'email': normalizedEmail,
        'password': passwordHash,
        'user_id': userId,
        'username': username ?? normalizedEmail.split('@')[0],
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Guardar usuarios
      await prefs.setString(_localUsersKey, jsonEncode(users));
      
      // Intentar hacer login en el backend para obtener token válido
      String? backendToken;
      try {
        final url = await baseUrl;
        final loginResponse = await http.post(
          Uri.parse('$url/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': normalizedEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));
        
        if (loginResponse.statusCode == 200) {
          final loginData = jsonDecode(loginResponse.body);
          backendToken = loginData['access_token'];
          print('✅ Token del backend obtenido después del registro local');
        }
      } catch (e) {
        print('⚠️ No se pudo obtener token del backend (puede no estar disponible): $e');
      }
      
      // Usar token del backend si está disponible, sino usar token local
      final token = backendToken ?? _generateLocalToken(userId, normalizedEmail);
      final role = normalizedEmail == 'power4gods@gmail.com' ? 'admin' : 'user';
      await _saveAuthData(token, userId, normalizedEmail, username ?? normalizedEmail.split('@')[0], role: role);
      
      return {
        'success': true,
        'data': {
          'email': normalizedEmail,
          'user_id': userId,
          'username': username ?? normalizedEmail.split('@')[0],
          'access_token': token,
        },
        'offline': true
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al registrar: $e'
      };
    }
  }

  /// Genera un hash SHA256 de la contraseña (compatible con el backend)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Genera un ID de usuario único
  String _generateUserId(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_');
  }

  /// Genera un token local simple
  String _generateLocalToken(String userId, String email) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    final tokenData = '$userId:$email:$timestamp:$random';
    return base64Encode(utf8.encode(tokenData));
  }
}





