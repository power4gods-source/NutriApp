plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase plugin removido - ahora usamos Supabase
}

android {
    namespace = "com.mycompany.nutrirecipeapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID único: cambiar a tu dominio para Play Store (ej. com.tudominio.nutritrack)
        applicationId = "com.mycompany.nutrirecipeapp"
        minSdk = flutter.minSdkVersion  // Android 5.0+ para máxima compatibilidad
        targetSdk = 34  // Requerido por Play Store 2024+
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Para Play Store: crear keystore y configurar signingConfigs.release
            // Ver: https://docs.flutter.dev/deployment/android#signing-the-app
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Supabase no requiere dependencias adicionales en Android
    // Todo se maneja a través de supabase_flutter
}
