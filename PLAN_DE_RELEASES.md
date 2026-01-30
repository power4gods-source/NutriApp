# Plan de releases – NutriTrack

Este documento define el plan de acción para publicar NutriTrack en **Google Play Store** y **Apple App Store**, con compatibilidad Android e iOS, y el roadmap de funcionalidades por releases.

---

## 1. Publicación en tiendas (v1.0)

### 1.1 Requisitos para Play Store y App Store

- **Android**
  - `applicationId` único (ej. `com.tudominio.nutritrack`).
  - Firma release con keystore propio (no debug).
  - `minSdk` ≥ 21 (Android 5.0) recomendado; actualmente usa `flutter.minSdkVersion`.
  - `targetSdk` actualizado (API 34 recomendado para 2024/2025).
  - Nombre de app visible: "NutriTrack" en `android:label`.
  - Política de privacidad URL si se recogen datos.

- **iOS**
  - Bundle ID único (ej. `com.tudominio.nutritrack`).
  - Cuenta Apple Developer y certificados de distribución.
  - `Info.plist`: `CFBundleDisplayName` = "NutriTrack", descripciones de privacidad si usas cámara/fotos.
  - iOS 12+ como mínimo (según Flutter).

### 1.2 Funcionalidades marcadas como "Pronto..."

En la v1.0 se publica la app con las funciones ya implementadas. Las no disponibles se muestran en la UI con el texto **"Pronto..."** y no son accionables (o muestran un mensaje informativo). Ejemplos:

- Inicio de sesión con Google / Apple ID  
- Recuperación de contraseña por email  
- Donaciones (usuarios / app)  
- Límite de generación de recetas (5 gratis, luego 0,01 €/consulta)  
- Centro de ayuda  
- Eliminar cuenta  
- Invitar amigos  
- Compartir (tab "Compartir")  
- Más info / Términos y condiciones (si aún no hay URL)

---

## 2. Roadmap por releases

### Release 1.0 – Publicación inicial (actual)

**Objetivo:** App publicable en Play Store y App Store, estable y con funciones actuales.

- [x] Ajustes Android/iOS para tiendas (label, IDs, permisos mínimos).
- [x] Marcar como "Pronto..." todas las funcionalidades no implementadas.
- [x] Pantalla "Compartir" con mensaje "Pronto..." en lugar de placeholder vacío.
- [ ] Política de privacidad y, si aplica, términos (URL).
- [ ] Firma release Android (keystore) y configuración en `build.gradle`.
- [ ] Certificados y provisioning iOS para App Store.

**Funcionalidades disponibles en 1.0**

- Login/registro por email y contraseña.
- Recetas, favoritos, seguimiento nutricional, ingredientes, lista de la compra.
- Generador de recetas con IA (sin límite de uso en esta versión; el límite se añade en 1.1).
- Sincronización con Supabase.
- Perfil, notificaciones básicas, amigos (lista/seguir).

---

### Release 1.1 – Autenticación y correo

**Objetivo:** Más opciones de login y recuperación de cuenta.

1. **Iniciar sesión con Google y Apple ID**
   - Android: Google Sign-In.
   - iOS: Sign in with Apple (obligatorio si ofreces otros proveedores sociales).
   - Backend: validar token OAuth y crear/vinculación de usuario.

2. **Registro y usuario por email**
   - Mantener registro por email como ya está.
   - Un solo "usuario" por cuenta (email o cuenta social vinculada).

3. **Email de la app y recuperación de contraseña**
   - Dominio/email corporativo (ej. `noreply@nutritrack.app`).
   - Endpoint "Olvidé contraseña": envía link de reset al email del usuario.
   - Enlace con token de un solo uso y caducidad (ej. 24 h).

4. **Emails transaccionales**
   - Email de bienvenida tras registro.
   - (Opcional) Email al cambiar contraseña o al vincular/desvincular cuenta social.

**Tareas técnicas**

- Backend: endpoints `POST /auth/forgot-password`, `POST /auth/reset-password`, integración con servicio de email (SendGrid, Resend, SES, etc.).
- Flutter: paquetes `google_sign_in`, `sign_in_with_apple`; pantallas "Olvidé contraseña" y "Restablecer contraseña".
- Quitar "Pronto..." de: "Iniciar sesión con Google/Apple", "Recuperar contraseña".

---

### Release 1.2 – Límite de generación de recetas y micropagos

**Objetivo:** 5 generaciones gratuitas; a partir de la 6.ª (hasta 25 total) y más allá, 0,01 € por consulta.

1. **Límite de generación**
   - Definir "generación" = una llamada al generador de recetas con IA.
   - Gratis: 5 generaciones (por usuario, por periodo; ej. mensual o total histórico según diseño).
   - Si se quiere generar más de 25 en total (o más de 5 en el periodo): cobro de 0,01 € por consulta adicional.

2. **Micropagos**
   - Backend: contador de generaciones por usuario, reglas de límite (5 gratis, 25 total o similar).
   - Integración con pasarela de pago (Stripe, RevenueCat, o in-app de Google/Apple).
   - En Flutter: pantalla "Generar receta" mostrando usos restantes y opción "Comprar más generaciones" (0,01 €/consulta o paquetes).

**Tareas técnicas**

- Backend: modelo/registro `recipe_generations` (user_id, count, period), endpoint para comprobar y consumir generaciones, webhook o API de pagos.
- Flutter: UI de "X/5 generaciones usadas", botón de pago y flujo post-pago.
- Quitar "Pronto..." del límite de generación cuando esté implementado.

---

### Release 1.3 – Donaciones

**Objetivo:** Donaciones a usuarios (creadores) o a la app.

1. **Donaciones a la app**
   - Botón "Apoyar la app" / "Donar" en Ajustes o Perfil.
   - Cantidades fijas o libre (según pasarela).
   - No requiere cuenta de creador.

2. **Donaciones a usuarios**
   - En perfil público de un usuario: "Enviar propina" / "Donar".
   - Monto elegido por el donante; el receptor debe poder recibir pagos (cuenta Stripe/Connect o similar).

**Tareas técnicas**

- Backend: Stripe (o similar), Stripe Connect para pagos a creadores; webhooks de pago.
- Flutter: pantallas "Donar a la app" y "Donar a [usuario]"; mostrar "Pronto..." hasta que esté listo y luego sustituir por flujo real.
- Cumplir políticas de Google/Apple sobre donaciones y comisiones.

---

### Release 1.4 – Emails de marketing y notificaciones

**Objetivo:** Mails con publicidad y comunicaciones promocionales (con consentimiento).

1. **Registro de email para comunicaciones**
   - En registro o en Ajustes: casilla "Recibir ofertas y novedades" (opt-in).
   - Guardar preferencia en backend (campo `marketing_emails` o similar).

2. **Emails con publicidad**
   - Envío de newsletters/ofertas solo a usuarios que hayan aceptado.
   - Servicio de email marketing (Mailchimp, SendGrid, etc.) o propio con plantillas.

3. **Cumplimiento**
   - RGPD / LOPD: base legal y posibilidad de baja en cada email.
   - En Ajustes: "Gestionar suscripción a emails" (activar/desactivar).

**Tareas técnicas**

- Backend: campo y endpoint para preferencia de marketing; cola o integración con proveedor de emails.
- Flutter: checkbox en registro y pantalla en Ajustes; enlace "Darse de baja" en pies de email.
- Quitar "Pronto..." de opciones de email cuando estén implementadas.

---

### Release 1.5 – Otras funcionalidades recomendadas

**Objetivo:** Mejorar retención, seguridad y calidad de producto.

1. **Eliminar cuenta (GDPR/LOPD)**
   - Endpoint `DELETE /user` o `POST /user/deactivate` que elimine o anonimice datos.
   - En Ajustes: "Eliminar cuenta" con confirmación y, si aplica, verificación de contraseña.
   - Quitar "Pronto..." de "Eliminar cuenta".

2. **Centro de ayuda**
   - Página web o sección in-app con FAQ, contacto y enlaces a política de privacidad y términos.
   - En Ajustes: "Ayuda" abre esa URL o pantalla.
   - Quitar "Pronto..." de "Ayuda".

3. **Invitar amigos**
   - Compartir link de invitación (deep link o referral) y, opcional, beneficio para quien invita/invitado.
   - Backend: códigos de referido y contador.
   - Quitar "Pronto..." de "Invitar amigos".

4. **Compartir (tab)**
   - Compartir recetas o fotos a redes sociales o contacto; o subir contenido a la comunidad NutriTrack.
   - Definir si es solo compartir externo o también contenido in-app.
   - Sustituir pantalla "Pronto..." por flujo real.

5. **Términos y condiciones / Más info**
   - URLs definitivas en backend o web; enlaces en Perfil y/o Ajustes.
   - Quitar "Pronto..." cuando las páginas estén publicadas.

6. **Mejoras técnicas**
   - Rate limiting y protección de APIs.
   - Analíticas (Firebase, Mixpanel, etc.) sin identificar de más; aviso en política de privacidad.
   - Tests automatizados para login, generación de recetas y flujos críticos.

---

## 3. Resumen de releases

| Release | Contenido principal |
|--------|----------------------|
| **1.0** | Publicación en tiendas, "Pronto..." en funciones no listas, compatibilidad Android/iOS. |
| **1.1** | Login Google/Apple, recuperación de contraseña, email bienvenida. |
| **1.2** | Límite 5 generaciones gratis, 0,01 € por consulta extra; micropagos. |
| **1.3** | Donaciones a la app y a usuarios. |
| **1.4** | Emails de marketing (opt-in) y publicidad. |
| **1.5** | Eliminar cuenta, ayuda, invitar amigos, compartir, términos/legal, mejoras técnicas. |

---

## 4. Compatibilidad Android e iOS

- **Plataforma:** Flutter; un solo código para Android e iOS.
- **Android:** `minSdk` y `targetSdk` definidos en `android/app/build.gradle.kts`; probar en al menos API 21 y 34.
- **iOS:** Deployment target según Flutter (ej. iOS 12+); probar en último y penúltimo major.
- **Permisos:** Solo los necesarios (ej. INTERNET, red); cámara/almacenamiento solo cuando se implemente "Compartir" con foto; declarar en AndroidManifest e Info.plist y describir en política de privacidad.

Con este plan, la app puede subirse a Play Store y App Store en la versión 1.0, y las funcionalidades solicitadas (pagos, límite de recetas, login social, email y recuperación, donaciones, emails de marketing) quedan repartidas en releases posteriores, con "Pronto..." hasta su llegada.
