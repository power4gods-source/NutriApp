"""
Servicio para interactuar con Supabase Storage desde el backend Python
Permite leer y escribir archivos JSON en Supabase Storage con fallback a archivos locales
"""
import json
import os
from typing import Optional, Dict, Any
from supabase import create_client, Client

# Configuración de Supabase
# Obtener desde variables de entorno o usar valores por defecto
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://gxdzybyszpebhlspwiyz.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "sb_publishable_JIAsHqR-ryvBtin_n6EpoA__VkJbZ5T")
STORAGE_BUCKET = "data"

# Cliente de Supabase (singleton)
_supabase_client: Optional[Client] = None

def get_supabase_client() -> Optional[Client]:
    """Obtiene o crea el cliente de Supabase"""
    global _supabase_client
    if _supabase_client is None:
        try:
            _supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        except Exception as e:
            print(f"⚠️ Error inicializando Supabase: {e}")
            return None
    return _supabase_client

def is_supabase_configured() -> bool:
    """Verifica si Supabase está configurado"""
    return SUPABASE_URL and SUPABASE_KEY and SUPABASE_URL != "YOUR_SUPABASE_URL_HERE"

def load_json_from_supabase(file_name: str) -> Optional[Dict[str, Any]]:
    """
    Carga un archivo JSON desde Supabase Storage
    Retorna None si no existe o hay error
    """
    if not is_supabase_configured():
        return None
    
    try:
        client = get_supabase_client()
        if client is None:
            return None
        
        # Determinar la ruta en Supabase Storage
        # Los archivos van en data/ excepto users/ que van directamente
        if file_name.startswith("users/"):
            path = file_name
        else:
            path = f"data/{file_name}"
        
        print(f"📥 Descargando {path} desde Supabase Storage...")
        
        # Descargar el archivo (retorna bytes)
        response_bytes = client.storage.from_(STORAGE_BUCKET).download(path)
        
        if response_bytes:
            # Decodificar bytes a string y luego a JSON
            content = response_bytes.decode('utf-8')
            data = json.loads(content)
            print(f"✅ Descargado {file_name} desde Supabase ({len(content)} bytes)")
            return data
        else:
            print(f"⚠️ Archivo {file_name} no encontrado en Supabase")
            return None
            
    except Exception as e:
        error_str = str(e)
        if "not found" in error_str.lower() or "404" in error_str:
            # Archivo no existe - es normal
            return None
        print(f"⚠️ Error descargando {file_name} desde Supabase: {e}")
        return None

def save_json_to_supabase(file_name: str, data: Dict[str, Any]) -> bool:
    """
    Guarda un archivo JSON en Supabase Storage
    Retorna True si fue exitoso, False si hubo error
    """
    if not is_supabase_configured():
        return False
    
    try:
        client = get_supabase_client()
        if client is None:
            return False
        
        # Determinar la ruta en Supabase Storage
        if file_name.startswith("users/"):
            path = file_name
        else:
            path = f"data/{file_name}"
        
        print(f"📤 Subiendo {path} a Supabase Storage...")
        
        # Convertir a JSON string y luego a bytes
        json_string = json.dumps(data, ensure_ascii=False, indent=2)
        json_bytes = json_string.encode('utf-8')
        
        # Subir el archivo (usar upsert para sobrescribir si existe)
        response = client.storage.from_(STORAGE_BUCKET).upload(
            path=path,
            file=json_bytes,
            file_options={"content_type": "application/json", "upsert": "true"}
        )
        
        print(f"✅ Subido {file_name} a Supabase ({len(json_bytes)} bytes)")
        return True
        
    except Exception as e:
        print(f"❌ Error subiendo {file_name} a Supabase: {e}")
        return False

def load_json_with_fallback(file_name: str, local_file_path: str) -> Dict[str, Any]:
    """
    Carga un archivo JSON desde Supabase Storage con fallback a archivo local
    Prioridad: Supabase > Archivo local
    """
    # 1. Intentar desde Supabase
    supabase_data = load_json_from_supabase(file_name)
    if supabase_data is not None:
        # Guardar también localmente como cache
        try:
            with open(local_file_path, "w", encoding="utf-8") as f:
                json.dump(supabase_data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"⚠️ Error guardando cache local de {file_name}: {e}")
        return supabase_data
    
    # 2. Fallback a archivo local
    try:
        with open(local_file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            print(f"📂 Cargado {file_name} desde archivo local")
            return data
    except FileNotFoundError:
        print(f"⚠️ Archivo {file_name} no encontrado ni en Supabase ni localmente")
        return {} if "users" not in file_name.lower() else {}
    except json.JSONDecodeError:
        print(f"⚠️ Error parseando JSON de {file_name}")
        return {} if "users" not in file_name.lower() else {}

def save_json_with_sync(file_name: str, data: Dict[str, Any], local_file_path: str) -> bool:
    """
    Guarda un archivo JSON en Supabase Storage Y en archivo local
    Prioridad: Supabase primero, luego local como backup
    """
    # 1. Intentar guardar en Supabase
    supabase_success = save_json_to_supabase(file_name, data)
    
    # 2. Siempre guardar localmente también (como backup)
    try:
        with open(local_file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"💾 Guardado {file_name} localmente")
    except Exception as e:
        print(f"❌ Error guardando {file_name} localmente: {e}")
        return False
    
    # Retornar éxito si al menos se guardó localmente
    return True
