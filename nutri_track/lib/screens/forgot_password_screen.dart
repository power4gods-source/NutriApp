import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/password_validator.dart';
import 'login_screen.dart';

/// Pantalla unificada de recuperación de contraseña:
/// Paso 1: Introducir email y enviar código
/// Paso 2: Introducir código del email, nueva contraseña y confirmar. Guardar -> volver a login
class ForgotPasswordScreen extends StatefulWidget {
  /// Si true, muestra directamente el paso 2 (código + nueva contraseña). Para "Ya tengo el token".
  final bool showCodeStep;
  /// Token pre-rellenado (ej. desde enlace)
  final String? initialToken;

  const ForgotPasswordScreen({
    super.key,
    this.showCodeStep = false,
    this.initialToken,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    if (widget.showCodeStep) _step = 2;
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _codeController.text = widget.initialToken!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.forgotPassword(_emailController.text.trim());
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Revisa tu correo. Introduce el código que te enviamos.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      setState(() => _step = 2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.resetPassword(
      _codeController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Código inválido o expirado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_step == 1 ? 'Recuperar contraseña' : 'Nueva contraseña'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() {
    return [
      const SizedBox(height: 16),
      Text(
        'Introduce el email con el que te registraste. Te enviaremos un código para restablecer tu contraseña.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Email',
          filled: true,
          fillColor: AppTheme.fillLight(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primary),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Introduce tu email';
          if (!v.contains('@')) return 'Email no válido';
          return null;
        },
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _sendCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Enviar código'),
      ),
    ];
  }

  List<Widget> _buildStep2() {
    return [
      const SizedBox(height: 16),
      Text(
        'Introduce el código que te enviamos por email y tu nueva contraseña.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _codeController,
        decoration: InputDecoration(
          labelText: 'Código del email',
          hintText: 'Pega el código del correo o el token del enlace',
          filled: true,
          fillColor: AppTheme.fillLight(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppTheme.primary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Introduce el código' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Nueva contraseña',
          filled: true,
          fillColor: AppTheme.fillLight(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) => PasswordValidator.validate(v),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmController,
        obscureText: _obscureConfirm,
        decoration: InputDecoration(
          labelText: 'Confirmar contraseña',
          filled: true,
          fillColor: AppTheme.fillLight(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: (v) {
          if (v != _passwordController.text) return 'Las contraseñas no coinciden';
          return null;
        },
      ),
      if (!widget.showCodeStep) ...[
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: Text('Cambiar email', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
        ),
      ],
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _savePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Guardar nueva contraseña'),
      ),
    ];
  }
}
