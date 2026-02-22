import 'package:flutter/material.dart';

/// Tema CooKind: paleta verde elegante (#235631)
class AppTheme {
  // Color principal - verde bosque
  static const Color primary = Color(0xFF235631);

  // Tonalidades del primary (más claro/oscuro)
  static const Color primaryLight = Color(0xFF3D6B47);
  static const Color primaryDark = Color(0xFF1A4025);

  // Verde acento (botones, highlights)
  static const Color accent = Color(0xFF4A7C54);

  // Acentos coloridos fuertes (tarjetas, iconos)
  static const Color vividRed = Color(0xFFD32F2F);      // Rojo intenso (favoritos, errores)
  static const Color vividOrange = Color(0xFFE65100);   // Naranja fuerte
  static const Color vividGreen = Color(0xFF2E7D32);    // Verde vivo
  static const Color vividBlue = Color(0xFF1565C0);     // Azul intenso

  // Acentos sutiles
  static const Color ecoSage = Color(0xFF52796F);
  static const Color ecoSageLight = Color(0xFF84A98C);
  static const Color ecoTerracotta = Color(0xFFBC6C25);
  static const Color ecoPeach = Color(0xFFF4A261);

  // Fondos: primary como base, tonalidades para interiores
  static const Color scaffoldBackground = Color(0xFF235631);  // Fondo pestañas (primary)
  static const Color scaffoldBackgroundLight = Color(0xFF2D4532); // Variante algo más clara
  static const Color ecoCream = Color(0xFFE8F0E4); // Crema verdoso
  static const Color surface = Color(0xFF2D4532);  // AppBar (tonalidad primary)

  // Interiores con información: tonalidades muy claras para legibilidad
  static const Color cardBackground = Color(0xFFE8F4E5);   // Verde muy claro (casi blanco)
  static const Color cardBackgroundWarm = Color(0xFFF0F7ED); // Verde crema muy claro
  static const Color cardBorder = Color(0xFFB8D4B0);       // Borde verde suave

  // Bordes y divisores
  static const Color divider = Color(0xFFB8D4B0);
  static const Color borderLight = Color(0xFFD0E2CA);

  // Dark mode - fondo negro base
  static const Color darkScaffoldBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceElevated = Color(0xFF1A1A1A);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
  static const Color darkCardBackgroundElevated = Color(0xFF262626);
  static const Color darkCardBorder = Color(0xFF2E2E2E);
  static const Color darkDivider = Color(0xFF333333);

  // Dark mode - texto (blanco/gris según contraste)
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFD4D4D4);
  static const Color darkTextTertiary = Color(0xFF808080);

  /// Colores según el tema actual (light/dark)
  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBackground : cardBackground;
  static Color cardBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBorder : cardBorder;
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : const Color(0xFF1A1A1A);
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : const Color(0xFF5A5A5A);
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextTertiary : const Color(0xFF808080);
  static Color fillLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBackground : const Color(0xFFF5F5F5);
  static Color fillMedium(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBackgroundElevated : const Color(0xFFE0E0E0);
}
