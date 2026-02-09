/// Rutas de Firebase Storage para organizar las imágenes por tipo.
/// Estructura: data/{tipo}/{contexto}/{archivo}
class FirebaseStoragePaths {
  FirebaseStoragePaths._();

  /// Avatares de perfil: data/users/{userId}/avatar/{timestamp}.jpg
  static String userAvatar(String userId, [String extension = 'jpg']) =>
      'data/users/$userId/avatar/${DateTime.now().millisecondsSinceEpoch}.$extension';

  /// Fotos de recetas: data/users/{userId}/recipes/{recipeId}/{timestamp}.jpg
  static String recipeImage(String userId, String recipeId, [String extension = 'jpg']) =>
      'data/users/$userId/recipes/$recipeId/${DateTime.now().millisecondsSinceEpoch}.$extension';

  /// Fotos de recetas nuevas (sin recipeId aún): data/users/{userId}/recipes/new/{timestamp}.jpg
  static String recipeImageNew(String userId, [String extension = 'jpg']) =>
      'data/users/$userId/recipes/new/${DateTime.now().millisecondsSinceEpoch}.$extension';

  /// Fotos de posts (futuro): data/users/{userId}/posts/{postId}/{timestamp}.jpg
  static String postImage(String userId, String postId, [String extension = 'jpg']) =>
      'data/users/$userId/posts/$postId/${DateTime.now().millisecondsSinceEpoch}.$extension';
}
