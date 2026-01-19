/// Utilidad para normalizar nombres de ingredientes al singular
class IngredientNormalizer {
  /// Convierte un nombre de ingrediente del plural al singular
  static String toSingular(String ingredient) {
    if (ingredient.isEmpty) return ingredient;
    
    final lower = ingredient.toLowerCase().trim();
    
    // Reglas específicas para ingredientes comunes
    final specificRules = {
      'pollos': 'pollo',
      'cebollas': 'cebolla',
      'patatas': 'patata',
      'zanahorias': 'zanahoria',
      'tomates': 'tomate',
      'pimientos': 'pimiento',
      'ajos': 'ajo',
      'huevos': 'huevo',
      'limones': 'limón',
      'naranjas': 'naranja',
      'manzanas': 'manzana',
      'plátanos': 'plátano',
      'fresas': 'fresa',
      'uvas': 'uva',
      'zanahorias': 'zanahoria',
      'lechugas': 'lechuga',
      'espinacas': 'espinaca',
      'zanahorias': 'zanahoria',
      'pepinos': 'pepino',
      'calabacines': 'calabacín',
      'berenjenas': 'berenjena',
      'pimientos': 'pimiento',
      'champiñones': 'champiñón',
      'setas': 'seta',
      'judías': 'judía',
      'garbanzos': 'garbanzo',
      'lentejas': 'lenteja',
      'alubias': 'alubia',
      'guisantes': 'guisante',
      'zanahorias': 'zanahoria',
    };
    
    // Verificar reglas específicas primero
    if (specificRules.containsKey(lower)) {
      return specificRules[lower]!;
    }
    
    // Reglas generales para plurales en español
    // Terminaciones comunes: -s, -es, -ces
    if (lower.endsWith('ces')) {
      // Ej: zanahorias -> zanahoria (ya cubierto arriba)
      return lower.substring(0, lower.length - 3) + 'z';
    } else if (lower.endsWith('es') && lower.length > 3) {
      // Ej: tomates -> tomate, pimientos -> pimiento
      final withoutEs = lower.substring(0, lower.length - 2);
      // Si termina en vocal antes de 'es', solo quitar 's'
      if (withoutEs.endsWith('a') || withoutEs.endsWith('e') || 
          withoutEs.endsWith('i') || withoutEs.endsWith('o') || 
          withoutEs.endsWith('u')) {
        return withoutEs;
      }
      // Si termina en consonante, quitar 'es'
      return withoutEs;
    } else if (lower.endsWith('s') && lower.length > 2) {
      // Ej: pollos -> pollo, huevos -> huevo
      final withoutS = lower.substring(0, lower.length - 1);
      // Si termina en vocal, solo quitar 's'
      if (withoutS.endsWith('a') || withoutS.endsWith('e') || 
          withoutS.endsWith('i') || withoutS.endsWith('o') || 
          withoutS.endsWith('u')) {
        return withoutS;
      }
      // Si termina en consonante, mantener (puede ser singular ya)
      return lower;
    }
    
    // Si no coincide con ninguna regla, retornar original
    return lower;
  }
  
  /// Normaliza un ingrediente: convierte a minúsculas, quita espacios y convierte a singular
  static String normalize(String ingredient) {
    return toSingular(ingredient.trim().toLowerCase());
  }
}
