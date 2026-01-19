# Solución Completa: Registro de Usuarios

## 🔍 Problemas Identificados

### 1. Backend no responde a `/auth/register`
**Síntoma**: `Failed to fetch, uri=https://nutriapp-470k.onrender.com/auth/register`

**Causas posibles:**
- Render está "spinning down" (inactivo) y tarda 30-60 segundos en responder
- El endpoint no existe o hay un error en el backend
- Problema de CORS o timeout

**Solución implementada:**
- ✅ Reintentos automáticos (3 intentos con delays progresivos)
- ✅ Timeout aumentado a 60 segundos
- ✅ Mejor manejo de errores con logging detallado

### 2. Token local no válido
**Síntoma**: `401 Unauthorized` con token `bW5fYXRfZ21haWxfY29t...`

**Causa**: Se estaba generando un token local (base64) que NO es un JWT válido

**Solución implementada:**
- ✅ **NO se guarda token local si el backend no está disponible**
- ✅ Se retorna error `requires_login: true` para forzar login cuando el backend esté disponible
- ✅ El usuario debe hacer LOGIN después para obtener JWT válido

### 3. Error 403 en Supabase Storage
**Síntoma**: `StorageException(message: new row violates row-level security policy, statusCode: 403)`

**Causa**: Las políticas RLS (Row-Level Security) de Supabase están bloqueando la escritura

**Solución:**
- Verificar y actualizar las políticas de Storage en Supabase Dashboard

## ✅ Cambios Implementados

### 1. Reintentos en Registro Backend
- 3 intentos automáticos con delays progresivos (2s, 4s, 6s)
- Timeout de 60 segundos por intento
- Manejo inteligente de errores (no reintenta errores 400/409)

### 2. Prevención de Token Local
- Si el backend no responde después de 3 intentos, **NO se guarda token local**
- Se retorna error con `requires_login: true`
- El usuario debe hacer LOGIN cuando el backend esté disponible

### 3. Mejoras en UI
- Mensaje claro cuando el backend no está disponible
- Botón "Hacer Login" en el mensaje de error
- Cambio automático a pestaña de login

## 🔧 Pasos para Solucionar

### Paso 1: Configurar JWT_SECRET_KEY en Render (CRÍTICO)

1. Ve a **Render Dashboard** → Tu servicio → **Settings** → **Environment Variables**
2. Añade:
   ```
   JWT_SECRET_KEY=<genera-una-clave-aleatoria>
   ```
3. Para generar la clave:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
4. Copia el resultado y úsalo como valor
5. **Haz clic en "Save Changes"**

### Paso 2: Verificar Políticas de Supabase Storage

1. Ve a [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Storage** → **Policies**
4. Para el bucket `data`, asegúrate de tener una política que permita escritura:

```sql
-- Política para permitir escritura (INSERT/UPDATE)
CREATE POLICY "Allow public write access"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'data');

CREATE POLICY "Allow public update access"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'data')
WITH CHECK (bucket_id = 'data');
```

**O más permisivo (solo para desarrollo):**
```sql
-- Política muy permisiva (solo para desarrollo)
CREATE POLICY "Allow all operations on data bucket"
ON storage.objects
FOR ALL
TO public
USING (bucket_id = 'data')
WITH CHECK (bucket_id = 'data');
```

### Paso 3: Hacer Deploy del Último Commit

1. En Render Dashboard → **Manual Deploy** → **Deploy latest commit**
2. Espera a que termine el deploy (puede tardar 2-5 minutos)

### Paso 4: Probar Registro

1. **Espera 30-60 segundos** después del deploy (Render puede estar "spinning down")
2. Intenta registrar un nuevo usuario
3. Si falla con "Backend no disponible":
   - Espera otros 30 segundos
   - Intenta hacer **LOGIN** en lugar de registro
   - El usuario ya debería existir en el backend

## 📋 Flujo Correcto de Registro

### Escenario 1: Backend Disponible
1. Usuario intenta registrarse
2. App intenta registrar en backend (con 3 reintentos)
3. Backend crea usuario y retorna JWT
4. App guarda JWT y usuario puede usar la app ✅

### Escenario 2: Backend No Disponible (Spinning Down)
1. Usuario intenta registrarse
2. App intenta registrar en backend (3 intentos fallan)
3. App muestra mensaje: "Backend no disponible. Por favor, intenta hacer login."
4. Usuario hace **LOGIN** (el backend ya está despierto)
5. Backend retorna JWT válido
6. Usuario puede usar la app ✅

### Escenario 3: Backend Nunca Disponible
1. Usuario intenta registrarse
2. App intenta registrar en backend (3 intentos fallan)
3. App muestra mensaje de error
4. Usuario debe esperar a que el backend esté disponible
5. Cuando esté disponible, hacer LOGIN

## 🐛 Troubleshooting

### Error: "Failed to fetch" al registrar

**Causa**: Render está "spinning down" o hay un problema de red

**Solución:**
1. Espera 30-60 segundos
2. Intenta hacer **LOGIN** en lugar de registro
3. Si el usuario ya existe, el login funcionará
4. Si no existe, espera más tiempo y vuelve a intentar registro

### Error: "Could not validate credentials" después del registro

**Causa**: Se guardó un token local que no es válido

**Solución:**
1. **Cierra sesión** en la app
2. **Haz LOGIN** (no registro)
3. Esto obtendrá un JWT válido del backend

### Error: 403 en Supabase Storage

**Causa**: Políticas RLS bloqueando escritura

**Solución:**
1. Ve a Supabase Dashboard → Storage → Policies
2. Crea políticas permisivas para el bucket `data` (ver Paso 2 arriba)
3. Asegúrate de que el bucket sea público o que las políticas permitan escritura

## ✅ Verificación Final

Después de configurar todo:

1. ✅ `JWT_SECRET_KEY` configurado en Render
2. ✅ Políticas de Supabase Storage configuradas
3. ✅ Último commit desplegado en Render
4. ✅ Esperar 30-60 segundos después del deploy
5. ✅ Intentar registrar un nuevo usuario
6. ✅ Si falla, intentar hacer LOGIN
7. ✅ Verificar que el usuario aparece en Supabase Storage
8. ✅ Verificar que el token JWT funciona (no hay errores 401)

## 📝 Notas Importantes

- **Render Free Tier**: Se "duerme" después de 15 minutos de inactividad
- **Primera petición**: Puede tardar 30-60 segundos en "despertar"
- **Token Local**: Ya NO se usa - si el backend no está disponible, se fuerza login
- **Reintentos**: 3 intentos automáticos con delays progresivos
- **Timeout**: 60 segundos por intento (suficiente para Render)
