# Configurar Políticas de Supabase Storage

## Problema: Error 403 "row-level security policy"

Este error significa que las políticas de seguridad de Supabase están bloqueando la escritura en Storage.

## Solución: Configurar Políticas de Storage

### Paso 1: Ir a Storage Policies

1. Ve a tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard)
2. Ve a **Storage** en el menú lateral
3. Haz clic en el bucket **`data`**
4. Ve a la pestaña **"Policies"**

### Paso 2: Crear Política de Lectura Pública

1. Haz clic en **"New Policy"**
2. Selecciona **"Create policy from scratch"**
3. Configura:
   - **Policy name**: `Allow public read`
   - **Allowed operation**: `SELECT` (lectura)
   - **Policy definition**: 
     ```sql
     true
     ```
   - Esto permite que cualquiera pueda leer los archivos
4. Haz clic en **"Review"** y luego **"Save policy"**

### Paso 3: Crear Política de Escritura Autenticada

1. Haz clic en **"New Policy"** nuevamente
2. Selecciona **"Create policy from scratch"**
3. Configura:
   - **Policy name**: `Allow authenticated write`
   - **Allowed operation**: `INSERT`, `UPDATE`, `DELETE` (escritura)
   - **Policy definition**:
     ```sql
     auth.role() = 'authenticated'
     ```
   - Esto permite que usuarios autenticados puedan escribir
4. Haz clic en **"Review"** y luego **"Save policy"**

### Paso 4: Alternativa - Política Más Permisiva (Solo para Desarrollo)

Si las políticas anteriores no funcionan, puedes usar una política más permisiva:

1. **Policy name**: `Allow all operations`
2. **Allowed operation**: `SELECT`, `INSERT`, `UPDATE`, `DELETE`
3. **Policy definition**:
   ```sql
   true
   ```
   ⚠️ **ADVERTENCIA**: Esta política permite que cualquiera pueda leer y escribir. Úsala solo para desarrollo.

### Paso 5: Verificar que el Bucket es Público

1. En la pestaña **"Settings"** del bucket `data`
2. Asegúrate de que **"Public bucket"** esté **activado** ✅

## Verificar que Funciona

1. Intenta registrar un nuevo usuario desde la app
2. Ve a **Storage** > **data** bucket
3. Deberías ver el archivo `users/{user_id}.json` creado

## Troubleshooting

**Error persiste después de configurar políticas:**
- Espera 1-2 minutos (las políticas pueden tardar en aplicarse)
- Verifica que el bucket `data` existe y es público
- Verifica que las políticas están activas (deben aparecer en la lista)

**Error: "Bucket not found"**
- Verifica que el bucket se llama exactamente `data`
- Verifica que existe en Supabase Dashboard
