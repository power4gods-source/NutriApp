/// Utilidad para parsear strings de nutrientes
/// Formato: "calories 300,protein 20g,carbs 50g,fat 15g"
class NutritionParser {
  static Map<String, double> parseNutrientsString(String? nutrientsStr) {
    final result = <String, double>{
      'calories': 0.0,
      'protein': 0.0,
      'carbohydrates': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
    };
    
    if (nutrientsStr == null || nutrientsStr.isEmpty) {
      return result;
    }
    
    try {
      final parts = nutrientsStr.split(',');
      for (var part in parts) {
        part = part.trim().toLowerCase();
        
        // Extraer números (pueden tener decimales)
        final regex = RegExp(r'\d+\.?\d*');
        final matches = regex.allMatches(part);
        if (matches.isEmpty) continue;
        
        final value = double.tryParse(matches.first.group(0) ?? '0') ?? 0.0;
        
        if (part.contains('calories') || part.contains('calorias')) {
          result['calories'] = value;
        } else if (part.contains('protein') || part.contains('proteina')) {
          result['protein'] = value;
        } else if (part.contains('carbs') || part.contains('carbohydrates') || 
                   part.contains('carbohidratos') || part.contains('carbos')) {
          result['carbohydrates'] = value;
        } else if (part.contains('fat') || part.contains('grasas') || part.contains('grasa')) {
          result['fat'] = value;
        } else if (part.contains('fiber') || part.contains('fibra')) {
          result['fiber'] = value;
        } else if (part.contains('sugar') || part.contains('azúcar') || part.contains('azucar')) {
          result['sugar'] = value;
        } else if (part.contains('sodium') || part.contains('sodio')) {
          result['sodium'] = value;
        }
      }
    } catch (e) {
      print('Error parsing nutrients string: $e');
    }
    
    return result;
  }
  
  /// Obtiene nutrientes por ración desde una receta
  static Map<String, double> getNutritionPerServing(Map<String, dynamic> recipe) {
    final nutrientsStr = recipe['nutrients'] ?? '';
    final servings = (recipe['servings'] ?? 4.0).toDouble();
    
    if (servings <= 0) servings = 4.0;
    
    final totalNutrition = parseNutrientsString(nutrientsStr);
    
    // Si no hay nutrientes parseados, intentar usar calories_per_serving
    if (totalNutrition['calories'] == 0) {
      final caloriesPerServing = (recipe['calories_per_serving'] ?? 0).toDouble();
      if (caloriesPerServing > 0) {
        totalNutrition['calories'] = caloriesPerServing;
      }
    } else {
      // Dividir por número de raciones para obtener por ración
      for (var key in totalNutrition.keys) {
        totalNutrition[key] = totalNutrition[key]! / servings;
      }
    }
    
    return totalNutrition;
  }
}
