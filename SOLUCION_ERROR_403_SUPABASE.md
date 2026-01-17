# Solución: Error 403 en Supabase Storage

## Error que estás viendo:
```
StorageException(message: new row violates row-level security policy, statusCode: 403, error: Unauthorized)
```

## Solución Rápida (5 minutos)

### Paso 1: Ir a Storage Policies

1. Ve a [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Storage** en el menú lateral
4. Haz clic en el bucket **`data`**
5. Ve a la pestaña **"Policies"** (o "Políticas")

### Paso 2: Eliminar Políticas Existentes (si hay)

1. Si hay políticas existentes, elimínalas todas
2. Haz clic en el botón de eliminar (🗑️) en cada política

### Paso 3: Crear Nueva Política Permisiva

1. Haz clic en **"New Policy"**
2. Selecciona **"Create policy from scratch"**
3. Configura:
   - **Policy name**: `Allow all operations`
   - **Allowed operation**: Selecciona TODAS:
     - ✅ SELECT (lectura)
     - ✅ INSERT (escritura)
     - ✅ UPDATE (actualización)
     - ✅ DELETE (eliminación)
   - **Policy definition**: 
     ```sql
     true
     ```
   - Esto permite que cualquiera pueda leer y escribir
4. Haz clic en **"Review"** y luego **"Save policy"**

### Paso 4: Verificar que el Bucket es Público

1. En la pestaña **"Settings"** del bucket `data`
2. Asegúrate de que **"Public bucket"** esté **activado** ✅

### Paso 5: Probar

1. Intenta registrar un nuevo usuario desde la app
2. Debería funcionar sin el error 403

## Alternativa: Políticas Más Seguras (Recomendado para Producción)

Si quieres políticas más seguras (solo para desarrollo, puedes usar la política permisiva de arriba):

### Política 1: Lectura Pública
- **Policy name**: `Allow public read`
- **Allowed operation**: `SELECT`
- **Policy definition**: `true`

### Política 2: Escritura Autenticada
- **Policy name**: `Allow authenticated write`
- **Allowed operation**: `INSERT`, `UPDATE`, `DELETE`
- **Policy definition**: `auth.role() = 'authenticated'`

**Nota**: Para que esto funcione, necesitarías usar Supabase Auth, que requiere cambios en el código. Por ahora, usa la política permisiva (`true`) para que funcione.

## Verificar que Funciona

1. Intenta registrar un usuario
2. Ve a **Storage** > **data** bucket
3. Deberías ver `users/{user_id}.json` creado
