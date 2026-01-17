# Desplegar Backend en la Nube (Para Funcionar Offline)

## ¿Por qué necesitas esto?

Para que la app funcione **sin el PC encendido**, necesitas desplegar el backend en un servicio en la nube. Así funcionará 24/7 desde cualquier lugar.

## Opciones de Deployment

### Opción 1: Render (Recomendado - Gratis)

**Ventajas:**
- ✅ Plan gratuito disponible
- ✅ Fácil de configurar
- ✅ Auto-deploy desde GitHub
- ✅ HTTPS incluido

**Pasos:**

1. **Preparar el proyecto:**
   - Asegúrate de que `main.py` esté en la raíz
   - Crea un archivo `requirements.txt` con las dependencias
   - Crea un archivo `Procfile` (ya lo tienes)

2. **Subir a GitHub:**
   ```bash
   git add .
   git commit -m "Ready for cloud deployment"
   git push origin main
   ```

3. **Crear cuenta en Render:**
   - Ve a [render.com](https://render.com)
   - Crea una cuenta (gratis)

4. **Crear Web Service:**
   - Haz clic en "New" > "Web Service"
   - Conecta tu repositorio de GitHub
   - Configura:
     - **Name**: `nutriapp-backend`
     - **Environment**: `Python 3`
     - **Build Command**: `pip install -r requirements.txt`
     - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
     - **Plan**: Free

5. **Variables de Entorno:**
   - En "Environment Variables", añade:
     - `PORT`: `8000` (Render lo asigna automáticamente, pero por si acaso)

6. **Deploy:**
   - Haz clic en "Create Web Service"
   - Espera 5-10 minutos
   - Obtendrás una URL como: `https://nutriapp-backend.onrender.com`

7. **Actualizar la App:**
   - Edita `nutri_track/lib/config/app_config.dart`
   - Cambia la URL del backend a la de Render

### Opción 2: Railway (Gratis con límites)

**Pasos similares a Render**, pero en [railway.app](https://railway.app)

### Opción 3: Fly.io (Gratis)

**Pasos similares**, pero en [fly.io](https://fly.io)

## Actualizar la App para Usar Backend en la Nube

Una vez que tengas la URL del backend desplegado:

1. **Edita `nutri_track/lib/config/app_config.dart`:**
   ```dart
   static String get defaultBackendUrl {
     // Cambia esto por tu URL de Render/Railway/etc
     return 'https://nutriapp-backend.onrender.com';
   }
   ```

2. **O mejor, permite configurarlo dinámicamente:**
   - La app ya tiene `AppConfig.setBackendUrl()` para esto
   - Puedes añadir una pantalla de configuración en la app

## Importante: Archivos JSON en la Nube

Cuando despliegues el backend en la nube, los archivos JSON (`users.json`, `recipes.json`, etc.) se guardarán en el servidor de la nube, no en tu PC.

**Opciones:**
1. **Usar Supabase Storage** (recomendado): Los archivos se guardan en Supabase, no en el servidor
2. **Sincronizar con el servidor**: El backend puede leer/escribir desde Supabase Storage

## Configurar Backend para Usar Supabase Storage

Para que el backend en la nube también use Supabase:

1. Instala la librería de Supabase en Python:
   ```bash
   pip install supabase
   ```

2. Modifica `main.py` para leer/escribir desde Supabase Storage en lugar de archivos locales

3. Esto asegura que los datos estén siempre sincronizados

## Verificar que Funciona

1. Despliega el backend
2. Obtén la URL (ej: `https://nutriapp-backend.onrender.com`)
3. Prueba: `https://nutriapp-backend.onrender.com/health`
4. Debería responder: `{"status": "ok"}`
5. Actualiza la URL en la app
6. Prueba desde tu móvil (con el PC apagado)
