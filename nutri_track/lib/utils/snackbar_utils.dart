import 'package:flutter/material.dart';

/// Duración estándar para mensajes de error (2 segundos si el usuario no los toca)
const Duration kErrorSnackBarDuration = Duration(seconds: 2);

/// Muestra un SnackBar de error que se cierra automáticamente a los 2 segundos
void showErrorSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.red,
      duration: kErrorSnackBarDuration,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Muestra un SnackBar de éxito con duración corta
void showSuccessSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.green,
      duration: kErrorSnackBarDuration,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
