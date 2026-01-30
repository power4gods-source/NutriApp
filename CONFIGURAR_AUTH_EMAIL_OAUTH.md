# Configuración: Email corporativo NutriTrack y login Google/Apple

## 1. Email corporativo NutriTrack (olvidé contraseña / restablecer)

El backend envía correos desde una cuenta corporativa NutriTrack. Configura estas **variables de entorno** (en Render, Railway, o en tu `.env` local):

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `NUTRITRACK_EMAIL` | Email remitente (NutriTrack) | `noreply@nutritrack.app` |
| `NUTRITRACK_EMAIL_PASSWORD` | Contraseña o “App Password” del correo | (tu contraseña) |
| `SMTP_HOST` | Servidor SMTP | `smtp.gmail.com` |
| `SMTP_PORT` | Puerto (587 TLS, 465 SSL) | `587` |
| `SMTP_USE_TLS` | Usar TLS | `true` |
| `NUTRITRACK_SENDER_NAME` | Nombre visible en los correos | `NutriTrack` |
| `RESET_PASSWORD_BASE_URL` | URL base del enlace de restablecer (web o deep link) | `https://nutritrack.app/reset-password` |

### Gmail

- Usa una “Contraseña de aplicación” (no la contraseña normal): Cuenta Google → Seguridad → Verificación en 2 pasos → Contraseñas de aplicación.
- `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_USE_TLS=true`.

### Enlace de restablecer

- El correo incluye un enlace: `{RESET_PASSWORD_BASE_URL}?token=XXX`.
- En la app, el usuario puede ir a “Ya tengo el token” y pegar el `token` que recibe por correo (o abrir la URL en web y redirigir a la app con el token).

---

## 2. Activar login con Google y Apple en la app Flutter

Por defecto la app compila **sin** los paquetes `google_sign_in` y `sign_in_with_apple` (stub). Para que los botones "Continuar con Google" y "Continuar con Apple" funcionen:

1. En `nutri_track/pubspec.yaml`, descomenta: `google_sign_in: ^6.2.2` y `sign_in_with_apple: ^6.1.3`.
2. Ejecuta en la carpeta nutri_track: `flutter pub get`.
3. Copia el contenido de `lib/services/social_auth_google_apple_REAL.dart.example` en `lib/services/social_auth_google_apple.dart` (sobrescribe).

---

## 3. Login con Google (detalles)

- **Backend:** No requiere variables extra; el backend valida el `id_token` con `https://oauth2.googleapis.com/tokeninfo`.
- **Flutter (Android):** Por defecto `google_sign_in` usa el SHA-1 del keystore. Para producción, añade el SHA-1 de tu keystore de release en [Google Cloud Console](https://console.cloud.google.com/) (APIs & Services → Credentials) en la credencial de tipo “Android”.
- **Flutter (iOS):** Añade la URL de scheme inverso en Xcode y en la consola de Google si usas OAuth client iOS.

---

## 4. Login con Apple

- **Backend (opcional):** Si quieres validar el `aud` del JWT de Apple, define:
  - `APPLE_CLIENT_ID`: Bundle ID de tu app iOS (ej. `com.tudominio.nutritrack`).
- **Flutter (iOS):**
  1. En Xcode: selecciona el target Runner → Signing & Capabilities → **+ Capability** → **Sign in with Apple**.
  2. El archivo `ios/Runner/Runner.entitlements` ya incluye la capacidad; si Xcode no lo usa, asocia ese entitlements al target Runner en “Build Settings” → “Code Signing Entitlements”.
- **Flutter (Android):** Sign in with Apple en Android funciona con el paquete `sign_in_with_apple`; no hace falta configuración extra en backend para el token.

---

## 5. Resumen de endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/auth/forgot-password` | Body: `{ "email": "..." }`. Envía correo con enlace de restablecer. |
| POST | `/auth/reset-password` | Body: `{ "token": "...", "new_password": "..." }`. Restablece contraseña y devuelve JWT. |
| POST | `/auth/google` | Body: `{ "id_token": "..." }`. Login/registro con Google. |
| POST | `/auth/apple` | Body: `{ "identity_token": "...", "user_apple_id": "...", "email": "...", "full_name": "..." }`. Login/registro con Apple. |
| POST | `/profile/password` | Con Bearer token. Body: `{ "current_password": "...", "new_password": "..." }`. Cambiar contraseña. |
