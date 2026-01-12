import '../services/tracking_service.dart';

class IngredientMapper {
  final TrackingService _trackingService = TrackingService();

  /// Maps an ingredient to a food with automatic matching and suggestions
  Future<IngredientMappingResult> mapIngredient(
    String ingredientName, {
    double? quantity,
    String? unit,
  }) async {
    // Get mapping from backend
    final mappingData = await _trackingService.getIngredientMapping(ingredientName);
    
    if (mappingData['food'] != null) {
      // Found a match
      return IngredientMappingResult(
        ingredientName: ingredientName,
        food: mappingData['food'],
        confidence: mappingData['mapping']?['confidence'] ?? 1.0,
        matchType: mappingData['mapping']?['match_type'] ?? 'exact',
        autoMatched: mappingData['auto_matched'] ?? false,
        suggestions: [],
      );
    }
    
    // No match found, return suggestions
    return IngredientMappingResult(
      ingredientName: ingredientName,
      food: null,
      confidence: 0.0,
      matchType: 'none',
      autoMatched: false,
      suggestions: mappingData['suggestions'] ?? [],
    );
  }

  /// Create a manual mapping for an ingredient
  Future<bool> createMapping(
    String ingredientName,
    String foodId, {
    double? defaultQuantity,
    String? defaultUnit,
  }) async {
    return await _trackingService.createIngredientMapping(
      ingredientName,
      foodId,
      defaultQuantity: defaultQuantity,
      defaultUnit: defaultUnit,
    );
  }

  /// Get all possible food matches for an ingredient (fuzzy search)
  Future<List<Map<String, dynamic>>> getFoodSuggestions(String ingredientName) async {
    // Search foods by name
    final foods = await _trackingService.searchFoods(ingredientName);
    final List<Map<String, dynamic>> foodsList = foods.cast<Map<String, dynamic>>();
    
    // Also try partial matches
    if (foodsList.length < 5) {
      final partialMatches = await _trackingService.searchFoods(
        ingredientName.length > 3 ? ingredientName.substring(0, 3) : ingredientName,
      );
      final List<Map<String, dynamic>> partialList = partialMatches.cast<Map<String, dynamic>>();
      for (final food in partialList) {
        if (!foodsList.any((f) => f['food_id'] == food['food_id'])) {
          foodsList.add(food);
        }
      }
    }
    
    return foodsList.take(10).toList();
  }
}

class IngredientMappingResult {
  final String ingredientName;
  final Map<String, dynamic>? food;
  final double confidence;
  final String matchType; // 'exact', 'partial', 'none'
  final bool autoMatched;
  final List<String> suggestions;

  IngredientMappingResult({
    required this.ingredientName,
    this.food,
    required this.confidence,
    required this.matchType,
    required this.autoMatched,
    required this.suggestions,
  });

  bool get hasMatch => food != null && confidence > 0.5;
  bool get isExactMatch => matchType == 'exact' && confidence >= 1.0;
}

