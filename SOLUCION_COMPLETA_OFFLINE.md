# Solución Completa: App Offline con Supabase

## Problema Actual

1. ❌ Error 403 en Supabase Storage (políticas de seguridad)
2. ❌ Backend requiere PC encendido
3. ❌ App no funciona completamente sin backend

## Solución en 2 Pasos

### Paso 1: Configurar Supabase Storage (5 minutos)

**Sigue la guía:** `SOLUCION_ERROR_403_SUPABASE.md`

**Resumen rápido:**
1. Ve a Supabase Dashboard > Storage > `data` bucket > Policies
2. Crea una política con:
   - **Policy name**: `Allow all operations`
   - **Allowed operations**: SELECT, INSERT, UPDATE, DELETE
   - **Policy definition**: `true`
3. Guarda la política

### Paso 2: Desplegar Backend en la Nube (15 minutos)

**Sigue la guía:** `DEPLOY_BACKEND_CLOUD.md`

**Opciones:**
- **Render** (recomendado): Gratis, fácil de usar
- **Railway**: Gratis con límites
- **Fly.io**: Gratis

**Pasos rápidos:**
1. Sube tu código a GitHub
2. Crea cuenta en Render.com
3. Conecta tu repositorio
4. Configura:
   - Build: `pip install -r requirements.txt`
   - Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Obtén la URL (ej: `https://nutriapp-backend.onrender.com`)
6. Actualiza la URL en la app

## Configurar la App para Usar Backend en la Nube

### Opción A: Cambiar URL por Defecto

Edita `nutri_track/lib/config/app_config.dart`:

```dart
static String get defaultBackendUrl {
  // Cambia esto por tu URL de Render/Railway/etc
  return 'https://nutriapp-backend.onrender.com';
}
```

### Opción B: Configuración Dinámica (Recomendado)

La app ya tiene `AppConfig.setBackendUrl()` para configurar la URL dinámicamente.

Puedes añadir una pantalla de configuración donde el usuario ingrese la URL del backend.

## Modo Offline Completo

**Con Supabase configurado correctamente, la app funciona completamente offline:**

✅ **Registro de usuarios** → Se guarda en Supabase Storage
✅ **Login** → Funciona con Supabase Storage
✅ **Guardar recetas** → Se guardan en Supabase Storage
✅ **Ingredientes** → Se guardan en Supabase Storage
✅ **Consumo diario** → Se guarda en Supabase Storage
✅ **Lista de compra** → Se guarda en Supabase Storage

**Sin backend:**
- ✅ Todas las funciones básicas funcionan
- ⚠️ Algunas funciones avanzadas pueden requerir backend
- ✅ Los datos se sincronizan automáticamente cuando el backend esté disponible

## Verificar que Todo Funciona

### 1. Verificar Supabase Storage

1. Registra un usuario desde la app
2. Ve a Supabase Dashboard > Storage > `data` bucket
3. Deberías ver: `users/{user_id}.json`

### 2. Verificar Backend en la Nube

1. Abre la URL del backend (ej: `https://nutriapp-backend.onrender.com/health`)
2. Debería responder: `{"status": "ok"}`

### 3. Probar desde el Móvil

1. **Con PC apagado:**
   - La app debería funcionar con Supabase
   - Registro, login, guardar datos → Todo funciona

2. **Con backend en la nube:**
   - La app se conecta al backend automáticamente
   - Funciones avanzadas también funcionan

## Estructura Final

```
App Móvil
  ├── Supabase Storage (siempre disponible)
  │   ├── users/{user_id}.json
  │   ├── recipes_public.json
  │   ├── recipes_private.json
  │   └── ...
  │
  └── Backend en la Nube (opcional, para funciones avanzadas)
      ├── API REST
      ├── JWT Authentication
      └── Funciones avanzadas
```

## Ventajas de Esta Solución

✅ **Funciona sin PC**: Supabase está en la nube
✅ **Funciona sin backend**: App usa Supabase directamente
✅ **Sincronización automática**: Cuando el backend esté disponible
✅ **Escalable**: Puedes añadir más funciones al backend después
✅ **Gratis**: Supabase y Render tienen planes gratuitos

## Próximos Pasos

1. ✅ Configura Supabase Storage (políticas)
2. ✅ Despliega backend en Render/Railway
3. ✅ Actualiza URL del backend en la app
4. ✅ Prueba desde el móvil con PC apagado
5. ✅ Verifica que todo funciona
