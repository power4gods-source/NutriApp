# NutriTrack - Aplicación de Nutrición y Recetas

Aplicación móvil completa para gestión de recetas, seguimiento nutricional y planificación de comidas.

## 🏗️ Estructura del Proyecto

```
NutriApp/
├── main.py                    # Backend FastAPI
├── requirements.txt           # Dependencias Python
├── Procfile                   # Configuración para despliegue en la nube
├── runtime.txt                # Versión de Python
├── *.json                     # Archivos de datos (recetas, usuarios, etc.)
│
└── nutri_track/               # App Flutter
    ├── lib/                   # Código fuente
    ├── android/               # Configuración Android
    └── pubspec.yaml           # Dependencias Flutter
```

## 🚀 Inicio Rápido

### Backend Local

```bash
# Instalar dependencias
pip install -r requirements.txt

# Ejecutar servidor
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Despliegue en la Nube

El backend está preparado para desplegarse en servicios como:
- **Railway**: Conecta tu repositorio y despliega automáticamente
- **Render**: Crea un Web Service y conecta tu repositorio
- **Heroku**: Usa el Procfile incluido

### App Flutter

```bash
cd nutri_track
flutter pub get
flutter run
```

## 📱 Publicación en Play Store y App Store

La app está preparada para **Android e iOS**. Las funcionalidades no disponibles se muestran con **"Pronto..."** en la interfaz.

- **Android:** `android:label="NutriTrack"`, `minSdk 21`, `targetSdk 34`. Para Play Store: crear keystore y configurar firma release en `nutri_track/android/app/build.gradle.kts`.
- **iOS:** `CFBundleDisplayName = NutriTrack`, descripciones de privacidad para cámara/galería en `Info.plist`. Para App Store: certificados y provisioning en Xcode.

**Plan de releases:** Ver [PLAN_DE_RELEASES.md](PLAN_DE_RELEASES.md) para el roadmap (login Google/Apple, recuperación de contraseña, donaciones, límite de generación de recetas, emails, etc.).

## 📱 Compilar APK para Android

```bash
cd nutri_track
flutter build apk --release
```

El APK estará en: `nutri_track/build/app/outputs/flutter-apk/app-release.apk`

## 📱 Compilar para iOS

```bash
cd nutri_track
flutter build ios --release
```

Abrir `ios/Runner.xcworkspace` en Xcode para configurar firma y subir a App Store Connect.

## 🔐 Credenciales de Prueba

- **Email**: power4gods@gmail.com
- **Password**: mabalfor

## ✨ Funcionalidades

- ✅ Autenticación de usuarios
- ✅ Gestión de recetas (generales, favoritas, privadas, públicas)
- ✅ Búsqueda avanzada de recetas
- ✅ Seguimiento nutricional
- ✅ Gestión de ingredientes
- ✅ Lista de compra
- ✅ Sincronización con Firebase
- ✅ Sugerencias de menú con IA

## 🛠️ Tecnologías

**Backend:**
- FastAPI
- Python 3.8+
- JWT Authentication

**Frontend:**
- Flutter
- Firebase (Storage, Firestore)
- Provider (State Management)

## 📦 Dependencias

**Backend:**
```bash
pip install -r requirements.txt
```

**Frontend:**
```bash
cd nutri_track
flutter pub get
```

## ☁️ Despliegue

### Railway (Recomendado)

1. Crea una cuenta en [railway.app](https://railway.app)
2. Conecta tu repositorio de GitHub
3. Railway detectará automáticamente Python/FastAPI
4. El backend estará disponible en una URL pública

### Render

1. Crea una cuenta en [render.com](https://render.com)
2. Crea un nuevo "Web Service"
3. Conecta tu repositorio
4. Configura:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

### Configuración de la App Flutter

Después de desplegar el backend, actualiza la URL en:
- `nutri_track/lib/config/app_config.dart`

Usa la URL pública proporcionada por el servicio de despliegue.
