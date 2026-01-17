# Guía Rápida: Configurar Supabase

## Pasos Rápidos

### 1. Crear Proyecto en Supabase (5 minutos)

1. Ve a [https://supabase.com](https://supabase.com) y crea una cuenta
2. Crea un nuevo proyecto:
   - **Name**: `nutriapp`
   - **Database Password**: (guárdala bien)
   - **Region**: Elige la más cercana
3. Espera 2-3 minutos a que se cree

### 2. Obtener Credenciales (1 minuto)

1. En tu proyecto, ve a **Settings** > **API**
2. Copia:
   - **Project URL** (ejemplo: `https://gxdzybyszpebhlspwiyz.supabase.co`)
   - **anon public key** (la clave larga que empieza con `eyJ...`)

### 3. Configurar Storage (2 minutos)

1. Ve a **Storage** en el menú lateral
2. Crea un bucket:
   - **Name**: `data`
   - **Public bucket**: ✅ **Activado** (importante!)
3. Haz clic en "Create bucket"

### 4. Configurar el Código (1 minuto)

1. Abre `nutri_track/lib/config/supabase_config.dart`
2. Reemplaza:
   ```dart
   static const String supabaseUrl = 'TU_PROJECT_URL_AQUI';
   static const String supabaseAnonKey = 'TU_ANON_KEY_AQUI';
   ```

### 5. Instalar Dependencias

```bash
cd nutri_track
flutter pub get
```

### 6. ¡Listo!

La app ahora usará Supabase en lugar de Firebase. Los datos se guardarán en Supabase Storage.

## Estructura de Datos

Los archivos JSON se guardarán en el bucket `data`:

```
data/
  ├── recipes.json
  ├── recipes_private.json
  ├── recipes_public.json
  ├── foods.json
  ├── users/
  │   └── {user_id}.json
  └── ...
```

## Verificar que Funciona

1. Ejecuta la app
2. Intenta registrar un nuevo usuario
3. Ve a Supabase Dashboard > Storage > data bucket
4. Deberías ver el archivo `users/{user_id}.json`

## Notas Importantes

- **Bucket público**: Asegúrate de que el bucket `data` sea público para lectura
- **Políticas de Storage**: Por defecto, Supabase permite lectura pública y escritura autenticada
- **Offline**: La app seguirá funcionando offline usando datos locales si Supabase no está disponible

## Troubleshooting

**Error: "Invalid API key"**
- Verifica que copiaste la `anon key`, no la `service_role key`
- Verifica que no hay espacios extra en las credenciales

**Error: "Bucket not found"**
- Verifica que el bucket se llama exactamente `data`
- Verifica que el bucket existe en Supabase Dashboard

**Error: "Permission denied"**
- Asegúrate de que el bucket es público
- Ve a Storage > Policies y verifica las políticas
