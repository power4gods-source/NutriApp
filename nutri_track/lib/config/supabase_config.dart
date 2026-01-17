/// Configuración de Supabase
/// 
/// IMPORTANTE: Reemplaza estos valores con tus credenciales de Supabase
/// Obtén las credenciales desde: https://supabase.com/dashboard/project/_/settings/api
class SupabaseConfig {
  // TODO: Reemplaza con tu Project URL de Supabase
  // Ejemplo: https://xxxxx.supabase.co
  static const String supabaseUrl = 'https://gxdzybyszpebhlspwiyz.supabase.co';
  
  // TODO: Reemplaza con tu anon/public key de Supabase
  // Ejemplo: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  static const String supabaseAnonKey = 'sb_publishable_JIAsHqR-ryvBtin_n6EpoA__VkJbZ5T';
  
  // Nombre del bucket de Storage donde se guardarán los archivos JSON
  static const String storageBucket = 'data';
  
  // Verificar que las credenciales están configuradas
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL_HERE' &&
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE' &&
           supabaseUrl.isNotEmpty &&
           supabaseAnonKey.isNotEmpty &&
           !supabaseUrl.contains('xxxxx') &&
           supabaseAnonKey.length > 20; // La anon key debe ser larga
  }
}
