# Guía de Configuración de Supabase

Esta guía te ayudará a configurar Supabase para reemplazar Firebase en tu aplicación NutriApp.

## 1. Crear Proyecto en Supabase

1. Ve a [https://supabase.com](https://supabase.com)
2. Crea una cuenta o inicia sesión
3. Haz clic en "New Project"
4. Completa los datos:
   - **Name**: `nutriapp` (o el nombre que prefieras)
   - **Database Password**: Crea una contraseña segura (guárdala)
   - **Region**: Elige la región más cercana
5. Espera a que se cree el proyecto (2-3 minutos)

## 2. Obtener Credenciales

Una vez creado el proyecto:

1. Ve a **Settings** > **API**
2. Copia las siguientes credenciales:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - **service_role key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (mantén esto secreto)

## 3. Configurar Storage

1. Ve a **Storage** en el menú lateral
2. Crea un bucket llamado `data`:
   - Haz clic en "New bucket"
   - **Name**: `data`
   - **Public bucket**: ✅ Activado (para acceso público a los archivos JSON)
   - Haz clic en "Create bucket"

3. Configura las políticas de Storage:
   - Ve a **Storage** > **Policies**
   - Para el bucket `data`, crea políticas:
     - **Policy name**: `Allow public read`
       - **Allowed operation**: SELECT
       - **Policy definition**: `true` (permite lectura pública)
     - **Policy name**: `Allow authenticated write`
       - **Allowed operation**: INSERT, UPDATE, DELETE
       - **Policy definition**: `auth.role() = 'authenticated'` (solo usuarios autenticados pueden escribir)

## 4. Configurar Autenticación

1. Ve a **Authentication** > **Settings**
2. Configura:
   - **Site URL**: `http://localhost` (para desarrollo)
   - **Redirect URLs**: Añade tu URL de desarrollo si es necesario
   - **Enable Email Auth**: ✅ Activado

3. (Opcional) Configura Email Templates:
   - Ve a **Authentication** > **Email Templates**
   - Personaliza los templates si lo deseas

## 5. Configurar Base de Datos (Opcional - para datos estructurados)

Si quieres usar Postgres en lugar de solo Storage:

1. Ve a **SQL Editor**
2. Puedes crear tablas para usuarios, recetas, etc.
3. Por ahora, usaremos Storage para mantener compatibilidad con el sistema actual

## 6. Configurar Variables de Entorno

Crea un archivo `.env` en la raíz del proyecto (o configura en el código):

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**⚠️ IMPORTANTE**: No subas el archivo `.env` a GitHub. Añádelo a `.gitignore`.

## 7. Instalar Dependencias

Las dependencias ya están añadidas en `pubspec.yaml`. Ejecuta:

```bash
cd nutri_track
flutter pub get
```

## 8. Configurar el Código

1. Edita `nutri_track/lib/config/supabase_config.dart`
2. Añade tus credenciales de Supabase:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

## 9. Probar la Conexión

1. Ejecuta la app
2. Intenta hacer login/registro
3. Verifica en Supabase Dashboard que los datos se están guardando

## Estructura de Datos en Storage

Los archivos JSON se guardarán en el bucket `data` con la siguiente estructura:

```
data/
  ├── users/
  │   └── {user_id}.json
  ├── recipes.json
  ├── recipes_private.json
  ├── recipes_public.json
  ├── foods.json
  ├── profiles.json
  ├── consumption_history.json
  └── ...
```

## Migración desde Firebase

Si tienes datos en Firebase:

1. Descarga los archivos JSON desde Firebase Storage
2. Sube los archivos manualmente a Supabase Storage usando el Dashboard
3. O usa el script de migración (si se crea)

## Troubleshooting

### Error: "Invalid API key"
- Verifica que las credenciales en `supabase_config.dart` sean correctas
- Asegúrate de usar la `anon key`, no la `service_role key` en el cliente

### Error: "Bucket not found"
- Verifica que el bucket `data` existe en Supabase Storage
- Verifica que el bucket es público o que las políticas permiten acceso

### Error: "Permission denied"
- Revisa las políticas de Storage en Supabase Dashboard
- Asegúrate de que las políticas permiten lectura/escritura según sea necesario

## Recursos

- [Documentación de Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Supabase Storage](https://supabase.com/docs/guides/storage)
- [Supabase Auth](https://supabase.com/docs/guides/auth)
