/// Utilidad para convertir ingredientes a plural
class PluralHelper {
  // Mapa de singular a plural
  static final Map<String, String> _pluralMap = {
    'huevo': 'huevos',
    'patata': 'patatas',
    'tomate': 'tomates',
    'pimiento': 'pimientos',
    'ajo': 'ajos',
    'cebolla': 'cebollas',
    'zanahoria': 'zanahorias',
    'calabacín': 'calabacines',
    'berenjena': 'berenjenas',
    'pepino': 'pepinos',
    'limón': 'limones',
    'naranja': 'naranjas',
    'manzana': 'manzanas',
    'plátano': 'plátanos',
    'fresa': 'fresas',
    'uva': 'uvas',
    'pollo': 'pollos',
    'pescado': 'pescados',
    'gamba': 'gambas',
    'huevo': 'huevos',
    'queso': 'quesos',
    'pan': 'panes',
    'pasta': 'pastas',
    'arroz': 'arroz', // No cambia
    'aceite': 'aceites',
    'sal': 'sales',
    'pimienta': 'pimientas',
    'azúcar': 'azúcares',
    'harina': 'harinas',
    'leche': 'leches',
    'yogur': 'yogures',
    'mantequilla': 'mantequillas',
  };

  /// Convierte un ingrediente a plural si es necesario
  static String toPlural(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase().trim();
    
    // Si ya está en plural, devolverlo tal cual
    if (_pluralMap.values.contains(lowerIngredient)) {
      return ingredient; // Mantener capitalización original
    }
    
    // Buscar en el mapa
    if (_pluralMap.containsKey(lowerIngredient)) {
      final plural = _pluralMap[lowerIngredient]!;
      // Mantener capitalización
      if (ingredient[0] == ingredient[0].toUpperCase()) {
        return plural[0].toUpperCase() + plural.substring(1);
      }
      return plural;
    }
    
    // Reglas básicas de pluralización en español
    if (lowerIngredient.endsWith('a') || 
        lowerIngredient.endsWith('e') || 
        lowerIngredient.endsWith('i') || 
        lowerIngredient.endsWith('o') || 
        lowerIngredient.endsWith('u')) {
      return ingredient + 's';
    }
    
    if (lowerIngredient.endsWith('z')) {
      return ingredient.substring(0, ingredient.length - 1) + 'ces';
    }
    
    if (lowerIngredient.endsWith('ón')) {
      return ingredient.substring(0, ingredient.length - 2) + 'ones';
    }
    
    // Si no se puede determinar, devolver tal cual
    return ingredient;
  }

  /// Normaliza un ingrediente (convierte a plural y lowercase)
  static String normalize(String ingredient) {
    return toPlural(ingredient).toLowerCase();
  }
}




