# Probar la App desde PC (Como Móvil)

## 🎯 Objetivo

Ejecutar la app Flutter desde tu PC y conectarla al backend de Render como si fuera un móvil.

## ✅ Configuración Actual

La app ya está configurada para usar Render por defecto:
- URL: `https://nutriapp-470k.onrender.com`
- Se conecta automáticamente sin necesidad de cambiar nada

## 🚀 Pasos para Ejecutar

### 1. Verificar que el Backend de Render Está Funcionando

Abre en tu navegador:
```
https://nutriapp-470k.onrender.com/health
```

Debería responder:
```json
{
  "status": "ok",
  "message": "Backend is running and accessible from network"
}
```

### 2. Ejecutar la App Flutter

Abre una terminal en la carpeta del proyecto y ejecuta:

**Windows (PowerShell o CMD):**
```powershell
cd nutri_track
flutter run -d windows
```

**O si quieres especificar un dispositivo específico:**
```powershell
cd nutri_track
flutter devices  # Ver dispositivos disponibles
flutter run -d windows  # O chrome, edge, etc.
```

### 3. Alternativas de Ejecución

**Opción A: Chrome (Web) - Más Rápido para Testing**
```powershell
cd nutri_track
flutter run -d chrome
```

**Opción B: Windows Desktop**
```powershell
cd nutri_track
flutter run -d windows
```

**Opción C: Android Emulator (Si lo tienes instalado)**
```powershell
cd nutri_track
flutter run -d emulator-5554  # O el ID de tu emulador
```

## 🔍 Verificar la Conexión

Una vez que la app esté ejecutándose:

1. **Abre la consola de Flutter** (donde ejecutaste `flutter run`)
2. **Busca mensajes como:**
   ```
   🔍 Intentando con URL guardada: https://nutriapp-470k.onrender.com
   ✅ Backend detectado en: https://nutriapp-470k.onrender.com
   ```

3. **Prueba las funcionalidades:**
   - Registro de usuario → Debería guardarse en Render y Supabase
   - Login → Debería funcionar
   - Ver perfiles en "Amigos" → Debería cargar desde Render
   - Seguir usuarios → Debería actualizar en Render y Supabase
   - Registrar consumo → Debería guardarse

## 🐛 Si Hay Problemas

### Error: "Failed to connect to backend"

**Solución:**
1. Verifica que Render esté funcionando: `https://nutriapp-470k.onrender.com/health`
2. Si Render está "spinning down" (inactivo), espera 30 segundos y recarga
3. Verifica que no haya firewall bloqueando

### Error: "No devices found"

**Solución:**
```powershell
flutter doctor  # Verificar instalación
flutter devices  # Ver dispositivos disponibles
```

### La app se conecta a localhost en lugar de Render

**Solución:**
La app debería usar Render por defecto. Si no:
1. Verifica `nutri_track/lib/config/app_config.dart`
2. Asegúrate de que `defaultBackendUrl` retorne `https://nutriapp-470k.onrender.com`

## 📱 Comportamiento Esperado

Cuando ejecutes la app desde PC:

✅ **Se conecta a Render automáticamente**
✅ **Todos los datos se guardan en Render y Supabase**
✅ **Funciona igual que en móvil**
✅ **Puedes probar todas las funcionalidades**

## 🔄 Flujo de Datos

```
App Flutter (PC)
    ↓
Backend Render (https://nutriapp-470k.onrender.com)
    ↓
Supabase Storage (archivos JSON)
    ↓
Archivos locales (fallback)
```

## 💡 Tips

1. **Usa Chrome para testing rápido** - `flutter run -d chrome`
2. **Mantén la consola abierta** - Verás logs de conexión
3. **Prueba con diferentes usuarios** - Registra varios usuarios y prueba seguimiento
4. **Verifica Supabase Dashboard** - Los datos deberían aparecer en Storage

## ✅ Checklist de Prueba

- [ ] Backend Render responde en `/health`
- [ ] App se ejecuta sin errores
- [ ] Puedo registrarme
- [ ] Puedo hacer login
- [ ] Veo perfiles en "Amigos"
- [ ] Puedo seguir usuarios
- [ ] Los contadores se actualizan
- [ ] Los datos aparecen en Supabase Storage
