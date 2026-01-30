import 'package:flutter/material.dart';

/// Badge "Pronto..." para marcar funcionalidades no disponibles aún.
/// Usado en Ajustes, Perfil y otras pantallas para cumplir con tiendas.
class ProntoBadge extends StatelessWidget {
  const ProntoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        'Pronto...',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }
}
