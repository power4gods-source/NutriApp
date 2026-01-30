# Guía paso a paso: Firebase + Render + NutriTrack

Ya tienes el proyecto creado en Firebase. Sigue estos pasos en orden.

**Checklist rápido**
- [ ] Parte 1: Firebase Console – Firestore + Storage + descargar JSON cuenta de servicio  
- [ ] Parte 2: Flutter – `flutterfire configure`, `flutter pub get`, `flutter run`  
- [ ] Parte 3: Render – crear Web Service, añadir `FIREBASE_SERVICE_ACCOUNT_JSON` (y opcional `JWT_SECRET_KEY`)  
- [ ] Parte 4: Subir JSON – script `upload_jsons_to_firestore.py` con credenciales en env  
- [ ] Parte 5: Git – commit (sin subir el JSON de cuenta); actualizar `FIREBASE_SERVICE_ACCOUNT_JSON` en Render cuando cambies la clave  

---

## Parte 1: Configurar Firebase Console

### 1.1 Activar Firestore
1. Entra en [Firebase Console](https://console.firebase.google.com/) y abre tu proyecto.
2. Menú izquierdo → **Build** → **Firestore Database**.
3. Clic en **Create database**.
4. Elige **Start in test mode** (o producción con reglas que tú definas).
5. Selecciona la región (ej. `europe-west1`) y **Enable**.

### 1.2 Activar Storage (para avatares)
1. Menú izquierdo → **Build** → **Storage**.
2. **Get started** → **Next** → **Done**.
3. En la pestaña **Rules**, deja reglas que permitan lectura/escritura autenticada o temporalmente en test mode según tu seguridad.

### 1.3 Obtener la cuenta de servicio (para Render)
1. Menú izquierdo → ⚙️ **Project settings** (Configuración del proyecto).
2. Pestaña **Service accounts**.
3. Clic en **Generate new private key** → **Generate key**. Se descargará un JSON.
4. **Guarda este archivo en un lugar seguro.** Lo usarás como valor de `FIREBASE_SERVICE_ACCOUNT_JSON` en Render (no subas este JSON a Git).

---

## Parte 2: Configurar la app Flutter (nutri_track)

### 2.0 Instalar Firebase CLI (obligatorio antes de `flutterfire configure`)
FlutterFire CLI necesita el **Firebase CLI** instalado. En Windows:

**Opción A – Con Node.js (recomendado)**  
1. Instala [Node.js](https://nodejs.org/) (LTS, v18 o superior) si no lo tienes. Incluye npm.
2. En PowerShell o CMD (como usuario normal):
   ```powershell
   npm install -g firebase-tools
   ```
3. Inicia sesión en Firebase:
   ```powershell
   firebase login
   ```
   Se abrirá el navegador para que inicies sesión con tu cuenta de Google.
4. Comprueba que funciona:
   ```powershell
   firebase --version
   ```

**Opción B – Sin Node.js (binario standalone)**  
1. Ve a [Firebase CLI - Install the Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli).
2. Descarga el instalador para Windows (standalone binary).
3. Instala y añade `firebase` al PATH si el instalador lo indica.
4. En PowerShell: `firebase login` y luego `firebase --version`.

Cuando `firebase --version` funcione, continúa con 2.1.

### 2.1 FlutterFire CLI y firebase_options
1. Abre una terminal en la carpeta del proyecto (donde está `nutri_track`).
2. Instala FlutterFire CLI (una vez):
   ```bash
   dart pub global activate flutterfire_cli
   ```
3. Entra en la carpeta de la app:
   ```bash
   cd nutri_track
   ```
4. Vincula el proyecto con Firebase y genera la config:
   ```bash
   flutterfire configure
   ```
   - Elige tu proyecto de Firebase.
   - Se generarán/actualizarán: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`.

### 2.2 Dependencias y ejecución local
1. En la misma carpeta `nutri_track`:
   ```bash
   flutter pub get
   flutter run
   ```
2. La app usará Firestore y Storage de tu proyecto. Si no hay datos aún, algunas pantallas pueden estar vacías hasta que subas los JSON (Parte 4).

---

## Parte 3: Desplegar el backend en Render y FIREBASE_SERVICE_ACCOUNT_JSON

### 3.1 Crear el servicio en Render
1. Entra en [Render](https://dashboard.render.com/).
2. **New** → **Web Service**.
3. Conecta el repositorio de NutriApp (GitHub/GitLab).
4. Configuración sugerida:
   - **Name:** `nutritrack-api` (o el que prefieras).
   - **Region:** la más cercana a tus usuarios.
   - **Branch:** la rama que uses (ej. `main` o `Final-firebase`).
   - **Root Directory:** vacío (el backend está en la raíz con `main.py`).
   - **Runtime:** Python 3.
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`

### 3.2 Añadir FIREBASE_SERVICE_ACCOUNT_JSON
1. En el servicio de Render → **Environment** (Environment variables).
2. **Add Environment Variable**:
   - **Key:** `FIREBASE_SERVICE_ACCOUNT_JSON`
   - **Value:** el **contenido completo** del JSON de la cuenta de servicio (el que descargaste en 1.3).
   - Cómo copiarlo:
     - Abre el JSON en un editor de texto.
     - Copia **todo** (desde `{` hasta `}`).
     - Pégalo en el campo Value. En Render suele aceptarse como una sola línea; si pide formato, pega el JSON sin cambiar las comillas.
3. Guarda. Render redesplegará el servicio.

### 3.3 Otras variables (recomendadas)
- `JWT_SECRET_KEY`: una cadena aleatoria larga para firmar los tokens (ej. generada con `openssl rand -base64 32`).
- Si usas email (recuperar contraseña, etc.): las que tengas en `email_service.py` (SMTP, etc.).

### 3.4 Comprobar que el backend usa Firestore
1. Tras el deploy, abre la URL del servicio (ej. `https://nutritrack-api.onrender.com`).
2. Prueba: `https://tu-url/health`. Debería responder OK.
3. En los **Logs** del servicio en Render no debería aparecer "Firebase no configurado"; si todo está bien, verás algo como "Firebase Firestore inicializado" en el arranque (si el código hace ese log).

---

## Parte 4: Subir los JSON a Firestore

El backend y la app esperan los datos en Firestore así:
- **Colección:** `storage`
- **Documento:** ID = nombre del archivo (ej. `users.json`, `recipes.json`). Si el “archivo” tiene ruta tipo `users/xxx.json`, el ID es `users_xxx.json` (slash → guión bajo).
- **Campo del documento:** `data` = objeto JSON (el contenido del archivo).

Tienes dos formas de subir los JSON.

### Opción A: Desde la app Flutter (sincronización)
1. Si tienes los JSON en tu máquina (en la raíz del backend, ej. `users.json`, `recipes.json`, etc.), puedes usar la pantalla **Sincronizar** de la app:
   - Inicia sesión en la app.
   - Menú → **Sincronizar con Firestore**.
   - Por ahora la subida masiva puede no estar implementada; en ese caso usa la Opción B.

### Opción B: Script Python (recomendado para la primera carga)
En el repo ya existe el script `upload_jsons_to_firestore.py` en la raíz del proyecto.

1. **Credenciales en tu máquina** (nunca las subas a Git):
   - **Opción 1 – Variable con el JSON:** En PowerShell (Windows), desde la raíz del proyecto:
     ```powershell
     $env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content -Path "C:\ruta\a\tu\cuenta-servicio-descargada.json" -Raw
     ```
   - **Opción 2 – Archivo:** Copia el JSON descargado a un archivo (ej. `service-account.json`) en una carpeta que no subas a Git y:
     ```powershell
     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\mball\Downloads\NutriApp\service-account.json"
     ```
2. **Ejecutar el script** desde la raíz del proyecto (donde está `main.py`):
   ```powershell
   cd C:\Users\mball\Downloads\NutriApp
   python upload_jsons_to_firestore.py
   ```
   El script leerá los JSON de la carpeta actual y los subirá a Firestore (colección `storage`, documento = nombre del archivo, campo `data`).
3. **followers.json y chats.json:** Si no existen localmente, el script los sube vacíos (`{}`). El backend los rellena cuando un usuario sigue a otro (followers) y cuando dos **conexiones mutuas** (se siguen entre sí) envían mensajes (chats). Solo los usuarios que se siguen mutuamente pueden chatear.

### Archivos JSON que debe conocer la app/backend
- `recipes.json`
- `recipes_private.json`
- `recipes_public.json`
- `users.json`
- `profiles.json`
- `foods.json`
- `ingredient_food_mapping.json`
- `consumption_history.json`
- `meal_plans.json`
- `nutrition_stats.json`
- `user_goals.json`
- `followers.json`

Puedes crear archivos vacíos `{}` o con estructura mínima para los que no tengas datos aún.

---

## Parte 5: Git – Commit y actualizar FIREBASE_SERVICE_ACCOUNT_JSON

### 5.1 Qué SÍ hacer commit
- Todo el código (Flutter, Python, `firebase_options.dart` si lo tienes generado por FlutterFire; en muchos equipos sí se sube).
- `requirements.txt`, `pubspec.yaml`, configs de Render (Blueprint si lo usas).
- Documentación (esta guía, `MIGRACION_FIREBASE.md`, etc.).
- **No** hagas commit del archivo JSON de la cuenta de servicio (ej. `service-account.json`, `*-firebase-adminsdk-*.json`). Añádelo a `.gitignore`.

### 5.2 .gitignore (recomendado)
En la raíz del proyecto, asegúrate de tener por ejemplo:
```
# Firebase / Google
**/service-account*.json
**/*-firebase-adminsdk-*.json
**/GoogleService-Info.plist
# Opcional: si no quieres subir firebase_options con claves
# lib/firebase_options.dart
```
(Si quieres que cada desarrollador genere su propio `firebase_options.dart` con `flutterfire configure`, puedes ignorar `firebase_options.dart`; si prefieres compartir el mismo proyecto Firebase, no lo ignores.)

### 5.3 Hacer commit
1. Desde la raíz del repo:
   ```bash
   git status
   git add .
   # Quita del staging cualquier archivo de cuenta de servicio si se hubiera colado
   git reset -- service-account.json
   git reset -- *firebase*adminsdk*.json
   git commit -m "Migración a Firebase: Firestore + Storage, backend en Render con FIREBASE_SERVICE_ACCOUNT_JSON"
   git push origin tu-rama
   ```

### 5.4 Actualizar FIREBASE_SERVICE_ACCOUNT_JSON (rotar clave o corregir)
Cuando quieras **rotar la clave** o **corregir el JSON** en Render:

1. **Firebase Console** → ⚙️ **Project settings** → **Service accounts** → **Generate new private key** (descarga un nuevo JSON). Si solo quieres pegar de nuevo el mismo JSON, no hace falta generar otra clave.
2. Abre el archivo JSON y copia **todo** el contenido (desde `{` hasta `}`).
3. **Render** → tu Web Service → **Environment**.
4. Busca la variable **Key:** `FIREBASE_SERVICE_ACCOUNT_JSON`, clic en **Edit** (o el lápiz).
5. En **Value** pega el contenido completo del JSON (una sola línea o con saltos, Render suele aceptar ambos).
6. **Save**. Render redesplegará el servicio con la nueva configuración.
7. **No** hagas commit del archivo JSON ni lo subas a Git; solo actualizas el valor en Render.

---

## Resumen rápido

| Paso | Dónde | Acción |
|------|--------|--------|
| 1 | Firebase Console | Activar Firestore y Storage; descargar JSON de cuenta de servicio |
| 2 | `nutri_track` | `flutterfire configure`, `flutter pub get`, `flutter run` |
| 3 | Render | Crear Web Service, poner `FIREBASE_SERVICE_ACCOUNT_JSON` (y opcionalmente `JWT_SECRET_KEY`) |
| 4 | Local o script | Subir JSON a Firestore (colección `storage`, doc id = nombre archivo, campo `data`) |
| 5 | Git | Commit de código y docs; **no** commit del JSON de cuenta; actualizar `FIREBASE_SERVICE_ACCOUNT_JSON` en Render cuando rotes la clave |

Si quieres, el siguiente paso puede ser que te escriba el script `upload_jsons_to_firestore.py` listo para copiar y usar en tu repo.
