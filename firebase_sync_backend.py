"""
Script para sincronizar archivos JSON con Firebase Storage
Ejecutar desde el directorio raíz del proyecto
"""

import json
import os
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, storage, firestore

# Archivos JSON que se sincronizarán
JSON_FILES = [
    'recipes.json',
    'foods.json',
    'users.json',
    'profiles.json',
    'consumption_history.json',
    'meal_plans.json',
    'nutrition_stats.json',
    'user_goals.json',
    'ingredient_food_mapping.json',
    'recipes_public.json',
    'recipes_private.json',
]

def initialize_firebase():
    """Inicializa Firebase Admin SDK"""
    # Ruta al archivo de credenciales de servicio
    # Descárgalo desde Firebase Console > Configuración del proyecto > Cuentas de servicio
    cred_path = os.getenv('FIREBASE_CREDENTIALS', 'firebase-credentials.json')
    
    if not os.path.exists(cred_path):
        print(f"❌ Error: No se encontró el archivo de credenciales: {cred_path}")
        print("📝 Descarga el archivo desde Firebase Console:")
        print("   1. Ve a Firebase Console > Configuración del proyecto")
        print("   2. Pestaña 'Cuentas de servicio'")
        print("   3. Click en 'Generar nueva clave privada'")
        print("   4. Guarda el archivo como 'firebase-credentials.json' en el directorio raíz")
        return False
    
    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': os.getenv('FIREBASE_STORAGE_BUCKET', 'nutritrack.appspot.com')
        })
        print("✅ Firebase inicializado correctamente")
        return True
    except Exception as e:
        print(f"❌ Error al inicializar Firebase: {e}")
        return False

def load_json_file(file_path):
    """Carga un archivo JSON"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"⚠️  Archivo no encontrado: {file_path}")
        return None
    except json.JSONDecodeError as e:
        print(f"❌ Error al parsear JSON {file_path}: {e}")
        return None

def upload_json_to_firebase(file_name, data):
    """Sube un archivo JSON a Firebase Storage"""
    try:
        bucket = storage.bucket()
        blob = bucket.blob(f'data/{file_name}')
        
        # Convertir a JSON string
        json_string = json.dumps(data, ensure_ascii=False, indent=2)
        
        # Subir como texto
        blob.upload_from_string(
            json_string,
            content_type='application/json'
        )
        
        # Guardar metadata en Firestore
        db = firestore.client()
        db.collection('sync_metadata').document(file_name).set({
            'fileName': file_name,
            'lastUpdated': firestore.SERVER_TIMESTAMP,
            'size': len(json_string),
        })
        
        print(f"✅ Subido: {file_name} ({len(json_string)} bytes)")
        return True
    except Exception as e:
        print(f"❌ Error al subir {file_name}: {e}")
        return False

def download_json_from_firebase(file_name):
    """Descarga un archivo JSON desde Firebase Storage"""
    try:
        bucket = storage.bucket()
        blob = bucket.blob(f'data/{file_name}')
        
        if not blob.exists():
            print(f"⚠️  Archivo no existe en Firebase: {file_name}")
            return None
        
        # Descargar como texto
        json_string = blob.download_as_text()
        data = json.loads(json_string)
        
        print(f"✅ Descargado: {file_name}")
        return data
    except Exception as e:
        print(f"❌ Error al descargar {file_name}: {e}")
        return None

def upload_all():
    """Sube todos los archivos JSON locales a Firebase"""
    print("\n📤 Subiendo archivos a Firebase...\n")
    
    results = {}
    for file_name in JSON_FILES:
        file_path = Path(file_name)
        
        if not file_path.exists():
            print(f"⏭️  Saltando {file_name} (no existe)")
            results[file_name] = False
            continue
        
        data = load_json_file(file_path)
        if data is not None:
            success = upload_json_to_firebase(file_name, data)
            results[file_name] = success
        else:
            results[file_name] = False
    
    print("\n📊 Resumen:")
    successful = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"✅ Exitosos: {successful}/{total}")
    print(f"❌ Fallidos: {total - successful}/{total}")
    
    return results

def download_all():
    """Descarga todos los archivos JSON desde Firebase"""
    print("\n📥 Descargando archivos desde Firebase...\n")
    
    results = {}
    for file_name in JSON_FILES:
        data = download_json_from_firebase(file_name)
        if data is not None:
            # Guardar localmente
            with open(file_name, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            results[file_name] = True
        else:
            results[file_name] = False
    
    print("\n📊 Resumen:")
    successful = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"✅ Descargados: {successful}/{total}")
    print(f"❌ Fallidos: {total - successful}/{total}")
    
    return results

if __name__ == '__main__':
    import sys
    
    if not initialize_firebase():
        sys.exit(1)
    
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == 'upload':
            upload_all()
        elif command == 'download':
            download_all()
        else:
            print("Uso: python firebase_sync_backend.py [upload|download]")
    else:
        print("Uso: python firebase_sync_backend.py [upload|download]")
        print("\nEjemplos:")
        print("  python firebase_sync_backend.py upload    # Sube todos los JSON a Firebase")
        print("  python firebase_sync_backend.py download   # Descarga todos los JSON desde Firebase")




