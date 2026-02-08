import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/password_validator.dart';
import '../main.dart';
import 'forgot_password_screen.dart';
import 'reset_password_screen.dart';
import 'terms_and_conditions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _isOver14 = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.login(
      _loginEmailController.text.trim(),
      _loginPasswordController.text,
    );
    
    setState(() => _isLoading = false);
    
    if (result['success'] == true && mounted) {
      // Usar Navigator.pushAndRemoveUntil para limpiar el stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
      // Mostrar mensaje si está en modo offline
      if (result['offline'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo offline: usando credenciales guardadas'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else if (mounted) {
      // Manejar error que puede ser String o List
      String errorMessage = 'Login failed';
      final error = result['error'];
      if (error != null) {
        if (error is String) {
          errorMessage = error;
        } else if (error is List) {
          errorMessage = error.join(', ');
        } else {
          errorMessage = error.toString();
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_acceptTerms || !_isOver14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y la Política de Privacidad, y declarar que eres mayor de 14 años.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      print('📝 Iniciando registro de usuario...');
      
      final result = await authService.register(
        _registerEmailController.text.trim(),
        _registerPasswordController.text,
        username: _registerUsernameController.text.trim().isNotEmpty
            ? _registerUsernameController.text.trim()
            : null,
        termsVersion: 'T&C v1.2',
      );
      
      print('📥 Resultado del registro: ${result['success']}');
      
      setState(() => _isLoading = false);
      
      if (result['success'] == true && mounted) {
        print('✅ Registro exitoso, navegando a la pantalla principal...');
        // Usar Navigator.pushAndRemoveUntil para limpiar el stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Usuario registrado correctamente'),
            backgroundColor: AppTheme.primary,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // Verificar si requiere login (backend no disponible)
        if (result['requires_login'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Backend no disponible. Por favor, intenta hacer login.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Hacer Login',
                textColor: Colors.white,
                onPressed: () {
                  _tabController.animateTo(0); // Cambiar a pestaña de login
                },
              ),
            ),
          );
        } else {
          final errorMessage = result['error'] ?? 'Error al registrar usuario';
          print('❌ Error en registro: $errorMessage');
          final isEmailTaken = errorMessage.toString().toLowerCase().contains('ya está registrado') ||
              errorMessage.toString().toLowerCase().contains('already registered');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage.toString()),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: isEmailTaken
                  ? SnackBarAction(
                      label: 'Iniciar sesión',
                      textColor: Colors.white,
                      onPressed: () => _tabController.animateTo(0),
                    )
                  : null,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Excepción durante el registro: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo
              const Text(
                'CooKind',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF4CAF50),
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    child: Text('Accede', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Tab(
                    child: Text('Regístrate'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Tab Content
              SizedBox(
                height: 620,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Login Tab
                    _buildLoginForm(),
                    // Register Tab
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bienvenido de vuelta!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          
          // Acepta email o nombre de usuario
          TextFormField(
            controller: _loginEmailController,
            decoration: InputDecoration(
              labelText: 'Email o nombre de usuario',
              hintText: 'ejemplo@correo.com o miusuario',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.username],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Introduce tu correo o nombre de usuario';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Password field
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Login button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Acceder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
          
          // Forgot password
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              );
            },
            child: const Text(
              'Olvidaste la contraseña?',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              );
            },
            child: Text(
              'Ya tengo el token',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          
          // Social login
          _buildSocialButton(context, 'G Continuar con Google', Icons.login, isGoogle: true),
          const SizedBox(height: 12),
          _buildSocialButton(context, 'Continuar con Apple', Icons.phone_iphone, isGoogle: false),
        ],
      ),
    );
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crea tu cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            
            // Username field
            TextFormField(
              controller: _registerUsernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Email field
            TextFormField(
              controller: _registerEmailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password field
            TextFormField(
              controller: _registerPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: 'Mín. 8 chars, 1 mayúscula, 1 especial',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) => PasswordValidator.validate(value),
            ),
            const SizedBox(height: 20),
            
            // Texto legal de protección de datos
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información básica sobre protección de datos:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Responsable: CooKind. Finalidad: Gestionar tu perfil, permitir la creación de recetas y facilitar la interacción social. '
                    'Legitimación: Consentimiento y ejecución de los Términos de Uso. Destinatarios: No se cederán datos a terceros, salvo obligación legal. '
                    'Derechos: Acceso, rectificación y supresión, detallados en nuestra Política de Privacidad.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Checkbox 1: Términos y Política
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                  activeColor: AppTheme.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4),
                        children: [
                          const TextSpan(text: 'Acepto los '),
                          TextSpan(
                            text: 'Términos y Condiciones',
                            style: const TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                            recognizer: TapGestureRecognizer()..onTap = _openTerms,
                          ),
                          const TextSpan(text: ' y la '),
                          TextSpan(
                            text: 'Política de Privacidad',
                            style: const TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                            recognizer: TapGestureRecognizer()..onTap = _openTerms,
                          ),
                          const TextSpan(text: '. Entiendo que soy el único responsable de los contenidos que publique y de las consecuencias de salud derivadas del uso de las recetas. (Obligatorio)'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Checkbox 2: Mayor de 14 años
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _isOver14,
                  onChanged: (v) => setState(() => _isOver14 = v ?? false),
                  activeColor: AppTheme.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isOver14 = !_isOver14),
                    child: Text(
                      'Declaro que soy mayor de 14 años. (Obligatorio)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Register button
            ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Registrarse', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          
          // Social login buttons
          _buildSocialButton(context, 'G Continuar con Google', Icons.login, isGoogle: true),
          const SizedBox(height: 12),
          _buildSocialButton(context, 'Continuar con Apple', Icons.phone_iphone, isGoogle: false),
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSocialLogin(BuildContext context, bool isGoogle) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() => _isLoading = true);
    final result = isGoogle
        ? await authService.loginWithGoogle()
        : await authService.loginWithApple();
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Error al iniciar sesión'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSocialButton(BuildContext context, String text, IconData icon, {required bool isGoogle}) {
    return OutlinedButton(
      onPressed: _isLoading ? null : () => _handleSocialLogin(context, isGoogle),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppTheme.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppTheme.primary)),
        ],
      ),
    );
  }
}

