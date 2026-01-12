// Common ingredients list for autocomplete suggestions
class IngredientSuggestions {
  static const List<String> commonIngredients = [
    'pollo',
    'carne',
    'pescado',
    'huevo',
    'huevos',
    'nata',
    'bacon',
    'panceta',
    'pimiento',
    'pimientos',
    'cebolla',
    'tomate',
    'tomates',
    'ajo',
    'zanahoria',
    'zanahorias',
    'patata',
    'patatas',
    'arroz',
    'pasta',
    'espaguetis',
    'queso',
    'leche',
    'mantequilla',
    'aceite',
    'sal',
    'pimienta',
    'limón',
    'limones',
    'champiñones',
    'espinacas',
    'lechuga',
    'pepino',
    'aguacate',
    'pan',
    'harina',
    'azúcar',
    'vinagre',
    'caldo',
    'garbanzos',
    'lentejas',
    'judías',
    'maíz',
    'pimiento rojo',
    'pimiento verde',
    'cebolla morada',
    'apio',
    'perejil',
    'cilantro',
    'albahaca',
    'orégano',
    'comino',
    'pimentón',
    'curry',
    'jengibre',
    'yogur',
    'nuez',
    'almendras',
    'aceitunas',
    'anchoas',
    'atún',
    'salmón',
    'gambas',
    'calamar',
    'berenjena',
    'calabacín',
    'calabaza',
    'brócoli',
    'coliflor',
    'pimiento amarillo',
    'pimiento naranja',
  ];

  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase().trim();
    return commonIngredients
        .where((ingredient) => ingredient.toLowerCase().contains(lowerQuery))
        .take(5)
        .toList();
  }
}







