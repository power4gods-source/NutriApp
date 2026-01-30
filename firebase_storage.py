"""
Servicio para interactuar con Firebase Firestore desde el backend Python.
Permite leer y escribir "archivos" JSON como documentos en Firestore,
con la misma API lógica que supabase_storage (load/save por nombre de archivo).
"""
import json
import os
from typing import Optional, Dict, Any

# Firebase Admin (opcional)
_firebase_app = None
_firestore_client = None

def _get_firestore_client():
    """Obtiene el cliente de Firestore (singleton). Inicializa Firebase si hace falta."""
    global _firebase_app, _firestore_client
    if _firestore_client is not None:
        return _firestore_client
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        print("⚠️ firebase-admin no instalado. Ejecuta: pip install firebase-admin")
        return None
    # Credenciales: 1) JSON en env, 2) archivo en GOOGLE_APPLICATION_CREDENTIALS
    cred = None
    json_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if json_str:
        try:
            cred = credentials.Certificate(json.loads(json_str))
        except Exception as e:
            print(f"⚠️ Error parseando FIREBASE_SERVICE_ACCOUNT_JSON: {e}")
            return None
    if cred is None:
        path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if path and os.path.isfile(path):
            cred = credentials.Certificate(path)
    if cred is None:
        print("⚠️ Firebase no configurado: define FIREBASE_SERVICE_ACCOUNT_JSON o GOOGLE_APPLICATION_CREDENTIALS")
        return None
    try:
        _firebase_app = firebase_admin.initialize_app(cred)
        _firestore_client = firestore.client(_firebase_app)
        print("✅ Firebase Firestore inicializado")
        return _firestore_client
    except Exception as e:
        print(f"⚠️ Error inicializando Firebase: {e}")
        return None

# Colección donde guardamos cada "archivo" como documento (doc id = nombre lógico)
FIRESTORE_COLLECTION = os.getenv("FIRESTORE_STORAGE_COLLECTION", "storage")

def is_firebase_configured() -> bool:
    """Comprueba si Firebase está configurado."""
    return bool(os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or os.getenv("GOOGLE_APPLICATION_CREDENTIALS"))

def _doc_id_for(file_name: str) -> str:
    """Nombre de documento en Firestore: mismo nombre lógico (ej. users.json, recipes.json)."""
    # Firestore doc IDs no pueden contener /; reemplazar por _
    return file_name.replace("/", "_")

def load_json_from_firebase(file_name: str) -> Optional[Dict[str, Any]]:
    """
    Carga un JSON desde Firestore (documento en colección storage).
    Retorna None si no existe o hay error.
    """
    if not is_firebase_configured():
        return None
    db = _get_firestore_client()
    if db is None:
        return None
    try:
        doc_ref = db.collection(FIRESTORE_COLLECTION).document(_doc_id_for(file_name))
        doc = doc_ref.get()
        if not doc.exists:
            return None
        data = doc.to_dict()
        # Guardamos el contenido bajo la clave "data"
        if data and "data" in data:
            print(f"✅ Descargado {file_name} desde Firestore")
            return data["data"]
        # Compatibilidad: si el documento es el dict directo (sin clave "data")
        if data and isinstance(data, dict) and "data" not in data:
            print(f"✅ Descargado {file_name} desde Firestore (formato legacy)")
            return data
        return None
    except Exception as e:
        print(f"⚠️ Error descargando {file_name} desde Firestore: {e}")
        return None

def save_json_to_firebase(file_name: str, data: Dict[str, Any]) -> bool:
    """
    Guarda un JSON en Firestore. Retorna True si fue exitoso.
    """
    if not is_firebase_configured():
        return False
    db = _get_firestore_client()
    if db is None:
        return False
    try:
        doc_ref = db.collection(FIRESTORE_COLLECTION).document(_doc_id_for(file_name))
        # Firestore acepta dicts anidados; guardamos bajo "data" para consistencia
        doc_ref.set({"data": data})
        print(f"✅ Subido {file_name} a Firestore")
        return True
    except Exception as e:
        print(f"❌ Error subiendo {file_name} a Firestore: {e}")
        return False

def load_json_with_fallback(file_name: str, local_file_path: str) -> Dict[str, Any]:
    """
    Carga JSON: primero Firestore, si falla o no está configurado usa archivo local.
    """
    fb_data = load_json_from_firebase(file_name)
    if fb_data is not None:
        try:
            with open(local_file_path, "w", encoding="utf-8") as f:
                json.dump(fb_data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"⚠️ Error guardando cache local de {file_name}: {e}")
        return fb_data
    try:
        with open(local_file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            print(f"📂 Cargado {file_name} desde archivo local")
            return data
    except FileNotFoundError:
        print(f"⚠️ Archivo {file_name} no encontrado ni en Firestore ni localmente")
        return {} if "users" not in file_name.lower() else {}
    except json.JSONDecodeError:
        print(f"⚠️ Error parseando JSON de {file_name}")
        return {} if "users" not in file_name.lower() else {}

def save_json_with_sync(file_name: str, data: Dict[str, Any], local_file_path: str) -> bool:
    """
    Guarda en Firestore y siempre en archivo local como respaldo.
    """
    save_json_to_firebase(file_name, data)
    try:
        with open(local_file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"💾 Guardado {file_name} localmente")
    except Exception as e:
        print(f"❌ Error guardando {file_name} localmente: {e}")
        return False
    return True
