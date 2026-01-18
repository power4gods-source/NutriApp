# Verificar Registro de Usuarios y Autenticación

## 🔍 Problema Actual

Los usuarios nuevos no pueden usar la app después del registro porque:
- Error 401 "Could not validate credentials"
- El token JWT no se valida correctamente
- Los usuarios no se guardan correctamente en la base de datos

## ✅ Soluciones Implementadas

### 1. SECRET_KEY Persistente
- **Problema**: El SECRET_KEY se generaba aleatoriamente en cada reinicio, invalidando todos los tokens
- **Solución**: 
  - Prioridad 1: Variable de entorno `JWT_SECRET_KEY` (para Render)
  - Prioridad 2: Archivo local `jwt_secret_key.txt`
  - Prioridad 3: Generar nueva y guardarla

### 2. Logging Detallado
- Añadido logging en:
  - Registro de usuarios
  - Validación de tokens
  - Guardado en base de datos
  - Carga de usuarios

### 3. Verificación de Guardado
- Después de guardar usuario/perfil, se verifica que exista en la base de datos

## 🔧 Pasos para Verificar

### Paso 1: Configurar JWT_SECRET_KEY en Render

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

### Paso 2: Hacer Deploy del Último Commit

1. En Render Dashboard → **Manual Deploy** → **Deploy latest commit**
2. Espera a que termine el deploy

### Paso 3: Verificar Logs

Después de registrar un usuario, revisa los logs en Render:

**Deberías ver:**
```
📝 Registrando nuevo usuario: email@example.com
👤 Creando usuario con rol: user
💾 Guardando usuario en base de datos...
✅ Usuario guardado: user_id (email@example.com)
✅ Verificación: Usuario user_id existe en base de datos
📝 Creando perfil para usuario: user_id
💾 Guardando perfil en base de datos...
✅ Perfil guardado para: user_id
✅ Verificación: Perfil user_id existe en base de datos
🔑 Generando token JWT para: user_id
✅ Token generado (primeros 20 chars): ...
✅ Registro completado para: email@example.com (rol: user)
```

**Cuando se valida un token:**
```
🔍 Validando token JWT (primeros 20 chars): ...
✅ Token válido para usuario: user_id
📋 Verificando usuario en base de datos: user_id
✅ Usuario encontrado: user_id
```

### Paso 4: Verificar en Supabase

1. Ve a [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Storage** → **data** bucket
4. Deberías ver:
   - `users.json` - Con el nuevo usuario
   - `profiles.json` - Con el nuevo perfil

## 🐛 Troubleshooting

### Error: "Could not validate credentials"

**Posibles causas:**
1. **SECRET_KEY cambió**: Verifica que `JWT_SECRET_KEY` esté configurado en Render
2. **Usuario no existe**: Verifica en los logs que el usuario se guardó correctamente
3. **Token no se envía**: Verifica en los logs del frontend que el token se está enviando

**Solución:**
- Revisa los logs en Render para ver qué está pasando
- Verifica que el usuario exista en `users.json` en Supabase
- Asegúrate de que `JWT_SECRET_KEY` esté configurado correctamente

### Usuario no se guarda en Supabase

**Verifica:**
1. Que Supabase esté configurado correctamente (URL y KEY)
2. Que las políticas de Storage permitan escritura
3. Los logs del backend para ver errores de Supabase

## 📋 Checklist de Verificación

- [ ] `JWT_SECRET_KEY` configurado en Render
- [ ] Último commit desplegado en Render
- [ ] Usuario se registra correctamente (ver logs)
- [ ] Usuario aparece en `users.json` en Supabase
- [ ] Perfil aparece en `profiles.json` en Supabase
- [ ] Token JWT se genera correctamente
- [ ] Token se guarda en el frontend
- [ ] Token se envía en las peticiones (ver logs)
- [ ] Token se valida correctamente (ver logs del backend)
- [ ] Usuario puede hacer peticiones autenticadas sin error 401

## 🔐 Permisos de Usuario

### Usuario Normal (role: "user")
- ✅ Puede crear/editar/eliminar sus propias recetas privadas
- ✅ Puede publicar sus recetas privadas
- ✅ Puede quitar sus recetas de públicas
- ✅ Puede añadir favoritos
- ✅ Puede seguir usuarios
- ✅ Puede registrar consumo
- ✅ Puede gestionar sus ingredientes
- ❌ NO puede editar recetas generales (solo admin)
- ❌ NO puede editar recetas públicas de otros usuarios (solo admin o el dueño)

### Admin (role: "admin", solo power4gods@gmail.com)
- ✅ Todo lo que puede hacer un usuario normal
- ✅ Puede editar/eliminar recetas generales
- ✅ Puede editar/eliminar cualquier receta pública
