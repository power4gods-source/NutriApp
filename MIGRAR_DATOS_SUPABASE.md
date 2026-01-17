# Guía: Migrar Datos Existentes a Supabase

## ¿Necesito subir archivos?

**Respuesta corta: NO es necesario.** La app funcionará sin subir archivos. Los datos se crearán automáticamente cuando uses la app.

**Pero si tienes datos existentes** que quieres migrar, puedes subirlos.

## Opción 1: Subir Manualmente (Recomendado)

### Pasos:

1. **Ve a Supabase Dashboard**
   - Abre tu proyecto en [supabase.com/dashboard](https://supabase.com/dashboard)
   - Ve a **Storage** > **data** bucket

2. **Sube los archivos JSON uno por uno:**
   - Haz clic en "Upload file"
   - Selecciona el archivo desde: `C:\Users\mball\Downloads\NutriApp\`
   - **IMPORTANTE**: Para archivos en la carpeta `data/`, sube directamente (ej: `recipes.json`)
   - Para archivos de usuarios, crea la carpeta `users/` primero y luego sube `{user_id}.json`

3. **Archivos a subir (si los tienes):**
   ```
   data/
     ├── recipes.json
     ├── recipes_private.json
     ├── recipes_public.json
     ├── foods.json
     ├── profiles.json
     ├── consumption_history.json
     ├── meal_plans.json
     ├── nutrition_stats.json
     ├── user_goals.json
     └── ingredient_food_mapping.json
   
   users/
     └── {user_id}.json (uno por cada usuario)
   ```

## Opción 2: Usar la App (Automático)

1. **Ejecuta la app**
2. **Registra/Inicia sesión** con tus usuarios
3. **Usa la app normalmente** - los datos se subirán automáticamente a Supabase cuando:
   - Guardes una receta
   - Agregues ingredientes
   - Registres consumo
   - etc.

## Opción 3: Script de Migración (Avanzado)

Si tienes muchos datos, puedo crear un script Python que suba todos los archivos automáticamente.

## Verificar que Funciona

1. Ejecuta la app
2. Haz login o registra un usuario
3. Ve a Supabase Dashboard > Storage > data bucket
4. Deberías ver:
   - `users/{user_id}.json` (creado automáticamente)
   - Otros archivos si los subiste manualmente

## Nota Importante

- **Los archivos JSON locales** seguirán existiendo en tu PC
- **Supabase Storage** será la copia en la nube
- **La app sincronizará** entre local y Supabase automáticamente
