# Migración a Firebase + Render (Spark + Free)

Objetivo: migrar todo a **Firebase (Spark)** + **Render (free)** paso a paso, sin perder dependencias y asegurando que todo funciona.

---

## Estado actual

| Componente | Uso |
|------------|-----|
| **Render** | Backend FastAPI (auth, recetas, perfiles, etc.) |
| **Supabase** | Storage JSON (users, recipes, profiles, foods, etc.); sync en la app; fallback auth cuando el backend no está |
| **Flutter** | AuthService (backend + fallback Supabase), SupabaseSyncService, SupabaseUserService |

---

## Plan de pasos (sin romper nada)

### Paso 1: Añadir Firebase a la app Flutter (Spark) — SIN quitar Supabase ✅

**Objetivo:** Firebase inicializado junto con Supabase. Crashlytics activo. Todo lo demás igual.

**Hecho en el repo:**
- ✅ `nutri_track/pubspec.yaml`: añadidos `firebase_core`, `firebase_crashlytics`.
- ✅ `lib/firebase_options.dart`: stub con valores placeholder (la app compila).
- ✅ `main.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, Crashlytics para errores fatales, **Supabase se mantiene**.
- ✅ Backend (main.py) y supabase_storage.py sin cambios.

**Qué debes hacer tú (para que Firebase y Crashlytics usen tu proyecto):**
1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/) (plan Spark).
2. Añade las apps Android e iOS (paquetes/bundle ID de nutri_track).
3. En la carpeta **nutri_track** ejecuta:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Eso genera `google-services.json` (Android), `GoogleService-Info.plist` (iOS) y sobrescribe `lib/firebase_options.dart` con tus claves.
4. En Android: si hace falta, en `android/build.gradle.kts` o `android/app/build.gradle.kts` asegura que esté el plugin de Google Services (FlutterFire suele añadirlo).
5. Ejecuta `flutter pub get` en nutri_track y prueba la app.

**Verificación:** La app arranca con Firebase y Supabase; si hay crash, Crashlytics lo verá en la consola de Firebase (cuando el proyecto esté configurado).

---

### Paso 2: Añadir Firestore (o Realtime DB) en la app — dual con Supabase

**Objetivo:** Nuevo servicio que lee/escribe en Firestore los mismos datos que hoy están en Supabase Storage. Elegir origen por config (Firebase o Supabase) para poder cambiar sin romper.

- Añadir `cloud_firestore` en pubspec.
- Crear `FirebaseSyncService` (igual API que SupabaseSyncService: upload/download JSON por “nombre de archivo” mapeado a documentos/colecciones).
- Añadir en config algo tipo `useFirebaseForSync: bool` (o leer de Firebase Remote Config más adelante). Si `true`, usar FirebaseSyncService; si `false`, SupabaseSyncService.
- **No** quitar Supabase todavía. Backend sigue usando Supabase.
- **Verificación:** Con `useFirebaseForSync == false` todo igual; con `true` y datos ya migrados, la app usa Firebase para sync.

---

### Paso 3: Migrar datos Supabase → Firestore (una vez)

**Objetivo:** Copiar los JSON actuales (users, recipes, profiles, etc.) de Supabase Storage a Firestore (o Realtime DB), con la estructura que use `FirebaseSyncService`.

- Script o instrucciones para: leer cada JSON desde Supabase (o desde los archivos locales que usa el backend), escribir en Firestore con la estructura acordada.
- **Verificación:** En Firebase Console se ven los datos. La app con `useFirebaseForSync == true` los lee bien.

---

### Paso 4: Backend (Render) usa Firebase para persistencia ✅

**Objetivo:** El backend deja de usar Supabase Storage y pasa a leer/escribir en Firestore vía Firebase Admin SDK.

**Hecho en el repo:** `requirements.txt` incluye `firebase-admin`; `firebase_storage.py` implementa load/save en Firestore (colección `storage`); `main.py` usa `firebase_storage` con fallback a archivo local. `supabase_storage.py` se mantiene por si hay que revertir.

**Qué hacer en Render:** Añadir variable `FIREBASE_SERVICE_ACCOUNT_JSON` con el JSON de la cuenta de servicio (Firebase Console → Cuentas de servicio → Generar clave). Opcional: `FIRESTORE_STORAGE_COLLECTION` (por defecto `storage`).

- En el proyecto de Render: añadir `firebase-admin` (Python) y credenciales (service account JSON en env).
- Crear `firebase_storage.py` (o extender el actual) con `load_json_from_firebase`, `save_json_to_firebase`, y usarlos con el mismo “nombre lógico” de archivo (users, recipes, etc.).
- En `main.py`: cambiar `load_json_with_fallback` / `save_json_with_sync` para que usen Firebase primero y local como fallback (o solo Firebase). Mantener fallback a archivo local si quieres.
- **No** borrar aún `supabase_storage.py` por si hay que revertir.
- **Verificación:** Backend en Render lee/escribe en Firestore; la app (con sync por Firebase) y el backend ven los mismos datos.

---

### Paso 5: App Flutter solo Firebase para sync; quitar Supabase ✅

**Objetivo:** Una sola fuente de verdad: Firebase. Quitar Supabase de la app.

**Hecho en el repo:**
- ✅ Reemplazados SupabaseSyncService, SupabaseUserService, SupabaseRecipeService por FirebaseSyncService, FirebaseUserService, FirebaseRecipeService en toda la app.
- ✅ Auth sigue con backend (Render); login/registro usan Firestore para datos de usuario cuando el backend no está.
- ✅ Quitada inicialización de Supabase en `main.dart`; solo Firebase (core, Crashlytics, Firestore).
- ✅ Quitada dependencia `supabase_flutter` del pubspec; añadidos `cloud_firestore`, `firebase_storage`.
- ✅ Subida de avatar en EditProfileScreen pasa a Firebase Storage (en lugar de Supabase Storage).
- ✅ Eliminados archivos: `supabase_config.dart`, `supabase_sync_service.dart`, `supabase_user_service.dart`, `supabase_recipe_service.dart`.

**Verificación:** Ejecutar `flutter pub get` en `nutri_track` y `flutter run`; la app arranca solo con Firebase; login, sync y datos usan Firestore.

---

### Paso 6 (opcional): Firebase Auth

**Objetivo:** Si quieres Auth en Firebase (Google, Apple, email): migrar login a Firebase Auth y que el backend (Render) verifique el token de Firebase en cada request, creando/actualizando usuario interno si hace falta.

- Implementar en la app: Firebase Auth (email, Google, Apple).
- Backend: endpoint que recibe el token de Firebase, lo verifica con Admin SDK, y devuelve o crea sesión (JWT propio o solo token de Firebase).
- **Verificación:** Login con Google/Apple/email vía Firebase; backend reconoce al usuario.

---

## Resumen de dependencias

- **Paso 1:** Flutter usa Firebase (core + Crashlytics). Sigue usando Supabase y Render. Backend sin cambios.
- **Pasos 2–3:** Flutter puede leer/escribir en Firestore; datos copiados de Supabase a Firebase.
- **Paso 4:** Backend (Render) usa Firebase en lugar de Supabase para persistencia.
- **Paso 5:** Flutter deja de usar Supabase; solo Firebase + Render.
- **Paso 6 (opcional):** Auth en Firebase; Render valida tokens de Firebase.

Coste objetivo: **Firebase Spark + Render free** hasta que el uso lo justifique.
