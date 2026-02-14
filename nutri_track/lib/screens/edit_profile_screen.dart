import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../services/firebase_storage_paths.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../utils/password_validator.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
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
          _firstNameController.text = data['first_name']?.toString().trim() ?? '';
          _lastNameController.text = data['last_name']?.toString().trim() ?? '';
          _addressController.text = data['address']?.toString().trim() ?? '';
          _phoneController.text = data['phone']?.toString().trim() ?? _authService.phone ?? '';
          _currentAvatarUrl = data['avatar_url'];
          _previousAvatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _phoneController.text = _authService.phone ?? '';
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
            duration: const Duration(seconds: 3),
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
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedImageBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAvatarToProfile(String avatarUrl) async {
    final headers = await _authService.getAuthHeaders();
    final url = await AppConfig.getBackendUrl();
    // PUT /profile actualiza avatar_url en profiles.json (sincronizado con Firebase)
    final response = await http.put(
      Uri.parse('$url/profile'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'avatar_url': avatarUrl}),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      await _authService.saveAvatarUrl(avatarUrl);
      await _authService.refreshUserDataFromBackend();
    } else {
      throw Exception('Error al guardar avatar: ${response.body}');
    }
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
          SnackBar(
            content: Text('Error al revertir: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  /// Sube la imagen a Firebase Storage: data/users/{userId}/avatar/{timestamp}.jpg
  /// La URL devuelta es persistente y se guarda en el backend (profiles.json → Firestore)
  Future<String?> _uploadImageToFirebase(Uint8List imageBytes) async {
    try {
      final userId = _authService.userId ?? '';
      if (userId.isEmpty) {
        print('Error: userId vacío, no se puede subir avatar');
        return null;
      }
      final path = FirebaseStoragePaths.userAvatar(userId);
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      print('Avatar subido a Firebase: $path -> URL obtenida');
      return url;
    } catch (e) {
      print('Error subiendo imagen a Firebase: $e');
      return null;
    }
  }
  
  /// Guarda nombre, apellidos, dirección y teléfono en una sola petición y retrocede
  Future<void> _saveAllAndPop() async {
    setState(() => _isSaving = true);
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      final body = jsonEncode({
        'first_name': _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      });
      final response = await http.put(
        Uri.parse('$url/profile'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await _authService.reloadAuthData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil guardado'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${err['detail'] ?? 'Error'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfileField(String key, String value) async {
    setState(() => _isSaving = true);
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      final response = await http.put(
        Uri.parse('$url/profile'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({key: value.isEmpty ? null : value}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado'), backgroundColor: Colors.green),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${err['detail'] ?? 'Error'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePhone(String newPhone) async {
    setState(() => _isSaving = true);
    try {
      final headers = await _authService.getAuthHeaders();
      final url = await AppConfig.getBackendUrl();
      final response = await http.put(
        Uri.parse('$url/profile'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'phone': newPhone}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await _authService.savePhone(newPhone.isEmpty ? null : newPhone);
        await _authService.reloadAuthData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teléfono guardado'), backgroundColor: Colors.green),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${err['detail'] ?? 'Error'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final pwdError = PasswordValidator.validate(_newPasswordController.text);
    if (pwdError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pwdError),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
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
              duration: const Duration(seconds: 3),
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
            duration: const Duration(seconds: 3),
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
  
  static const _darkGray = Color(0xFF424242);

  InputDecoration _inputDecoration(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _darkGray),
      hintStyle: const TextStyle(color: _darkGray),
      prefixIcon: Icon(icon, color: _darkGray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      hintText: hint,
    );
  }

  InputDecoration _passwordDecoration(
    String label,
    IconData icon,
    bool obscure,
    VoidCallback onToggle, {
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _darkGray),
      helperText: helperText,
      helperStyle: const TextStyle(color: _darkGray),
      prefixIcon: Icon(icon, color: _darkGray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: _darkGray),
        onPressed: onToggle,
      ),
    );
  }

  /// Info row: mismo tamaño visual que los TextField (mismo padding, altura y decoración)
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: _darkGray, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: _darkGray),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _darkGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppTheme.surface,
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
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveAllAndPop,
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isSaving ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
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
            
            // Nombre, apellidos, dirección (se guardan al pulsar Guardar)
            TextField(
              controller: _firstNameController,
              style: const TextStyle(color: _darkGray),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Nombre', Icons.badge, 'Opcional'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              style: const TextStyle(color: _darkGray),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Apellidos', Icons.badge_outlined, 'Opcional'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: _darkGray),
              keyboardType: TextInputType.streetAddress,
              minLines: 1,
              maxLines: 3,
              decoration: _inputDecoration('Dirección', Icons.location_on, 'Opcional'),
            ),
            const SizedBox(height: 24),
            
            // Info de usuario (solo lectura: nombre, email)
            _buildInfoRow(Icons.person, 'Nombre de usuario', _authService.username ?? ''),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Email', _authService.email ?? ''),
            const SizedBox(height: 12),
            // Teléfono (se guarda al pulsar Guardar)
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: _darkGray),
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Teléfono', Icons.phone, 'Opcional'),
            ),
            const SizedBox(height: 24),
            
            // Cambiar contraseña toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cambiar contraseña',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color.fromRGBO(158, 158, 158, 1),
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
                style: const TextStyle(color: _darkGray),
                decoration: _passwordDecoration(
                  'Contraseña actual',
                  Icons.lock,
                  _obscureCurrent,
                  () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: const TextStyle(color: _darkGray),
                decoration: _passwordDecoration(
                  'Nueva contraseña',
                  Icons.lock_outline,
                  _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew),
                  helperText: 'Mín. 8 chars, 1 mayúscula, 1 especial',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: _darkGray),
                decoration: _passwordDecoration(
                  'Confirmar nueva contraseña',
                  Icons.lock_outline,
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
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
    ),
    );
  }
}
