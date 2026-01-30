# Flujos de autenticación

## Resumen

| Flujo | Pantalla / Origen | Backend | Resultado |
|-------|-------------------|---------|-----------|
| **Login** (email/contraseña) | LoginScreen → Acceder | `POST /auth/login` | JWT guardado → MainNavigationScreen |
| **Registro** | LoginScreen → Regístrate | `POST /auth/register` | JWT guardado → MainNavigationScreen |
| **Olvidé contraseña** | LoginScreen → "Olvidaste la contraseña?" → ForgotPasswordScreen | `POST /auth/forgot-password` | Email enviado (NutriTrack) → pop |
| **Restablecer contraseña** | "Ya tengo el token" → ResetPasswordScreen | `POST /auth/reset-password` | JWT guardado → MainNavigationScreen |
| **Cambiar contraseña** | Ajustes → Contraseña → ChangePasswordScreen | `POST /profile/password` (Bearer) | Mensaje éxito → pop |
| **Continuar con Google** | LoginScreen / Regístrate | Stub por defecto; real: `POST /auth/google` | Ver CONFIGURAR_AUTH_EMAIL_OAUTH.md |
| **Continuar con Apple** | LoginScreen / Regístrate | Stub por defecto; real: `POST /auth/apple` | Ver CONFIGURAR_AUTH_EMAIL_OAUTH.md |

## Funcionalidades implementadas

- **Backend:** login, register, forgot-password, reset-password, auth/google, auth/apple, profile/password; email corporativo NutriTrack (SMTP).
- **Flutter:** pantallas Login, ForgotPassword, ResetPassword, ChangePassword; AuthService con todos los métodos; stub Google/Apple (implementación real opcional en `social_auth_google_apple_REAL.dart.example`).
- **Pronto…:** Ajustes (Perfil, Ayuda, Eliminar cuenta, Donar), Perfil (Más info, Términos, Invitar amigos), tab Compartir (ComingSoonScreen con "Muy pronto..." y bocadillo de sugerencias).
