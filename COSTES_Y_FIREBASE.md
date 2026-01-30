# Costes al inicio y migración a Firebase

Objetivo: publicar en Google Play y App Store, minimizar gastos al principio, y tener escalabilidad con Crashlytics, Auth y tiempo real.

---

## 1. Tu situación actual (Supabase + Render)

| Servicio   | Uso actual              | Coste típico con pocos usuarios |
|-----------|--------------------------|----------------------------------|
| **Render** | Backend FastAPI         | **Free**: el servicio se duerme a los ~15 min sin tráfico; el primer request puede tardar ~1 min (mala experiencia en producción). **Paid**: desde ~7 USD/mes (servicio siempre activo). |
| **Supabase** | Storage/sync (JSON, usuarios) | **Free**: 2 proyectos, cuotas generosas. Con pocos usuarios suele ser **0 EUR/mes**. |

**Problema para publicar en tiendas:** Con Render en free, la app puede dar timeouts o lentitud en el primer uso del día; las tiendas y los usuarios lo notan. Para una app “seria” en stores suele hacerse necesario **Render de pago** (unos **7–10 USD/mes** como referencia).

---

## 2. Firebase: qué cuesta con pocos usuarios

Firebase tiene un **plan Spark (gratuito)** que no pide tarjeta. Con **pocos usuarios** es muy probable quedarse en **0 EUR/mes** usando solo lo que Spark incluye.

### Incluido en Spark (sin coste extra)

- **Authentication** (email, Google, Apple, etc.): sin límite de uso en el plan gratuito.
- **Crashlytics**: sin coste.
- **Cloud Messaging (FCM)** para notificaciones: sin coste.
- **Performance Monitoring**: sin coste.
- **Realtime Database**: cuota gratuita (p. ej. 1 GB almacenamiento, 10 GB/mes descarga).
- **Firestore**: en Spark tiene cuotas limitadas (p. ej. 50 K lecturas/día, 20 K escrituras/día, 1 GB). Con pocos usuarios suele ser suficiente y **0 EUR**.

### Qué no está en Spark (necesita Blaze = pay-as-you-go)

- **Cloud Storage** (archivos/imágenes): en Spark no está; en Blaze hay franja gratuita y luego pagas por uso.
- **Cloud Functions**: en Spark no; en Blaze hay franja gratuita (2 M invocaciones/mes, etc.).

Si activas **Blaze** solo para Storage o Functions, sigues teniendo franjas gratuitas; solo pagas si te pasas. Google suele ofrecer **300 USD de crédito** para nuevos proyectos (consultar en la consola).

### Resumen coste con pocos usuarios

- **Solo Spark (Auth + Crashlytics + Realtime o Firestore dentro de límites):**  
  **0 EUR/mes** de forma realista al inicio.
- **Blaze solo para Storage/Functions, uso bajo:**  
  Suele ser **0 EUR/mes** dentro de las franjas gratuitas; si te pasas, pocos euros al mes.
- **Tu backend (FastAPI):**  
  Sigue pudiendo estar en Render (free o paid). Firebase no sustituye obligatoriamente a Render; puedes usar Firebase para Auth + Crashlytics + tiempo real y seguir con Render para la API.

---

## 3. ¿Migrar a Firebase? Recomendación

**Sí tiene sentido migrar a Firebase** si quieres:

- Publicar en Google Play y App Store con buen soporte (crashs, rendimiento).
- **Auth** unificado (Google, Apple, email) y escalable.
- **Crashlytics** y **Performance** desde el primer día.
- **Tiempo real** (Firestore o Realtime Database) para datos que cambien al instante.
- Minimizar costes al inicio: con pocos usuarios, **Firebase puede ser 0 EUR/mes** (Spark) o muy bajo (Blaze dentro de lo gratis).

**No es obligatorio migrar todo.** Opciones razonables:

| Opción | Idea | Coste típico al inicio |
|--------|------|-------------------------|
| **A) Solo Firebase (Auth + Crashlytics + Firestore/Realtime)** | Backend FastAPI en Render (free o paid). App usa Firebase para auth, crashes, y opcionalmente BD en tiempo real. | **0 EUR** (Firebase Spark) + **0–7 USD** (Render free o paid). |
| **B) Firebase + Render como ahora** | Migrar auth y datos “en vivo” a Firebase; mantener lógica de recetas/negocio en Render si quieres. | Igual que A. |
| **C) Quedarte solo con Supabase + Render** | Sin Firebase. Para Crashlytics podrías usar algo tipo Sentry (tiene free tier). Auth y tiempo real los sigues haciendo con Supabase + backend. | **0–7 USD/mes** (Render free o paid). |

Recomendación práctica para **publicar en stores y escalar sin gastar casi nada al principio:**

- **Usar Firebase** para: **Auth** (Google, Apple, email), **Crashlytics**, **Performance** y, si quieres, **Firestore/Realtime** para lo que deba ser tiempo real.
- **Mantener Render** para el backend FastAPI (recetas, reglas de negocio, etc.) o ir moviendo esa lógica a **Cloud Functions** más adelante si te interesa.
- Con **pocos usuarios**, esperable: **0 EUR/mes** en Firebase (Spark) y **0–7 USD/mes** en Render según elijas free o paid.

---

## 4. Gastos que asumirías al principio (resumen)

- **Firebase (Spark):** **0 EUR/mes** (Auth, Crashlytics, tiempo real/Firestore dentro de límites).
- **Firebase (Blaze, uso bajo):** **0 EUR/mes** en la práctica si no te pasas de las franjas gratis; si te pasas, pocos euros/mes.
- **Render free:** **0 EUR** pero servicio que se duerme (no ideal para stores).
- **Render paid (recomendado para producción):** del orden de **7–10 USD/mes**.
- **Supabase free:** **0 EUR** (si sigues usándolo para algo).

En total, con **pocos usuarios** y enfoque “minimizar gastos”:

- **Escenario muy bajo coste:** Firebase Spark (0 €) + Render free (0 €) → **0 EUR/mes**, asumiendo cold starts en Render.
- **Escenario “listo para stores”:** Firebase Spark (0 €) + Render paid (~7–10 USD) → **unos 7–10 USD/mes** (aprox. 6–9 EUR).

Si más adelante quieres, se puede detallar un plan de migración paso a paso (Auth, luego Crashlytics, luego datos en tiempo real) sin tocar todo el proyecto a la vez.
