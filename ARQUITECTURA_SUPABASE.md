# Arquitectura: ¿Supabase como Backend o Solo Storage?

## 📋 Resumen

**Supabase se usa SOLO como Storage (almacenamiento de archivos JSON), NO como backend completo.**

## 🏗️ Arquitectura Actual

### 1. **Backend FastAPI** (Backend Principal)
- ✅ **Ubicación**: `main.py` (FastAPI)
- ✅ **Función**: API REST, lógica de negocio, autenticación JWT
- ✅ **Endpoints**: `/auth/register`, `/auth/login`, `/tracking/consumption`, etc.
- ✅ **Autenticación**: JWT tokens generados por FastAPI
- ✅ **Lógica de negocio**: Validación, cálculos, procesamiento de datos

### 2. **Supabase Storage** (Solo Almacenamiento)
- ✅ **Función**: Almacenar archivos JSON en la nube
- ✅ **Archivos**: `users.json`, `recipes.json`, `profiles.json`, etc.
- ❌ **NO se usa**: Supabase Auth (autenticación)
- ❌ **NO se usa**: Supabase Database (base de datos SQL)
- ❌ **NO se usa**: Supabase como API backend

### 3. **Flutter App** (Frontend)
- ✅ Se conecta al **Backend FastAPI** para API
- ✅ Usa **Supabase Storage** como fallback cuando el backend no está disponible
- ✅ Guarda datos localmente en `shared_preferences` como cache

## 🔄 Flujo de Datos

### Escenario Normal (Backend Disponible)

```
Flutter App
    ↓
Backend FastAPI (main.py)
    ↓
Supabase Storage (archivos JSON)
```

**Ejemplo: Registrar Usuario**
1. App → `POST /auth/register` al Backend FastAPI
2. Backend FastAPI → Valida datos, crea JWT
3. Backend FastAPI → Guarda en `users.json` usando `save_users()`
4. `save_users()` → Guarda en Supabase Storage Y archivo local

### Escenario Offline (Backend NO Disponible)

```
Flutter App
    ↓
Supabase Storage (directamente)
    ↓
shared_preferences (cache local)
```

**Ejemplo: Registrar Usuario (Offline)**
1. App → Detecta que backend no está disponible
2. App → Guarda directamente en Supabase Storage
3. App → Guarda en `shared_preferences` localmente
4. Cuando backend esté disponible → Sincroniza

## 📊 Comparación

| Componente | Backend FastAPI | Supabase Storage |
|------------|----------------|------------------|
| **API REST** | ✅ Sí | ❌ No |
| **Autenticación** | ✅ JWT | ❌ No (no se usa Auth) |
| **Lógica de Negocio** | ✅ Sí | ❌ No |
| **Almacenamiento JSON** | ✅ Sí (vía Supabase) | ✅ Sí |
| **Validación de Datos** | ✅ Sí | ❌ No |
| **Cálculos** | ✅ Sí | ❌ No |

## 🔍 ¿Por qué Solo Storage?

### Ventajas de esta Arquitectura:

1. **Control Total**: Mantienes toda la lógica de negocio en FastAPI
2. **Compatibilidad**: No necesitas cambiar toda la lógica existente
3. **Flexibilidad**: Puedes cambiar de Supabase a otro storage fácilmente
4. **Offline First**: La app funciona offline usando Supabase Storage directamente

### Lo que NO se usa de Supabase:

- ❌ **Supabase Auth**: La autenticación sigue siendo JWT del backend FastAPI
- ❌ **Supabase Database**: No se usa PostgreSQL, solo Storage (archivos)
- ❌ **Supabase Realtime**: No se usa para sincronización en tiempo real
- ❌ **Supabase Functions**: No se usan funciones serverless

## 📁 Archivos en Supabase Storage

Solo se almacenan archivos JSON:

```
data/
  ├── users.json
  ├── profiles.json
  ├── recipes.json
  ├── recipes_private.json
  ├── recipes_public.json
  ├── foods.json
  ├── consumption_history.json
  ├── nutrition_stats.json
  ├── user_goals.json
  └── ...

users/
  └── {user_id}.json (archivos individuales)
```

## 🔐 Autenticación

### Actual (JWT del Backend FastAPI):
- El backend FastAPI genera tokens JWT
- La app usa estos tokens para autenticarse
- Supabase NO participa en la autenticación

### Si quisieras usar Supabase Auth (Futuro):
- Podrías usar `supabase.auth.signUp()` y `supabase.auth.signIn()`
- Pero requeriría cambiar toda la lógica de autenticación
- Actualmente NO está implementado

## ✅ Conclusión

**Supabase = Solo Storage (almacenamiento de archivos JSON)**

**Backend FastAPI = Backend completo (API, autenticación, lógica)**

Esta arquitectura híbrida te da:
- ✅ Backend completo con FastAPI
- ✅ Almacenamiento en la nube con Supabase Storage
- ✅ Funcionamiento offline
- ✅ Sincronización automática
