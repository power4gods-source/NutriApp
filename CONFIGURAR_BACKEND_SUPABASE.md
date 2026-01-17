# Configurar Backend para Usar Supabase Storage

## ✅ Cambios Aplicados

He modificado el backend para que use Supabase Storage en lugar de solo archivos locales.

### Archivos Modificados:

1. **`requirements.txt`**: Añadido `supabase==2.3.4`
2. **`supabase_storage.py`**: Nuevo módulo para interactuar con Supabase Storage
3. **`main.py`**: Todas las funciones `load_*` y `save_*` ahora usan Supabase Storage con fallback a archivos locales

## Cómo Funciona

### Prioridad de Datos:

1. **Supabase Storage** (primero) - Datos en la nube
2. **Archivos locales** (fallback) - Si Supabase no está disponible

### Funciones Actualizadas:

- `load_users()` / `save_users()` → Usa Supabase Storage
- `load_profiles()` / `save_profiles()` → Usa Supabase Storage
- `load_recipes_general()` / `save_recipes_general()` → Usa Supabase Storage
- `load_recipes_private()` / `save_recipes_private()` → Usa Supabase Storage
- `load_recipes_public()` / `save_recipes_public()` → Usa Supabase Storage
- `load_foods()` → Usa Supabase Storage
- `load_consumption_history()` / `save_consumption_history()` → Usa Supabase Storage
- Y todas las demás...

## Configuración

### Opción 1: Variables de Entorno (Recomendado para Producción)

En **Render/Railway/etc**, añade estas variables de entorno:

```
SUPABASE_URL=https://gxdzybyszpebhlspwiyz.supabase.co
SUPABASE_ANON_KEY=sb_publishable_JIAsHqR-ryvBtin_n6EpoA__VkJbZ5T
```

### Opción 2: Valores por Defecto (Ya Configurados)

El código ya tiene tus credenciales como valores por defecto en `supabase_storage.py`:

```python
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://gxdzybyszpebhlspwiyz.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "sb_publishable_JIAsHqR-ryvBtin_n6EpoA__VkJbZ5T")
```

## Estructura en Supabase Storage

Los archivos se guardan así:

```
data/
  ├── recipes.json
  ├── recipes_private.json
  ├── recipes_public.json
  ├── foods.json
  ├── users.json
  ├── profiles.json
  ├── consumption_history.json
  ├── meal_plans.json
  ├── nutrition_stats.json
  ├── user_goals.json
  └── ingredient_food_mapping.json

users/
  └── {user_id}.json (archivos individuales de usuarios)
```

## Ventajas

✅ **Sincronización automática**: Los datos se guardan en Supabase y localmente
✅ **Respaldo**: Si Supabase falla, usa archivos locales
✅ **Funciona offline**: El backend puede funcionar sin Supabase usando archivos locales
✅ **Consistencia**: App móvil y backend usan la misma fuente de datos (Supabase)

## Verificar que Funciona

1. **Ejecuta el backend localmente:**
   ```bash
   pip install -r requirements.txt
   uvicorn main:app --reload
   ```

2. **Registra un usuario desde la app**
3. **Verifica en Supabase Dashboard** > Storage > `data` bucket
4. **Deberías ver** `users.json` actualizado

## Desplegar en la Nube

Cuando despliegues en Render/Railway:

1. **Añade las variables de entorno** (SUPABASE_URL, SUPABASE_ANON_KEY)
2. **El backend automáticamente usará Supabase Storage**
3. **Los archivos JSON se guardarán en Supabase**, no en el servidor

## Troubleshooting

**Error: "Supabase client not initialized"**
- Verifica que las credenciales en `supabase_storage.py` sean correctas
- Verifica que el bucket `data` existe en Supabase

**Error: "Permission denied"**
- Verifica las políticas de Storage en Supabase Dashboard
- Asegúrate de que el bucket es público o las políticas permiten acceso

**Los datos no se sincronizan:**
- Verifica que Supabase está configurado correctamente
- Revisa los logs del backend para ver errores
