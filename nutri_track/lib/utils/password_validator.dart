/// Valida contraseñas según las reglas de la app:
/// - Mínimo 8 caracteres
/// - Al menos 1 letra mayúscula
/// - Al menos 1 carácter especial (!@#\$%^&* etc.)
class PasswordValidator {
  static const int minLength = 8;

  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  // Caracteres no alfanuméricos = especiales (!@#$%^&* etc.)
  static final RegExp _specialCharRegex = RegExp(r'[^A-Za-z0-9]');

  /// Valida la contraseña y retorna mensaje de error o null si es válida
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Introduce una contraseña';
    }
    if (value.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres';
    }
    if (!_uppercaseRegex.hasMatch(value)) {
      return 'La contraseña debe contener al menos una mayúscula';
    }
    if (!_specialCharRegex.hasMatch(value)) {
      return 'La contraseña debe contener al menos un carácter especial (!@#\$%^&* etc.)';
    }
    return null;
  }

  /// Comprueba si la contraseña cumple las reglas (para uso en auth_service)
  static bool isValid(String password) {
    return validate(password) == null;
  }
}
