# Flujos de actualización de datos (Backend + Firestore)

## Principio

- **Datos generales** (recetas, recetas públicas, alimentos): todos los usuarios los leen; se actualizan en Firestore cuando se guardan recetas o alimentos.
- **Datos por usuario** (consumos, favoritos, recetas privadas, seguidos, objetivos, ingredientes, lista de compra): cada usuario solo accede a los suyos. Las acciones del usuario van al **backend**; el backend actualiza Firestore. Al reabrir la app se descargan **solo los datos del usuario** desde el backend.

---

## Al iniciar la app

1. **Datos generales (cache):** Se descargan solo de Firestore: `recipes.json`, `recipes_public.json`, `foods.json`, `ingredient_food_mapping.json`. No se descargan `users.json`, `profiles.json`, `consumption_history.json`, etc. (no se accede a datos de otros usuarios).
2. **Usuario autenticado:** Se llama al backend `GET /profile` y `GET /tracking/goals` y se persisten localmente (SharedPreferences) ingredientes, favoritos, lista de compra y objetivos. Así, al volver a abrir la app el usuario tiene solo su información actualizada.

---

## Cuando el usuario hace una acción

Todas las mutaciones van al backend; el backend escribe en Firestore (o en archivos locales con fallback). La app, además, puede sincronizar con el doc de usuario en Firestore (`users/{userId}.json`) para redundancia.

| Acción | Llamada app → backend | Backend actualiza en Firestore |
|--------|------------------------|--------------------------------|
| Registrar consumo | `POST /tracking/consumption` | `consumption_history.json` |
| Guardar objetivos | `PUT /tracking/goals` | `user_goals.json` |
| Añadir quitar favorito | `POST/DELETE /profile/favorites/{id}` | `profiles.json` |
| Guardar receta privada | `POST /recipes/private` | `recipes_private.json` |
| Seguir / dejar de seguir | `POST/DELETE /profile/follow/{id}` | `followers.json` |
| Ingredientes | `PUT /profile/ingredients`, `POST/DELETE /profile/ingredients/...` | `profiles.json` |
| Lista de compra | `PUT /profile/shopping-list` | `profiles.json` |
| Chatear (solo conexiones mutuas) | `POST /chat/{other_user_id}/message` | `chats.json` |

Al volver a iniciar la app, los datos del usuario se refrescan con `GET /profile` y `GET /tracking/goals`, de modo que solo se descarga la información de ese usuario.
