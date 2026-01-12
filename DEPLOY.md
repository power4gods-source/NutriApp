# Guía de Despliegue del Backend

## 🚀 Opciones de Despliegue

### Railway (Recomendado - Más Fácil)

1. **Crear cuenta:**
   - Ve a [railway.app](https://railway.app)
   - Inicia sesión con GitHub

2. **Crear nuevo proyecto:**
   - Click en "New Project"
   - Selecciona "Deploy from GitHub repo"
   - Selecciona tu repositorio

3. **Configuración automática:**
   - Railway detectará automáticamente Python/FastAPI
   - Usará el `Procfile` y `requirements.txt`
   - El despliegue comenzará automáticamente

4. **Obtener URL:**
   - Una vez desplegado, Railway te dará una URL pública
   - Ejemplo: `https://tu-app.railway.app`

### Render

1. **Crear cuenta:**
   - Ve a [render.com](https://render.com)
   - Inicia sesión con GitHub

2. **Crear Web Service:**
   - Click en "New +" → "Web Service"
   - Conecta tu repositorio de GitHub

3. **Configuración:**
   - **Name:** `nutritrack-backend` (o el nombre que prefieras)
   - **Environment:** `Python 3`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`

4. **Desplegar:**
   - Click en "Create Web Service"
   - Render construirá y desplegará tu aplicación

### Heroku

1. **Instalar Heroku CLI:**
   ```bash
   # Windows (con Chocolatey)
   choco install heroku-cli
   
   # O descarga desde heroku.com
   ```

2. **Login:**
   ```bash
   heroku login
   ```

3. **Crear aplicación:**
   ```bash
   heroku create tu-app-name
   ```

4. **Desplegar:**
   ```bash
   git push heroku main
   ```

## 📝 Configuración Post-Despliegue

### Actualizar URL en Flutter

Después de desplegar, actualiza la URL del backend en tu app Flutter:

1. Edita `nutri_track/lib/config/app_config.dart`
2. Actualiza la URL por defecto o configura la detección automática
3. Ejemplo:
   ```dart
   static String get defaultBackendUrl {
     return 'https://tu-app.railway.app'; // Tu URL de despliegue
   }
   ```

### Variables de Entorno (Opcional)

Si necesitas configurar variables de entorno:

- **Railway:** Settings → Variables
- **Render:** Environment → Environment Variables
- **Heroku:** `heroku config:set KEY=value`

## ✅ Verificación

Después del despliegue, verifica que funciona:

```bash
curl https://tu-url.railway.app/health
```

Deberías recibir:
```json
{
  "status": "ok",
  "message": "Backend is running and accessible from network",
  ...
}
```

## 🔒 Notas de Seguridad

1. **CORS:** El backend está configurado con `allow_origins=["*"]` para desarrollo. En producción, considera restringir a dominios específicos.

2. **HTTPS:** Los servicios en la nube proporcionan HTTPS automáticamente.

3. **Secret Key:** El backend genera una SECRET_KEY aleatoria. Para producción, considera usar una variable de entorno fija.

## 🆘 Solución de Problemas

### El despliegue falla

- Verifica que `requirements.txt` esté actualizado
- Verifica que `Procfile` esté presente
- Revisa los logs del servicio de despliegue

### La app no puede conectar al backend

- Verifica que la URL esté correcta en `app_config.dart`
- Verifica que el backend esté corriendo (usa `/health`)
- Verifica la configuración de CORS si es necesario
