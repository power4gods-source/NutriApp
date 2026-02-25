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
  
  /// Convierte nutrients en formato objeto (calories_kcal, protein_g, etc.) a mapa estándar.
  static Map<String, double> _parseNutrientsMap(Map<String, dynamic>? m) {
    final result = <String, double>{
      'calories': 0.0, 'protein': 0.0, 'carbohydrates': 0.0, 'fat': 0.0,
      'fiber': 0.0, 'sugar': 0.0, 'sodium': 0.0,
    };
    if (m == null) return result;
    result['calories'] = _num(m['calories_kcal']) ?? _num(m['calories']) ?? 0.0;
    result['protein'] = _num(m['protein_g']) ?? _num(m['protein']) ?? 0.0;
    result['carbohydrates'] = _num(m['carbs_g']) ?? _num(m['carbohydrates']) ?? _num(m['carbs']) ?? 0.0;
    result['fat'] = _num(m['fat_g']) ?? _num(m['fat']) ?? 0.0;
    result['fiber'] = _num(m['fiber_g']) ?? _num(m['fiber']) ?? 0.0;
    result['sugar'] = _num(m['sugar_g']) ?? _num(m['sugar']) ?? 0.0;
    result['sodium'] = _num(m['sodium_mg']) ?? _num(m['sodium']) ?? 0.0;
    return result;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Obtiene nutrientes por ración desde una receta (null-safe).
  /// Acepta nutrients como String (legacy) o como Map (calories_kcal, protein_g, carbs_g, fat_g).
  static Map<String, double> getNutritionPerServing(Map<String, dynamic> recipe) {
    try {
      final rawNutrients = recipe['nutrients'];
      if (rawNutrients is Map) {
        final perServing = _parseNutrientsMap(Map<String, dynamic>.from(rawNutrients as Map));
        if ((perServing['calories'] ?? 0) > 0 ||
            (perServing['protein'] ?? 0) > 0 ||
            (perServing['carbohydrates'] ?? 0) > 0 ||
            (perServing['fat'] ?? 0) > 0) {
          return perServing;
        }
      }
      final nutrientsStr = rawNutrients == null
          ? ''
          : (rawNutrients is String ? rawNutrients : rawNutrients.toString());
      final rawServings = recipe['servings'];
      double servings = 4.0;
      if (rawServings != null) {
        if (rawServings is int) {
          servings = rawServings.toDouble();
        } else if (rawServings is double) {
          servings = rawServings;
        } else if (rawServings is num) {
          servings = rawServings.toDouble();
        } else {
          servings = double.tryParse(rawServings.toString()) ?? 4.0;
        }
      }
      if (servings <= 0 || servings.isNaN) servings = 4.0;

      final totalNutrition = parseNutrientsString(nutrientsStr);

      final rawCalories = recipe['calories_per_serving'];
      final caloriesPerServing = rawCalories == null
          ? 0.0
          : (rawCalories is num ? rawCalories.toDouble() : (double.tryParse(rawCalories.toString()) ?? 0.0));

      if (totalNutrition['calories'] == 0 && caloriesPerServing > 0) {
        totalNutrition['calories'] = caloriesPerServing;
      } else if ((totalNutrition['calories'] ?? 0) > 0) {
        for (var key in totalNutrition.keys) {
          final v = totalNutrition[key];
          if (v != null && v > 0) totalNutrition[key] = v / servings;
        }
      }
      return totalNutrition;
    } catch (_) {
      return {
        'calories': 0.0,
        'protein': 0.0,
        'carbohydrates': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 0.0,
      };
    }
  }
}
