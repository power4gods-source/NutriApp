#!/usr/bin/env python3
"""
Script para subir los JSON locales a Firestore (colección "storage").
Uso:
  1. Define FIREBASE_SERVICE_ACCOUNT_JSON (contenido del JSON) o GOOGLE_APPLICATION_CREDENTIALS (ruta al archivo).
  2. En la raíz del proyecto: python upload_jsons_to_firestore.py

- Si un archivo existe, se sube su contenido.
- Si no existe pero está en DEFAULT_IF_MISSING, se sube una estructura vacía (el backend la rellenará:
  followers.json cuando los usuarios sigan a otros; chats.json cuando conexiones mutuas envíen mensajes).
"""
import json
import os
import sys

# Lista de archivos JSON que la app/backend esperan en Firestore
JSON_FILES = [
    "recipes.json",
    "recipes_private.json",
    "recipes_public.json",
    "users.json",
    "profiles.json",
    "foods.json",
    "ingredient_food_mapping.json",
    "consumption_history.json",
    "meal_plans.json",
    "nutrition_stats.json",
    "user_goals.json",
    "followers.json",
    "chats.json",
]

# Archivos que, si no existen localmente, se suben vacíos para que el backend los use
# (followers: se rellena al seguir/dejar de seguir; chats: se rellena cuando dos conexiones mutuas chatean)
DEFAULT_IF_MISSING = {
    "followers.json": {},
    "chats.json": {},
}

def main():
    if not os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") and not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        print("❌ Define FIREBASE_SERVICE_ACCOUNT_JSON o GOOGLE_APPLICATION_CREDENTIALS")
        print("   Ejemplo (PowerShell): $env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content -Raw 'ruta\\cuenta.json'")
        sys.exit(1)

    from firebase_storage import save_json_to_firebase, is_firebase_configured

    if not is_firebase_configured():
        print("❌ Firebase no configurado. Revisa las variables de entorno.")
        sys.exit(1)

    uploaded = 0
    skipped = 0
    for file_name in JSON_FILES:
        if os.path.isfile(file_name):
            try:
                with open(file_name, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception as e:
                print(f"❌ Error leyendo {file_name}: {e}")
                skipped += 1
                continue
        elif file_name in DEFAULT_IF_MISSING:
            data = DEFAULT_IF_MISSING[file_name]
            print(f"📝 {file_name} no existe localmente → subiendo estructura vacía (se rellenará al usar seguir/chat)")
        else:
            print(f"⏭️  {file_name} no existe, omitiendo")
            skipped += 1
            continue

        if save_json_to_firebase(file_name, data):
            print(f"✅ Subido: {file_name}")
            uploaded += 1
        else:
            print(f"❌ Fallo al subir: {file_name}")
            skipped += 1

    print(f"\n📊 Resumen: {uploaded} subidos, {skipped} omitidos/fallos")

if __name__ == "__main__":
    main()
