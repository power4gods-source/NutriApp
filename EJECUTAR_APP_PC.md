# Ejecutar App desde PC (Conectado a Render)

## ✅ Configuración Lista

La app ya está configurada para conectarse a Render automáticamente:
- URL: `https://nutriapp-470k.onrender.com`
- No necesitas cambiar nada

## 🚀 Comandos para Ejecutar

### Opción 1: Si Flutter está en el PATH

Abre PowerShell o CMD y ejecuta:

```powershell
cd C:\Users\mball\Downloads\NutriApp\nutri_track
flutter run -d chrome
```

O para Windows Desktop:
```powershell
cd C:\Users\mball\Downloads\NutriApp\nutri_track
flutter run -d windows
```

### Opción 2: Si Flutter NO está en el PATH

**Encuentra la ruta de Flutter:**
- Normalmente está en: `C:\src\flutter\bin\flutter.bat`
- O donde lo hayas instalado

**Ejecuta con la ruta completa:**
```powershell
cd C:\Users\mball\Downloads\NutriApp\nutri_track
C:\src\flutter\bin\flutter.bat run -d chrome
```

### Opción 3: Usar Android Studio / VS Code

1. **Abre Android Studio o VS Code**
2. **Abre la carpeta:** `C:\Users\mball\Downloads\NutriApp\nutri_track`
3. **Selecciona el dispositivo:**
   - Chrome (para web)
   - Windows (para desktop)
   - O un emulador Android si lo tienes
4. **Presiona F5 o clic en "Run"**

## 📱 Dispositivos Disponibles

Para ver qué dispositivos tienes disponibles:

```powershell
cd C:\Users\mball\Downloads\NutriApp\nutri_track
flutter devices
```

Opciones comunes:
- `chrome` - Navegador Chrome (más rápido para testing)
- `windows` - Aplicación Windows Desktop
- `edge` - Navegador Edge
- `emulator-xxxxx` - Emulador Android (si lo tienes)

## ✅ Verificar que Funciona

### 1. Verificar Backend Render

Abre en tu navegador:
```
https://nutriapp-470k.onrender.com/health
```

Debería responder: `{"status": "ok"}`

### 2. Ejecutar la App

Una vez que la app se abra:

1. **Intenta registrarte** con un nuevo usuario
2. **Haz login**
3. **Ve a "Amigos"** → Deberías ver otros usuarios
4. **Sigue a algunos usuarios** → Los contadores deberían actualizarse
5. **Registra consumo** → Debería guardarse

### 3. Ver Logs en Consola

En la consola donde ejecutaste `flutter run`, deberías ver:
```
🔍 Intentando con URL: https://nutriapp-470k.onrender.com
✅ Backend detectado en: https://nutriapp-470k.onrender.com
```

## 🔍 Verificar Datos en Supabase

1. Ve a [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Storage** → **data** bucket
4. Deberías ver:
   - `users.json`
   - `profiles.json`
   - `followers.json`
   - `recipes_public.json`
   - etc.

## 🐛 Troubleshooting

### Error: "flutter: command not found"

**Solución:**
1. Encuentra dónde está Flutter instalado
2. Usa la ruta completa: `C:\ruta\a\flutter\bin\flutter.bat run -d chrome`
3. O añade Flutter al PATH del sistema

### Error: "No devices found"

**Solución:**
```powershell
flutter doctor  # Verificar instalación
flutter devices  # Ver dispositivos
```

Si no hay dispositivos:
- Para web: `flutter run -d chrome`
- Para Windows: Asegúrate de tener Windows Desktop support habilitado

### La app no se conecta a Render

**Verifica:**
1. Render está funcionando: `https://nutriapp-470k.onrender.com/health`
2. No hay firewall bloqueando
3. La URL en `app_config.dart` es correcta

### Render está "spinning down"

**Solución:**
- Render Free tier se "duerme" después de 15 min de inactividad
- La primera petición puede tardar 30-60 segundos
- Espera y recarga

## 📋 Comandos Rápidos

```powershell
# 1. Ir a la carpeta del proyecto
cd C:\Users\mball\Downloads\NutriApp\nutri_track

# 2. Ver dispositivos disponibles
flutter devices

# 3. Ejecutar en Chrome (recomendado para testing)
flutter run -d chrome

# 4. O ejecutar en Windows Desktop
flutter run -d windows

# 5. Ver logs en tiempo real
# (Los logs aparecen automáticamente en la consola)
```

## ✅ Checklist

- [ ] Backend Render responde en `/health`
- [ ] Flutter está instalado y funciona
- [ ] App se ejecuta sin errores
- [ ] App se conecta a Render (ver logs)
- [ ] Puedo registrarme
- [ ] Puedo hacer login
- [ ] Veo perfiles en "Amigos"
- [ ] Puedo seguir usuarios
- [ ] Los datos se guardan en Supabase

## 💡 Tips

1. **Usa Chrome para testing rápido** - Es más rápido que Windows Desktop
2. **Mantén la consola abierta** - Verás todos los logs de conexión
3. **Hot Reload** - Presiona `r` en la consola para recargar sin reiniciar
4. **Hot Restart** - Presiona `R` para reiniciar completamente
5. **Quit** - Presiona `q` para salir
