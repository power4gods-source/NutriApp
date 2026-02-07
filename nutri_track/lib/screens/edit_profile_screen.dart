import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../utils/password_validator.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  Uint8List? _selectedImageBytes;
  String? _currentAvatarUrl;
  String? _previousAvatarUrl; // Para revertir la foto
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showPasswordFields = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      
      final response = await http.get(
        Uri.parse('$url/profile'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _usernameController.text = data['username'] ?? _authService.username ?? '';
          _currentAvatarUrl = data['avatar_url'];
          _previousAvatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _usernameController.text = _authService.username ?? '';
        _currentAvatarUrl = _authService.avatarUrl;
        _previousAvatarUrl = _authService.avatarUrl;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _previousAvatarUrl ??= _currentAvatarUrl;
          _selectedImageBytes = bytes;
        });
        await _uploadAndSaveAvatar(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sube la imagen y guarda automáticamente en el perfil
  Future<void> _uploadAndSaveAvatar(Uint8List imageBytes) async {
    setState(() => _isSaving = true);
    try {
      final uploadedUrl = await _uploadImageToFirebase(imageBytes);
      if (uploadedUrl != null && mounted) {
        await _saveAvatarToProfile(uploadedUrl);
        setState(() {
          _currentAvatarUrl = uploadedUrl;
          _selectedImageBytes = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        setState(() => _selectedImageBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir la imagen'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedImageBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAvatarToProfile(String avatarUrl) async {
    final headers = await _authService.getAuthHeaders();
    final url = await AppConfig.getBackendUrl();
    await http.put(
      Uri.parse('$url/profile'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'avatar_url': avatarUrl}),
    ).timeout(const Duration(seconds: 10));
    await _authService.saveAvatarUrl(avatarUrl);
    await _authService.reloadAuthData();
  }

  /// Restaura la foto anterior
  Future<void> _revertAvatar() async {
    if (_previousAvatarUrl == null && _selectedImageBytes == null) return;
    setState(() => _isSaving = true);
    try {
      final urlToRestore = _previousAvatarUrl ?? '';
      await _saveAvatarToProfile(urlToRestore);
      if (mounted) {
        setState(() {
          _currentAvatarUrl = urlToRestore;
          _selectedImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto restaurada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al revertir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<String?> _uploadImageToFirebase(Uint8List imageBytes) async {
    try {
      final userId = _authService.userId ?? '';
      final fileName = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
  
  Future<void> _saveUsername() async {
    if (_isSaving) return;
    final newUsername = _usernameController.text.trim();
    setState(() => _isSaving = true);
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      final response = await http.put(
        Uri.parse('$url/profile'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'username': newUsername}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await _updateUsernameInUsers(newUsername);
        await _authService.reloadAuthData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nombre actualizado'), backgroundColor: Colors.green),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error['detail'] ?? 'Error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<void> _updateUsernameInUsers(String newUsername) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      
      // Endpoint para actualizar username en users.json
      final response = await http.put(
        Uri.parse('$url/profile/username'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': newUsername}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Username actualizado en users.json');
      }
    } catch (e) {
      print('⚠️ Error actualizando username en users.json: $e');
      // No es crítico, continuar
    }
  }
  
  Future<void> _changePassword() async {
    final pwdError = PasswordValidator.validate(_newPasswordController.text);
    if (pwdError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pwdError), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      
      final response = await http.post(
        Uri.parse('$url/profile/password'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contraseña actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _showPasswordFields = false;
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          });
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error['detail'] ?? 'Error al cambiar contraseña'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error changing password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  ImageProvider? _getAvatarImage() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      return NetworkImage(_currentAvatarUrl!);
    }
    return null;
  }
  
  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: _getAvatarImage(),
                child: _getAvatarImage() == null
                    ? Text(
                        (_authService.username ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20, color: Color(0xFF4CAF50)),
                    onPressed: _pickImage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _pickImage,
            child: const Text('Cambiar foto de perfil'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil'),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final canRevertAvatar = _selectedImageBytes != null ||
        (_currentAvatarUrl != null &&
            _previousAvatarUrl != null &&
            _currentAvatarUrl != _previousAvatarUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          if (canRevertAvatar)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              tooltip: 'Revertir foto',
              onPressed: _isSaving ? null : _revertAvatar,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildAvatarSection(),
            const SizedBox(height: 32),
            
            // Username - se guarda automáticamente al terminar de editar
            TextField(
              controller: _usernameController,
              onEditingComplete: _saveUsername,
              decoration: InputDecoration(
                labelText: 'Nombre de usuario',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Se guarda automáticamente',
              ),
            ),
            const SizedBox(height: 24),
            
            // Cambiar contraseña toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Switch(
                  value: _showPasswordFields,
                  onChanged: (value) {
                    setState(() {
                      _showPasswordFields = value;
                      if (!value) {
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      }
                    });
                  },
                  activeColor: const Color(0xFF4CAF50),
                ),
              ],
            ),
            
            // Campos de contraseña - se guarda al pulsar Cambiar contraseña
            if (_showPasswordFields) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Mín. 8 chars, 1 mayúscula, 1 especial',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _changePassword,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Cambiar contraseña'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
