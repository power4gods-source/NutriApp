from fastapi import FastAPI, HTTPException, Depends, status, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import List, Optional
import json
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
import secrets
import bcrypt
from supabase_storage import load_json_with_fallback, save_json_with_sync, load_json_from_supabase, save_json_to_supabase

app = FastAPI()

# Health check endpoint
@app.get("/health")
def health_check():
    """Health check endpoint to verify backend is running"""
    import socket
    hostname = socket.gethostname()
    
    # Obtener todas las IPs de la máquina
    try:
        # Obtener IP local
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        try:
            local_ip = socket.gethostbyname(hostname)
        except:
            local_ip = "unknown"
    
    return {
        "status": "ok", 
        "message": "Backend is running and accessible from network",
        "hostname": hostname,
        "local_ip": local_ip,
        "port": 8000,
        "host": "0.0.0.0",
        "accessible_from_network": True,
        "timestamp": datetime.now().isoformat()
    }

# Add CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Recipe file paths
RECIPES_GENERAL_FILE = "recipes.json"  # Precompiled recipes
RECIPES_PRIVATE_FILE = "recipes_private.json"  # User's private recipes
RECIPES_PUBLIC_FILE = "recipes_public.json"  # User's public recipes
USERS_FILE = "users.json"  # User profiles
PROFILES_FILE = "profiles.json"  # Extended user profiles
FOODS_FILE = "foods.json"  # Food database
INGREDIENT_MAPPING_FILE = "ingredient_food_mapping.json"  # Ingredient to food mapping
CONSUMPTION_HISTORY_FILE = "consumption_history.json"  # Consumption history
MEAL_PLANS_FILE = "meal_plans.json"  # Meal plans
NUTRITION_STATS_FILE = "nutrition_stats.json"  # Nutrition statistics
USER_GOALS_FILE = "user_goals.json"  # User goals
FOLLOWERS_FILE = "followers.json"  # User following/followers relationships

# Authentication settings
# SECRET_KEY debe ser persistente para que los tokens JWT sigan siendo válidos después de reinicios
# Prioridad: 1) Variable de entorno, 2) Archivo local, 3) Generar nueva y guardarla
SECRET_KEY_FILE = "jwt_secret_key.txt"

def get_or_create_secret_key():
    """Get SECRET_KEY from environment variable, file, or create a new one"""
    import os
    
    # 1. Intentar desde variable de entorno (para Render/producción)
    env_key = os.getenv("JWT_SECRET_KEY")
    if env_key:
        print("🔑 Usando SECRET_KEY desde variable de entorno")
        return env_key
    
    # 2. Intentar leer desde archivo local
    try:
        if os.path.exists(SECRET_KEY_FILE):
            with open(SECRET_KEY_FILE, 'r') as f:
                key = f.read().strip()
                if key:
                    print("🔑 Usando SECRET_KEY desde archivo local")
                    return key
    except Exception as e:
        print(f"⚠️ Error leyendo SECRET_KEY desde archivo: {e}")
    
    # 3. Generar nueva clave y guardarla
    new_key = secrets.token_urlsafe(32)
    try:
        with open(SECRET_KEY_FILE, 'w') as f:
            f.write(new_key)
        print("🔑 Generada nueva SECRET_KEY y guardada en archivo")
    except Exception as e:
        print(f"⚠️ No se pudo guardar SECRET_KEY en archivo: {e}")
        print("⚠️ Usando SECRET_KEY temporal (los tokens se invalidarán al reiniciar)")
    
    return new_key

SECRET_KEY = get_or_create_secret_key()
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30 * 24 * 60  # 30 days

# Password hashing
# Initialize password context - use direct bcrypt to avoid passlib version detection issues
# We'll use bcrypt directly for hashing, and passlib only for verification when needed
pwd_context = None
try:
    # Try to initialize with bcrypt
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    # Test that it works
    test_hash = pwd_context.hash("test")
    print("✅ Password context initialized with bcrypt")
except Exception as e:
    print(f"⚠️ Warning: Could not initialize passlib bcrypt context: {e}")
    print("ℹ️ Will use direct bcrypt library instead")
    pwd_context = None

# Security
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash (supports bcrypt and SHA256 for migration)"""
    # Try bcrypt first
    try:
        if hashed_password.startswith('$2') or hashed_password.startswith('$2a') or hashed_password.startswith('$2b'):
            return pwd_context.verify(plain_password, hashed_password)
    except:
        pass
    
    # Fallback to SHA256 for legacy passwords
    import hashlib
    sha256_hash = hashlib.sha256(plain_password.encode()).hexdigest()
    return sha256_hash == hashed_password

def get_password_hash(password: str) -> str:
    """Hash a password using bcrypt directly (more reliable than passlib)"""
    # Bcrypt has a 72-byte limit, truncate if necessary
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
    
    # Use bcrypt directly to avoid passlib version detection issues
    try:
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password_bytes, salt)
        return hashed.decode('utf-8')
    except Exception as e:
        print(f"⚠️ Error hashing password with bcrypt: {e}")
        # Fallback to passlib if available
        if pwd_context:
            return pwd_context.hash(password)
        # Last resort: SHA256 (not secure, but better than nothing)
        import hashlib
        return hashlib.sha256(password.encode()).hexdigest()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def load_users():
    """Load users from Supabase Storage with fallback to local file"""
    # Para users.json, cargar desde Supabase Storage
    data = load_json_with_fallback(USERS_FILE, USERS_FILE)
    # Asegurar que es un dict
    if not isinstance(data, dict):
        print(f"⚠️ users.json no es un dict, retornando dict vacío")
        return {}
    print(f"📋 Cargados {len(data)} usuarios desde base de datos")
    return data

def save_users(users: dict):
    """Save users to Supabase Storage and local file"""
    save_json_with_sync(USERS_FILE, users, USERS_FILE)

def load_profiles():
    """Load user profiles from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(PROFILES_FILE, PROFILES_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_profiles(profiles: dict):
    """Save user profiles to Supabase Storage and local file"""
    save_json_with_sync(PROFILES_FILE, profiles, PROFILES_FILE)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current authenticated user from JWT token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        token = credentials.credentials
        print(f"🔍 Validando token JWT (primeros 20 chars): {token[:20] if len(token) > 20 else token}...")
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            print(f"❌ Token no contiene 'sub' (user_id)")
            raise credentials_exception
        print(f"✅ Token válido para usuario: {user_id}")
    except JWTError as e:
        print(f"❌ Error decodificando token JWT: {e}")
        raise credentials_exception
    
    users = load_users()
    print(f"📋 Verificando usuario en base de datos: {user_id}")
    if user_id not in users:
        print(f"❌ Usuario no encontrado en base de datos: {user_id}")
        print(f"📋 Usuarios disponibles: {list(users.keys())[:5]}...")
        raise credentials_exception
    print(f"✅ Usuario encontrado: {user_id}")
    
    user_info = users[user_id]
    email = user_info.get("email", "")
    # Obtener el rol del usuario (admin para power4gods@gmail.com, user para el resto)
    role = user_info.get("role", "user")  # Por defecto 'user'
    if email == "power4gods@gmail.com" and role != "admin":
        # Asegurar que power4gods@gmail.com siempre sea admin
        role = "admin"
        user_info["role"] = "admin"
        save_users(users)
    
    return {"user_id": user_id, "email": email, "role": role}

def is_admin(current_user: dict = Depends(get_current_user)) -> bool:
    """Check if current user is admin"""
    return current_user.get("role") == "admin"

def load_recipes_general():
    """Load precompiled recipes from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(RECIPES_GENERAL_FILE, RECIPES_GENERAL_FILE)
    # Si es un dict con clave 'recipes', extraer la lista
    if isinstance(data, dict) and 'recipes' in data:
        return data['recipes']
    # Si es una lista, retornarla directamente
    if isinstance(data, list):
        return data
    return []

def save_recipes_general(recipes_list):
    """Save general recipes to Supabase Storage and local file"""
    # Guardar como dict con clave 'recipes' para consistencia
    data = {'recipes': recipes_list} if isinstance(recipes_list, list) else recipes_list
    save_json_with_sync(RECIPES_GENERAL_FILE, data, RECIPES_GENERAL_FILE)

def load_recipes_private():
    """Load private user recipes from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(RECIPES_PRIVATE_FILE, RECIPES_PRIVATE_FILE)
    # Si es un dict con clave 'recipes', extraer la lista
    if isinstance(data, dict) and 'recipes' in data:
        return data['recipes']
    # Si es una lista, retornarla directamente
    if isinstance(data, list):
        return data
    return []

def load_recipes_public():
    """Load public user recipes from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(RECIPES_PUBLIC_FILE, RECIPES_PUBLIC_FILE)
    # Si es un dict con clave 'recipes', extraer la lista
    if isinstance(data, dict) and 'recipes' in data:
        recipes = data['recipes']
        print(f"📖 Loaded {len(recipes)} public recipes from Supabase/local")
        return recipes
    # Si es una lista, retornarla directamente
    if isinstance(data, list):
        print(f"📖 Loaded {len(data)} public recipes from Supabase/local")
        return data
    print(f"⚠️ No public recipes found, returning empty list")
    return []

def save_recipes_private(recipes_list):
    """Save private recipes to Supabase Storage and local file"""
    # Guardar como dict con clave 'recipes' para consistencia
    data = {'recipes': recipes_list} if isinstance(recipes_list, list) else recipes_list
    save_json_with_sync(RECIPES_PRIVATE_FILE, data, RECIPES_PRIVATE_FILE)

def save_recipes_public(recipes_list):
    """Save public recipes to Supabase Storage and local file"""
    # Guardar como dict con clave 'recipes' para consistencia
    data = {'recipes': recipes_list} if isinstance(recipes_list, list) else recipes_list
    save_json_with_sync(RECIPES_PUBLIC_FILE, data, RECIPES_PUBLIC_FILE)
    print(f"💾 Saved {len(recipes_list)} public recipes to Supabase and local file")

# Food database functions
def load_foods():
    """Load foods database from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(FOODS_FILE, FOODS_FILE)
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and 'foods' in data:
        return data['foods']
    return []

def load_ingredient_mapping():
    """Load ingredient to food mapping from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(INGREDIENT_MAPPING_FILE, INGREDIENT_MAPPING_FILE)
    if isinstance(data, dict):
        return data.get("mappings", [])
    if isinstance(data, list):
        return data
    return []

def save_ingredient_mapping(mappings):
    """Save ingredient to food mapping to Supabase Storage and local file"""
    data = {"mappings": mappings} if isinstance(mappings, list) else mappings
    save_json_with_sync(INGREDIENT_MAPPING_FILE, data, INGREDIENT_MAPPING_FILE)

def load_consumption_history():
    """Load consumption history from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(CONSUMPTION_HISTORY_FILE, CONSUMPTION_HISTORY_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_consumption_history(history):
    """Save consumption history to Supabase Storage and local file"""
    save_json_with_sync(CONSUMPTION_HISTORY_FILE, history, CONSUMPTION_HISTORY_FILE)

def load_meal_plans():
    """Load meal plans from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(MEAL_PLANS_FILE, MEAL_PLANS_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_meal_plans(plans):
    """Save meal plans to Supabase Storage and local file"""
    save_json_with_sync(MEAL_PLANS_FILE, plans, MEAL_PLANS_FILE)

def load_nutrition_stats():
    """Load nutrition statistics from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(NUTRITION_STATS_FILE, NUTRITION_STATS_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_nutrition_stats(stats):
    """Save nutrition statistics to Supabase Storage and local file"""
    save_json_with_sync(NUTRITION_STATS_FILE, stats, NUTRITION_STATS_FILE)

def load_user_goals():
    """Load user goals from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(USER_GOALS_FILE, USER_GOALS_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_user_goals(goals):
    """Save user goals to Supabase Storage and local file"""
    save_json_with_sync(USER_GOALS_FILE, goals, USER_GOALS_FILE)

def load_followers():
    """Load followers/following relationships from Supabase Storage with fallback to local file"""
    data = load_json_with_fallback(FOLLOWERS_FILE, FOLLOWERS_FILE)
    if not isinstance(data, dict):
        return {}
    return data

def save_followers(followers_data):
    """Save followers/following relationships to Supabase Storage and local file"""
    save_json_with_sync(FOLLOWERS_FILE, followers_data, FOLLOWERS_FILE)

@app.get("/")
def read_root():
    return {"message": "Hello from Nutritrack backend!"}

# Authentication models
class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, description="Password must be at least 6 characters")
    username: Optional[str] = Field(None, description="Optional username")

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    role: Optional[str] = "user"

class PasswordUpdate(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6, description="New password must be at least 6 characters")

# Profile models
class ProfileCreate(BaseModel):
    username: Optional[str] = None
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    dietary_preferences: Optional[List[str]] = Field(default=[], description="e.g., vegetarian, vegan, halal")
    favorite_cuisines: Optional[List[str]] = Field(default=[], description="e.g., italian, mexican, asian")

class ProfileUpdate(BaseModel):
    username: Optional[str] = None
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    dietary_preferences: Optional[List[str]] = None
    favorite_cuisines: Optional[List[str]] = None

class NotificationSettings(BaseModel):
    email_notifications: Optional[bool] = True
    push_notifications: Optional[bool] = True
    recipe_updates: Optional[bool] = True
    new_followers: Optional[bool] = True
    comments_on_recipes: Optional[bool] = True
    likes_on_recipes: Optional[bool] = True

class ProfileResponse(BaseModel):
    user_id: str
    email: str
    username: Optional[str] = None
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    dietary_preferences: List[str] = []
    favorite_cuisines: List[str] = []
    notification_settings: Optional[dict] = {}
    created_at: str
    updated_at: Optional[str] = None
    recipes_count: int = 0
    public_recipes_count: int = 0
    favorite_recipes: List[str] = []

# Authentication endpoints
@app.post("/auth/register", response_model=Token)
def register(user_data: UserRegister):
    """Register a new user"""
    print(f"📝 Registrando nuevo usuario: {user_data.email}")
    users = load_users()
    print(f"📋 Usuarios existentes: {len(users)}")
    
    # Check if email already exists
    for user_id, user_info in users.items():
        if user_info.get("email") == user_data.email.lower():
            print(f"⚠️ Email ya registrado: {user_data.email}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
    
    # Create new user
    user_id = user_data.email.lower().replace("@", "_at_").replace(".", "_")
    hashed_password = get_password_hash(user_data.password)
    
    # Asignar rol: admin SOLO para power4gods@gmail.com, user para el resto (por defecto)
    role = "admin" if user_data.email.lower() == "power4gods@gmail.com" else "user"
    print(f"👤 Creando usuario con rol: {role}")
    
    users[user_id] = {
        "email": user_data.email.lower(),
        "hashed_password": hashed_password,
        "username": user_data.username or user_data.email.split("@")[0],
        "role": role,
        "created_at": datetime.now().isoformat()
    }
    print(f"💾 Guardando usuario en base de datos...")
    save_users(users)
    print(f"✅ Usuario guardado: {user_id} ({user_data.email})")
    
    # Create profile
    profiles = load_profiles()
    print(f"📝 Creando perfil para usuario: {user_id}")
    profiles[user_id] = {
        "user_id": user_id,
        "email": user_data.email.lower(),
        "username": user_data.username or user_data.email.split("@")[0],
        "display_name": user_data.username or user_data.email.split("@")[0],
        "bio": "",
        "avatar_url": "",
        "dietary_preferences": [],
        "favorite_cuisines": [],
        "favorite_recipes": [],
        "ingredients": [],
        "followers_count": 0,
        "following_count": 0,
        "connections_count": 0,
        "notification_settings": {
            "email_notifications": True,
            "push_notifications": True,
            "recipe_updates": True,
            "new_followers": True,
            "comments_on_recipes": True,
            "likes_on_recipes": True
        },
        "created_at": datetime.now().isoformat(),
        "updated_at": None
    }
    
    # Initialize followers data
    followers_data = load_followers()
    if user_id not in followers_data:
        followers_data[user_id] = {
            "following": [],  # Users this user follows
            "followers": [],  # Users that follow this user
            "connections": []  # Mutual follows (bidirectional)
        }
        save_followers(followers_data)
    print(f"💾 Guardando perfil en base de datos...")
    save_profiles(profiles)
    print(f"✅ Perfil guardado para: {user_id}")
    
    # Verificar que el perfil se guardó correctamente
    profiles_verification = load_profiles()
    if user_id in profiles_verification:
        print(f"✅ Verificación: Perfil {user_id} existe en base de datos")
    else:
        print(f"❌ ERROR: Perfil {user_id} NO se encontró después de guardar")
    
    # Create access token
    print(f"🔑 Generando token JWT para: {user_id}")
    access_token = create_access_token(data={"sub": user_id})
    print(f"✅ Token generado (primeros 20 chars): {access_token[:20]}...")
    
    # Obtener el rol del usuario
    role = users[user_id].get("role", "user")
    if user_data.email.lower() == "power4gods@gmail.com" and role != "admin":
        role = "admin"
        users[user_id]["role"] = "admin"
        save_users(users)
    
    result = {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user_id,
        "email": user_data.email.lower(),
        "username": user_data.username or user_data.email.split("@")[0],
        "role": role
    }
    print(f"✅ Registro completado para: {user_data.email} (rol: {role})")
    print(f"📤 Retornando token JWT al cliente")
    return result

@app.post("/auth/login", response_model=Token)
def login(user_data: UserLogin):
    """Login and get access token"""
    users = load_users()
    
    # Find user by email
    user_id = None
    user_info = None
    for uid, info in users.items():
        if info.get("email") == user_data.email.lower():
            user_id = uid
            user_info = info
            break
    
    if not user_id or not user_info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Verify password
    if not verify_password(user_data.password, user_info.get("hashed_password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Create access token
    access_token = create_access_token(data={"sub": user_id})
    
    # Obtener el rol del usuario
    role = user_info.get("role", "user")
    if user_data.email.lower() == "power4gods@gmail.com" and role != "admin":
        role = "admin"
        user_info["role"] = "admin"
        users[user_id] = user_info
        save_users(users)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user_id,
        "email": user_info.get("email"),
        "role": role
    }

@app.get("/auth/me")
def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current authenticated user information"""
    return current_user  # Ya incluye user_id, email y role

# Profile endpoints
@app.get("/profile", response_model=ProfileResponse)
def get_profile(current_user: dict = Depends(get_current_user)):
    """Get user profile"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    profile = profiles[user_id].copy()
    
    # Count user's recipes
    private_recipes = load_recipes_private()
    public_recipes = load_recipes_public()
    user_private = [r for r in private_recipes if r.get("user_id") == user_id]
    user_public = [r for r in public_recipes if r.get("user_id") == user_id]
    
    profile["recipes_count"] = len(user_private) + len(user_public)
    profile["public_recipes_count"] = len(user_public)
    
    return profile

@app.get("/profiles/all")
def get_all_profiles(current_user: dict = Depends(get_current_user)):
    """Get all user profiles (for friends screen)"""
    profiles = load_profiles()
    users = load_users()
    followers_data = load_followers()
    current_user_id = current_user["user_id"]
    
    # Get current user's following list
    current_following = []
    if current_user_id in followers_data:
        current_following = followers_data[current_user_id].get("following", [])
    
    # Return all profiles as a list
    all_profiles = []
    
    # First, add all existing profiles
    for user_id, profile_data in profiles.items():
        if user_id == current_user_id:
            continue  # Skip current user
        
        # Skip admin user (power4gods@gmail.com)
        user_email = profile_data.get("email", "").lower()
        user_role = users.get(user_id, {}).get("role", "user")
        if user_email == "power4gods@gmail.com" or user_role == "admin":
            continue  # Skip admin user
            
        profile = profile_data.copy()
        
        # Count user's recipes
        private_recipes = load_recipes_private()
        public_recipes = load_recipes_public()
        user_private = [r for r in private_recipes if r.get("user_id") == user_id]
        user_public = [r for r in public_recipes if r.get("user_id") == user_id]
        
        profile["recipes_count"] = len(user_private) + len(user_public)
        profile["public_recipes_count"] = len(user_public)
        
        # Add follow status
        profile["is_following"] = user_id in current_following
        
        # Add follower counts
        if user_id in followers_data:
            profile["followers_count"] = len(followers_data[user_id].get("followers", []))
        else:
            profile["followers_count"] = 0
        
        all_profiles.append(profile)
    
    # Then, add users that don't have a profile yet
    for user_id, user_data in users.items():
        if user_id == current_user_id:
            continue  # Skip current user
        
        # Skip admin user
        user_email = user_data.get("email", "").lower()
        user_role = user_data.get("role", "user")
        if user_email == "power4gods@gmail.com" or user_role == "admin":
            continue  # Skip admin user
            
        if user_id not in profiles:
            # Create a basic profile from user data
            profile = {
                "user_id": user_id,
                "email": user_data.get("email", ""),
                "username": user_data.get("username") or user_data.get("email", "").split("@")[0],
                "display_name": user_data.get("username") or user_data.get("email", "").split("@")[0],
                "bio": None,
                "avatar_url": None,
                "dietary_preferences": [],
                "favorite_cuisines": [],
                "ingredients": [],
                "favorite_recipes": [],
                "recipes_count": 0,
                "public_recipes_count": 0,
                "followers_count": 0,
                "is_following": user_id in current_following,
                "created_at": user_data.get("created_at", datetime.now().isoformat()),
                "updated_at": datetime.now().isoformat(),
            }
            
            # Count user's recipes
            private_recipes = load_recipes_private()
            public_recipes = load_recipes_public()
            user_private = [r for r in private_recipes if r.get("user_id") == user_id]
            user_public = [r for r in public_recipes if r.get("user_id") == user_id]
            
            profile["recipes_count"] = len(user_private) + len(user_public)
            profile["public_recipes_count"] = len(user_public)
            
            # Add follower counts
            if user_id in followers_data:
                profile["followers_count"] = len(followers_data[user_id].get("followers", []))
            
            all_profiles.append(profile)
    
    return {"profiles": all_profiles}

@app.put("/profile")
def update_profile(profile_update: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    """Update user profile"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    profile = profiles[user_id]
    
    # Update only provided fields
    update_data = profile_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        if value is not None:
            profile[key] = value
    
    profile["updated_at"] = datetime.now().isoformat()
    save_profiles(profiles)
    
    return {"message": "Profile updated successfully", "profile": profile}

class AvatarUpdate(BaseModel):
    avatar_url: str = Field(..., description="URL of the avatar image")

@app.post("/profile/avatar")
def update_avatar(avatar_data: AvatarUpdate, current_user: dict = Depends(get_current_user)):
    """Update user avatar"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    profiles[user_id]["avatar_url"] = avatar_data.avatar_url
    profiles[user_id]["updated_at"] = datetime.now().isoformat()
    save_profiles(profiles)
    
    return {"message": "Avatar updated successfully", "avatar_url": avatar_data.avatar_url}

@app.post("/profile/password")
def update_password(password_update: PasswordUpdate, current_user: dict = Depends(get_current_user)):
    """Update user password"""
    users = load_users()
    user_id = current_user["user_id"]
    
    if user_id not in users:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Verify current password
    if not verify_password(password_update.current_password, users[user_id].get("hashed_password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )
    
    # Update password
    users[user_id]["hashed_password"] = get_password_hash(password_update.new_password)
    save_users(users)
    
    return {"message": "Password updated successfully"}

@app.get("/profile/favorites")
def get_favorite_recipes(current_user: dict = Depends(get_current_user)):
    """Get user's favorite recipes"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        return {"favorite_recipes": []}
    
    favorite_recipe_ids = profiles[user_id].get("favorite_recipes", [])
    
    # Get recipes from all sources
    all_recipes = []
    all_recipes.extend(load_recipes_general())
    all_recipes.extend(load_recipes_public())
    all_recipes.extend([r for r in load_recipes_private() if r.get("user_id") == user_id])
    
    # Filter favorite recipes
    favorite_recipes = []
    for recipe_id in favorite_recipe_ids:
        # Try to find recipe by title or other identifier
        for recipe in all_recipes:
            if recipe.get("title") == recipe_id or str(recipe.get("id", "")) == str(recipe_id):
                favorite_recipes.append(recipe)
                break
    
    return {"favorite_recipes": favorite_recipes, "count": len(favorite_recipes)}

@app.post("/profile/favorites/{recipe_id}")
def add_favorite_recipe(recipe_id: str, current_user: dict = Depends(get_current_user)):
    """Add a recipe to favorites"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    favorite_recipes = profiles[user_id].get("favorite_recipes", [])
    if recipe_id not in favorite_recipes:
        favorite_recipes.append(recipe_id)
        profiles[user_id]["favorite_recipes"] = favorite_recipes
        profiles[user_id]["updated_at"] = datetime.now().isoformat()
        save_profiles(profiles)
    
    return {"message": "Recipe added to favorites", "favorite_recipes": favorite_recipes}

@app.delete("/profile/favorites/{recipe_id}")
def remove_favorite_recipe(recipe_id: str, current_user: dict = Depends(get_current_user)):
    """Remove a recipe from favorites"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    favorite_recipes = profiles[user_id].get("favorite_recipes", [])
    if recipe_id in favorite_recipes:
        favorite_recipes.remove(recipe_id)
        profiles[user_id]["favorite_recipes"] = favorite_recipes
        profiles[user_id]["updated_at"] = datetime.now().isoformat()
        save_profiles(profiles)
    
    return {"message": "Recipe removed from favorites", "favorite_recipes": favorite_recipes}

@app.get("/profile/notifications")
def get_notification_settings(current_user: dict = Depends(get_current_user)):
    """Get user notification settings"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        return {"notification_settings": {}}
    
    return {"notification_settings": profiles[user_id].get("notification_settings", {})}

@app.put("/profile/notifications")
def update_notification_settings(settings: NotificationSettings, current_user: dict = Depends(get_current_user)):
    """Update user notification settings"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    current_settings = profiles[user_id].get("notification_settings", {})
    update_data = settings.dict(exclude_unset=True)
    current_settings.update(update_data)
    
    profiles[user_id]["notification_settings"] = current_settings
    profiles[user_id]["updated_at"] = datetime.now().isoformat()
    save_profiles(profiles)
    
    return {"message": "Notification settings updated", "notification_settings": current_settings}

# Ingredients management
class IngredientItem(BaseModel):
    name: str
    quantity: float = 1.0
    unit: str = "unidades"  # "unidades" or "gramos"

class IngredientsUpdate(BaseModel):
    ingredients: List[IngredientItem]

@app.get("/profile/ingredients")
def get_user_ingredients(current_user: dict = Depends(get_current_user)):
    """Get user's ingredients"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    # Create profile if it doesn't exist
    if user_id not in profiles:
        profiles[user_id] = {
            "user_id": user_id,
            "email": current_user.get("email", ""),
            "username": current_user.get("username"),
            "display_name": None,
            "bio": None,
            "avatar_url": None,
            "dietary_preferences": [],
            "favorite_cuisines": [],
            "ingredients": [],
            "followers_count": 0,
            "following_count": 0,
            "connections_count": 0,
            "notification_settings": {
                "email_notifications": True,
                "push_notifications": True,
                "new_followers": True,
                "likes_on_recipes": True,
            },
            "favorite_recipes": [],
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
        save_profiles(profiles)
        
        # Initialize followers data
        followers_data = load_followers()
        if user_id not in followers_data:
            followers_data[user_id] = {
                "following": [],
                "followers": [],
                "connections": []
            }
            save_followers(followers_data)
    
    ingredients = profiles[user_id].get("ingredients", [])
    # Convert old format (list of strings) to new format if needed
    if ingredients and isinstance(ingredients[0], str):
        ingredients = [{"name": ing, "quantity": 1.0, "unit": "unidades"} for ing in ingredients]
        profiles[user_id]["ingredients"] = ingredients
        save_profiles(profiles)
    
    return {"ingredients": ingredients, "count": len(ingredients)}

@app.put("/profile/ingredients")
def update_user_ingredients(request: dict, current_user: dict = Depends(get_current_user)):
    """Update user's ingredients (backward compatibility)"""
    try:
        profiles = load_profiles()
        user_id = current_user["user_id"]
        
        # Create profile if it doesn't exist
        if user_id not in profiles:
            profiles[user_id] = {
                "user_id": user_id,
                "email": current_user.get("email", ""),
                "username": current_user.get("username"),
                "display_name": None,
                "bio": None,
                "avatar_url": None,
                "dietary_preferences": [],
                "favorite_cuisines": [],
                "ingredients": [],
                "notification_settings": {
                    "email_notifications": True,
                    "push_notifications": True,
                    "new_followers": True,
                    "likes_on_recipes": True,
                },
                "favorite_recipes": [],
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
            }
            save_profiles(profiles)
        
        # Get ingredients from request
        ingredients_list = request.get("ingredients", [])
        
        # Validate and normalize ingredients
        normalized_ingredients = []
        for ing in ingredients_list:
            if isinstance(ing, dict):
                raw_name = str(ing.get("name", "")).lower().strip()
                normalized_name = to_singular(raw_name)
                normalized_ingredients.append({
                    "name": normalized_name,
                    "quantity": float(ing.get("quantity", 1.0)),
                    "unit": str(ing.get("unit", "unidades"))
                })
            elif isinstance(ing, str):
                # Backward compatibility with string format
                raw_name = ing.lower().strip()
                normalized_name = to_singular(raw_name)
                normalized_ingredients.append({
                    "name": normalized_name,
                    "quantity": 1.0,
                    "unit": "unidades"
                })
        
        # Guardar ingredientes en el perfil del usuario
        profiles[user_id]["ingredients"] = normalized_ingredients
        profiles[user_id]["updated_at"] = datetime.now().isoformat()
        
        # Guardar en el archivo JSON
        save_profiles(profiles)
        
        # Verificar que se guardó correctamente
        print(f"✅ Ingredientes guardados para usuario {user_id}: {len(normalized_ingredients)} ingredientes")
        print(f"   Ingredientes: {[ing['name'] for ing in normalized_ingredients]}")
        
        return {"message": "Ingredients updated", "ingredients": normalized_ingredients}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error updating ingredients: {str(e)}"
        )

def to_singular(ingredient: str) -> str:
    """Convierte un nombre de ingrediente del plural al singular"""
    if not ingredient:
        return ingredient
    
    lower = ingredient.lower().strip()
    
    # Reglas específicas para ingredientes comunes
    specific_rules = {
        'pollos': 'pollo',
        'cebollas': 'cebolla',
        'patatas': 'patata',
        'zanahorias': 'zanahoria',
        'tomates': 'tomate',
        'pimientos': 'pimiento',
        'ajos': 'ajo',
        'huevos': 'huevo',
        'limones': 'limón',
        'naranjas': 'naranja',
        'manzanas': 'manzana',
        'plátanos': 'plátano',
        'fresas': 'fresa',
        'uvas': 'uva',
        'lechugas': 'lechuga',
        'espinacas': 'espinaca',
        'pepinos': 'pepino',
        'calabacines': 'calabacín',
        'berenjenas': 'berenjena',
        'champiñones': 'champiñón',
        'setas': 'seta',
        'judías': 'judía',
        'garbanzos': 'garbanzo',
        'lentejas': 'lenteja',
        'alubias': 'alubia',
        'guisantes': 'guisante',
    }
    
    # Verificar reglas específicas primero
    if lower in specific_rules:
        return specific_rules[lower]
    
    # Reglas generales para plurales en español
    if lower.endswith('ces') and len(lower) > 3:
        return lower[:-3] + 'z'
    elif lower.endswith('es') and len(lower) > 3:
        without_es = lower[:-2]
        # Si termina en vocal antes de 'es', solo quitar 'es'
        if without_es and without_es[-1] in 'aeiou':
            return without_es
        return without_es
    elif lower.endswith('s') and len(lower) > 2:
        without_s = lower[:-1]
        # Si termina en vocal, solo quitar 's'
        if without_s and without_s[-1] in 'aeiou':
            return without_s
        # Si termina en consonante, mantener (puede ser singular ya)
        return lower
    
    # Si no coincide con ninguna regla, retornar original
    return lower

@app.post("/profile/ingredients/{ingredient_name}")
def add_user_ingredient(
    ingredient_name: str,
    quantity: Optional[float] = 1.0,
    unit: Optional[str] = "unidades",
    current_user: dict = Depends(get_current_user)
):
    """Add a single ingredient to user's list (like favorites)"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    # Normalizar al singular
    normalized_name = to_singular(ingredient_name.lower().strip())
    print(f"🔄 Normalizando ingrediente: '{ingredient_name}' -> '{normalized_name}'")
    
    ingredients = profiles[user_id].get("ingredients", [])
    ingredient_normalized = {
        "name": normalized_name,
        "quantity": float(quantity),
        "unit": str(unit)
    }
    
    # Check if ingredient already exists
    ingredient_exists = any(
        ing.get("name", "").lower() == ingredient_normalized["name"]
        for ing in ingredients
    )
    
    if not ingredient_exists:
        ingredients.append(ingredient_normalized)
        profiles[user_id]["ingredients"] = ingredients
        profiles[user_id]["updated_at"] = datetime.now().isoformat()
        save_profiles(profiles)
        print(f"✅ Ingrediente añadido: {ingredient_normalized['name']}")
    
    return {"message": "Ingredient added", "ingredients": ingredients}

@app.delete("/profile/ingredients/{ingredient_name}")
def remove_user_ingredient(
    ingredient_name: str,
    current_user: dict = Depends(get_current_user)
):
    """Remove a single ingredient from user's list (like favorites)"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    ingredients = profiles[user_id].get("ingredients", [])
    ingredient_name_lower = ingredient_name.lower().strip()
    
    # Remove ingredient by name
    ingredients = [
        ing for ing in ingredients
        if ing.get("name", "").lower() != ingredient_name_lower
    ]
    
    profiles[user_id]["ingredients"] = ingredients
    profiles[user_id]["updated_at"] = datetime.now().isoformat()
    save_profiles(profiles)
    print(f"✅ Ingrediente eliminado: {ingredient_name_lower}")
    
    return {"message": "Ingredient removed", "ingredients": ingredients}

@app.get("/profile/shopping-list")
def get_shopping_list(current_user: dict = Depends(get_current_user)):
    """Get user's shopping list"""
    user_id = current_user["user_id"]
    profiles = load_profiles()
    
    if user_id not in profiles:
        return {"shopping_list": []}
    
    return {"shopping_list": profiles[user_id].get("shopping_list", [])}

@app.put("/profile/shopping-list")
def update_shopping_list(
    request: dict,
    current_user: dict = Depends(get_current_user)
):
    """Update user's shopping list"""
    try:
        user_id = current_user["user_id"]
        profiles = load_profiles()
        
        if user_id not in profiles:
            profiles[user_id] = {
                "user_id": user_id,
                "bio": "",
                "favorite_cuisines": [],
                "ingredients": [],
                "shopping_list": [],
                "followers_count": 0,
                "following_count": 0,
                "connections_count": 0,
                "notification_settings": {
                    "email_notifications": True,
                    "push_notifications": True,
                    "new_followers": True,
                    "likes_on_recipes": True,
                },
                "favorite_recipes": [],
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
            }
            save_profiles(profiles)
            
            # Initialize followers data
            followers_data = load_followers()
            if user_id not in followers_data:
                followers_data[user_id] = {
                    "following": [],
                    "followers": [],
                    "connections": []
                }
                save_followers(followers_data)
        
        shopping_list = request.get("shopping_list", [])
        profiles[user_id]["shopping_list"] = shopping_list
        profiles[user_id]["updated_at"] = datetime.now().isoformat()
        save_profiles(profiles)
        
        return {"message": "Shopping list updated", "shopping_list": shopping_list}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error updating shopping list: {str(e)}"
        )

# AI Menu Generation
class MenuGenerationRequest(BaseModel):
    ingredients: List[str]  # List of ingredient names (for compatibility)
    meal_types: Optional[List[str]] = None  # List of meal types (Desayuno, Comida, Cena)

class RecipeGenerationRequest(BaseModel):
    meal_type: str = "Comida"  # Desayuno, Comida, or Cena
    ingredients: Optional[List[str]] = None  # Optional list of ingredients to use
    num_recipes: int = 5  # Number of recipes to generate

@app.post("/ai/generate-menu")
def generate_menu_with_ai(request: MenuGenerationRequest, current_user: dict = Depends(get_current_user)):
    """Generate menu suggestions using AI based on user's ingredients"""
    import os
    
    # Extract ingredient names from the list
    ingredient_names = request.ingredients
    meal_types = request.meal_types or ['Desayuno', 'Comida', 'Cena']
    
    # OpenAI Integration (Ready but disabled - requires API key)
    # Uncomment and configure when you have OpenAI API key:
    #
    # OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    # if not OPENAI_API_KEY:
    #     # Fallback to rule-based if no API key
    #     pass
    # else:
    #     try:
    #         import openai
    #         openai.api_key = OPENAI_API_KEY
    #         
    #         prompt = f"""Eres un asistente culinario experto. 
    #         Genera un menú completo (desayuno, comida y cena) usando estos ingredientes: {', '.join(ingredient_names)}
    #         
    #         Responde en formato JSON con esta estructura:
    #         {{
    #             "menu": [
    #                 {{
    #                     "meal_type": "Desayuno",
    #                     "name": "Nombre del plato",
    #                     "description": "Descripción breve",
    #                     "ingredients": ["ingrediente1", "ingrediente2"],
    #                     "instructions": "Instrucciones paso a paso",
    #                     "time_minutes": 30
    #                 }},
    #                 {{
    #                     "meal_type": "Comida",
    #                     ...
    #                 }},
    #                 {{
    #                     "meal_type": "Cena",
    #                     ...
    #                 }}
    #             ]
    #         }}"""
    #         
    #         response = openai.ChatCompletion.create(
    #             model="gpt-3.5-turbo",
    #             messages=[
    #                 {
    #                     "role": "system",
    #                     "content": "Eres un chef profesional que crea menús creativos y nutritivos. Responde siempre en formato JSON válido."
    #                 },
    #                 {
    #                     "role": "user",
    #                     "content": prompt
    #                 }
    #             ],
    #             temperature=0.7,
    #             max_tokens=1500
    #         )
    #         
    #         ai_response = response.choices[0].message.content
    #         # Parse JSON response
    #         import json
    #         ai_menu_data = json.loads(ai_response)
    #         
    #         return {
    #             "message": "Menu generated successfully with AI",
    #             "ingredients_used": request.ingredients,
    #             "menu": ai_menu_data.get("menu", []),
    #             "ai_generated": True
    #         }
    #     except Exception as e:
    #         print(f"OpenAI API error: {e}")
    #         # Fallback to rule-based
    #         pass
    
    # Rule-based fallback (currently active)
    ingredients = [ing.lower() for ing in ingredient_names]
    
    # Simple menu generation logic (replace with actual AI in production)
    menu = []
    
    # Generate suggestions only for selected meal types
    if 'Desayuno' in meal_types:
        breakfast_options = []
        if any(ing in ['huevo', 'huevos', 'egg', 'eggs'] for ing in ingredients):
            breakfast_options.append({
                "meal_type": "Desayuno",
                "name": "Huevos revueltos",
                "description": "Huevos revueltos con ingredientes disponibles",
                "ingredients": [i for i in ingredients if i in ['huevo', 'huevos', 'egg', 'eggs', 'cebolla', 'pimiento', 'bacon']],
                "instructions": "Bate los huevos, añade los ingredientes picados y cocina en una sartén.",
                "time_minutes": 15
            })
        
        if breakfast_options:
            menu.append(breakfast_options[0])
        else:
            menu.append({
                "meal_type": "Desayuno",
                "name": "Desayuno con ingredientes disponibles",
                "description": f"Prepara un desayuno usando: {', '.join(ingredients[:3])}",
                "ingredients": ingredients[:3],
                "instructions": "Combina los ingredientes disponibles para crear un desayuno nutritivo.",
                "time_minutes": 20
            })
    
    if 'Comida' in meal_types:
        lunch_options = []
        if any(ing in ['pollo', 'chicken'] for ing in ingredients):
            lunch_options.append({
                "meal_type": "Comida",
                "name": "Pollo con verduras",
                "description": f"Pollo preparado con {', '.join([i for i in ingredients if i not in ['pollo', 'chicken']][:3])}",
                "ingredients": [i for i in ingredients if i in ['pollo', 'chicken', 'cebolla', 'pimiento', 'tomate', 'nata']],
                "instructions": "Cocina el pollo y añade las verduras. Si tienes nata, puedes hacer una salsa cremosa.",
                "time_minutes": 45
            })
        
        if lunch_options:
            menu.append(lunch_options[0])
        else:
            menu.append({
                "meal_type": "Comida",
                "name": "Plato principal con ingredientes disponibles",
                "description": f"Prepara un plato principal usando: {', '.join(ingredients[:4])}",
                "ingredients": ingredients[:4],
                "instructions": "Combina los ingredientes principales para crear un plato completo.",
                "time_minutes": 40
            })
    
    if 'Cena' in meal_types:
        dinner_options = []
        if any(ing in ['bacon', 'panceta'] for ing in ingredients):
            dinner_options.append({
                "meal_type": "Cena",
                "name": "Cena ligera con bacon",
                "description": f"Cena preparada con bacon y {', '.join([i for i in ingredients if i not in ['bacon', 'panceta']][:2])}",
                "ingredients": [i for i in ingredients if i in ['bacon', 'panceta', 'huevo', 'huevos', 'cebolla', 'pimiento']],
                "instructions": "Cocina el bacon hasta que esté crujiente. Añade los otros ingredientes y sirve.",
                "time_minutes": 25
            })
        
        if dinner_options:
            menu.append(dinner_options[0])
        else:
            menu.append({
            "meal_type": "Cena",
            "name": "Cena ligera",
            "description": f"Prepara una cena ligera usando: {', '.join(ingredients[:3])}",
            "ingredients": ingredients[:3],
            "instructions": "Combina los ingredientes para una cena nutritiva y ligera.",
            "time_minutes": 30
        })
    
    return {
        "message": "Menu generated successfully",
        "ingredients_used": request.ingredients,
        "menu": menu,
        "suggestions": f"Basado en tus ingredientes: {', '.join(request.ingredients)}",
        "ai_generated": False  # Set to True when using OpenAI
    }

# Save AI-generated menu as favorite
class SaveMenuRequest(BaseModel):
    menu: List[dict]
    menu_name: Optional[str] = "Menú generado por IA"

@app.post("/ai/generate-recipes")
def generate_recipes_with_ai(request: RecipeGenerationRequest, current_user: dict = Depends(get_current_user)):
    """Generate 5 recipes using AI based on meal type and optional ingredients"""
    import os
    import json
    
    meal_type = request.meal_type
    ingredients = request.ingredients or []
    num_recipes = min(request.num_recipes, 10)  # Limit to 10 recipes max
    
    # Try to use OpenAI API (gpt-3.5-turbo is cheap: $0.50 per 1M tokens)
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    
    if not OPENAI_API_KEY:
        # Fallback to rule-based if no API key
        return {
            "error": "OpenAI API key not configured. Please set OPENAI_API_KEY environment variable.",
            "recipes": [],
            "fallback": True
        }
    
    try:
        from openai import OpenAI
        client = OpenAI(api_key=OPENAI_API_KEY)
        
        # Build prompt
        ingredients_text = f"usando estos ingredientes: {', '.join(ingredients)}" if ingredients else "con ingredientes comunes y nutritivos"
        
        prompt = f"""Eres un chef profesional y nutricionista experto. Genera exactamente {num_recipes} recetas para {meal_type.lower()} {ingredients_text}.

IMPORTANTE: Responde SOLO con un JSON válido, sin texto adicional antes o después.

Formato requerido (array de objetos):
[
  {{
    "title": "Nombre de la receta",
    "description": "Descripción breve y atractiva de la receta",
    "ingredients": "ingrediente1,ingrediente2,ingrediente3",
    "time_minutes": 30,
    "difficulty": "Fácil",
    "tags": "tag1,tag2,tag3",
    "nutrients": "calories 450,protein 25.0g,carbs 50.0g,fat 15.0g",
    "servings": 4,
    "calories_per_serving": 450
  }},
  ...
]

Reglas:
- Genera exactamente {num_recipes} recetas
- Todas deben ser para {meal_type.lower()}
- "difficulty" debe ser: "Fácil", "Media", o "Difícil"
- "time_minutes" debe ser un número realista (15-120)
- "servings" debe ser un número (2-8)
- "calories_per_serving" debe ser un número razonable (200-800)
- "ingredients" debe ser una cadena separada por comas, sin espacios después de las comas
- "nutrients" debe incluir: calories, protein, carbs, fat (en gramos)
- Las recetas deben ser variadas, creativas y nutritivas
- Si se proporcionaron ingredientes, úsalos como base pero puedes añadir otros comunes
"""
        
        print(f"🤖 Generando {num_recipes} recetas para {meal_type} con IA...")
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system",
                    "content": "Eres un chef profesional que crea recetas creativas y nutritivas. Responde SIEMPRE en formato JSON válido, sin texto adicional."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.8,
            max_tokens=3000
        )
        
        ai_response = response.choices[0].message.content.strip()
        
        # Clean response - remove markdown code blocks if present
        if ai_response.startswith("```json"):
            ai_response = ai_response[7:]
        if ai_response.startswith("```"):
            ai_response = ai_response[3:]
        if ai_response.endswith("```"):
            ai_response = ai_response[:-3]
        ai_response = ai_response.strip()
        
        # Parse JSON response
        try:
            recipes = json.loads(ai_response)
            if not isinstance(recipes, list):
                recipes = [recipes]
            
            # Ensure all recipes have required fields and format correctly
            formatted_recipes = []
            for recipe in recipes[:num_recipes]:
                formatted_recipe = {
                    "title": recipe.get("title", "Receta sin título"),
                    "description": recipe.get("description", ""),
                    "ingredients": recipe.get("ingredients", ""),
                    "time_minutes": int(recipe.get("time_minutes", 30)),
                    "difficulty": recipe.get("difficulty", "Media"),
                    "tags": recipe.get("tags", ""),
                    "image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop",
                    "nutrients": recipe.get("nutrients", ""),
                    "servings": int(recipe.get("servings", 4)),
                    "calories_per_serving": int(recipe.get("calories_per_serving", 0)),
                    "is_ai_generated": True,
                    "meal_type": meal_type,
                }
                formatted_recipes.append(formatted_recipe)
            
            print(f"✅ Generadas {len(formatted_recipes)} recetas con IA")
            
            return {
                "message": f"Recetas generadas exitosamente para {meal_type}",
                "recipes": formatted_recipes,
                "meal_type": meal_type,
                "ai_generated": True
            }
            
        except json.JSONDecodeError as e:
            print(f"❌ Error parseando JSON de IA: {e}")
            print(f"Respuesta recibida: {ai_response[:500]}")
            return {
                "error": f"Error parseando respuesta de IA: {str(e)}",
                "recipes": [],
                "raw_response": ai_response[:200]
            }
            
    except Exception as e:
        print(f"❌ Error con OpenAI API: {e}")
        import traceback
        traceback.print_exc()
        return {
            "error": f"Error con API de IA: {str(e)}",
            "recipes": [],
            "fallback": True
        }

@app.post("/ai/save-menu")
def save_ai_menu(save_request: SaveMenuRequest, current_user: dict = Depends(get_current_user)):
    """Save an AI-generated menu as a favorite recipe collection"""
    profiles = load_profiles()
    user_id = current_user["user_id"]
    
    if user_id not in profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    
    # Create a recipe collection from the menu
    menu_id = f"ai_menu_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Save each meal as a recipe in private recipes
    recipes = load_recipes_private()
    saved_recipe_ids = []
    
    for meal in save_request.menu:
        recipe = {
            "title": meal.get("name", "Receta sin nombre"),
            "ingredients": ",".join(meal.get("ingredients", [])),
            "time_minutes": meal.get("time_minutes", 30),
            "difficulty": "Media",
            "tags": f"ai-generated,{meal.get('meal_type', '').lower()}",
            "image_url": "",
            "description": meal.get("instructions", meal.get("description", "")),
            "nutrients": "",
            "user_id": user_id,
            "created_at": datetime.now().isoformat(),
            "is_public": False,
            "is_ai_generated": True,
            "meal_type": meal.get("meal_type", ""),
            "menu_id": menu_id
        }
        recipes.append(recipe)
        saved_recipe_ids.append(str(len(recipes) - 1))
    
    save_recipes_private(recipes)
    
    # Add all recipes to favorites
    favorite_recipes = profiles[user_id].get("favorite_recipes", [])
    favorite_recipes.extend(saved_recipe_ids)
    profiles[user_id]["favorite_recipes"] = favorite_recipes
    profiles[user_id]["updated_at"] = datetime.now().isoformat()
    save_profiles(profiles)
    
    return {
        "message": "Menu saved as favorites successfully",
        "menu_id": menu_id,
        "recipes_saved": len(saved_recipe_ids),
        "recipe_ids": saved_recipe_ids
    }

@app.post("/profile/follow/{target_user_id}")
def follow_user(target_user_id: str, current_user: dict = Depends(get_current_user)):
    """Follow a user"""
    user_id = current_user["user_id"]
    
    if user_id == target_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot follow yourself"
        )
    
    followers_data = load_followers()
    profiles = load_profiles()
    
    # Initialize if needed
    if user_id not in followers_data:
        followers_data[user_id] = {"following": [], "followers": [], "connections": []}
    if target_user_id not in followers_data:
        followers_data[target_user_id] = {"following": [], "followers": [], "connections": []}
    
    # Check if already following
    if target_user_id in followers_data[user_id]["following"]:
        return {"message": "Already following", "following": True}
    
    # Add to following list
    followers_data[user_id]["following"].append(target_user_id)
    
    # Add to target's followers list
    if user_id not in followers_data[target_user_id]["followers"]:
        followers_data[target_user_id]["followers"].append(user_id)
    
    # Check if it's a mutual follow (connection)
    if user_id in followers_data[target_user_id]["following"]:
        if target_user_id not in followers_data[user_id]["connections"]:
            followers_data[user_id]["connections"].append(target_user_id)
        if user_id not in followers_data[target_user_id]["connections"]:
            followers_data[target_user_id]["connections"].append(user_id)
    
    save_followers(followers_data)
    
    # Update profile counts
    if user_id in profiles:
        profiles[user_id]["following_count"] = len(followers_data[user_id]["following"])
        profiles[user_id]["connections_count"] = len(followers_data[user_id]["connections"])
        save_profiles(profiles)
    
    if target_user_id in profiles:
        profiles[target_user_id]["followers_count"] = len(followers_data[target_user_id]["followers"])
        profiles[target_user_id]["connections_count"] = len(followers_data[target_user_id]["connections"])
        save_profiles(profiles)
    
    # Create notification for target user
    if target_user_id in profiles:
        notifications = profiles[target_user_id].get("notifications", [])
        notifications.append({
            "type": "new_follower",
            "from_user_id": user_id,
            "from_username": profiles.get(user_id, {}).get("username", "Usuario"),
            "message": f"{profiles.get(user_id, {}).get('username', 'Usuario')} empezó a seguirte",
            "created_at": datetime.now().isoformat(),
            "read": False
        })
        profiles[target_user_id]["notifications"] = notifications
        save_profiles(profiles)
    
    return {"message": "User followed successfully", "following": True}

@app.delete("/profile/follow/{target_user_id}")
def unfollow_user(target_user_id: str, current_user: dict = Depends(get_current_user)):
    """Unfollow a user"""
    user_id = current_user["user_id"]
    
    followers_data = load_followers()
    profiles = load_profiles()
    
    if user_id not in followers_data or target_user_id not in followers_data[user_id]["following"]:
        return {"message": "Not following", "following": False}
    
    # Remove from following list
    followers_data[user_id]["following"].remove(target_user_id)
    
    # Remove from target's followers list
    if user_id in followers_data[target_user_id]["followers"]:
        followers_data[target_user_id]["followers"].remove(user_id)
    
    # Remove from connections if it was mutual
    if target_user_id in followers_data[user_id]["connections"]:
        followers_data[user_id]["connections"].remove(target_user_id)
    if user_id in followers_data[target_user_id]["connections"]:
        followers_data[target_user_id]["connections"].remove(user_id)
    
    save_followers(followers_data)
    
    # Update profile counts
    if user_id in profiles:
        profiles[user_id]["following_count"] = len(followers_data[user_id]["following"])
        profiles[user_id]["connections_count"] = len(followers_data[user_id]["connections"])
        save_profiles(profiles)
    
    if target_user_id in profiles:
        profiles[target_user_id]["followers_count"] = len(followers_data[target_user_id]["followers"])
        profiles[target_user_id]["connections_count"] = len(followers_data[target_user_id]["connections"])
        save_profiles(profiles)
    
    return {"message": "User unfollowed successfully", "following": False}

@app.get("/profile/following")
def get_following(current_user: dict = Depends(get_current_user)):
    """Get users that current user is following"""
    user_id = current_user["user_id"]
    followers_data = load_followers()
    profiles = load_profiles()
    
    if user_id not in followers_data:
        return {"following": []}
    
    following_ids = followers_data[user_id]["following"]
    following_profiles = []
    
    for follow_id in following_ids:
        if follow_id in profiles:
            profile = profiles[follow_id].copy()
            private_recipes = load_recipes_private()
            public_recipes = load_recipes_public()
            user_public = [r for r in public_recipes if r.get("user_id") == follow_id]
            profile["public_recipes_count"] = len(user_public)
            following_profiles.append(profile)
    
    return {"following": following_profiles}

@app.get("/profile/stats")
def get_profile_stats(current_user: dict = Depends(get_current_user)):
    """Get current user's follow stats"""
    user_id = current_user["user_id"]
    followers_data = load_followers()
    
    if user_id not in followers_data:
        return {
            "followers_count": 0,
            "following_count": 0,
            "connections_count": 0
        }
    
    return {
        "followers_count": len(followers_data[user_id]["followers"]),
        "following_count": len(followers_data[user_id]["following"]),
        "connections_count": len(followers_data[user_id]["connections"])
    }

@app.delete("/profile/account")
def delete_account(current_user: dict = Depends(get_current_user)):
    """Delete user account and all associated data"""
    user_id = current_user["user_id"]
    
    # Delete user from users
    users = load_users()
    if user_id in users:
        del users[user_id]
        save_users(users)
    
    # Delete profile
    profiles = load_profiles()
    if user_id in profiles:
        del profiles[user_id]
        save_profiles(profiles)
    
    # Remove from followers data
    followers_data = load_followers()
    if user_id in followers_data:
        # Remove from all following/followers lists
        for other_user_id in list(followers_data.keys()):
            if other_user_id != user_id:
                if user_id in followers_data[other_user_id]["following"]:
                    followers_data[other_user_id]["following"].remove(user_id)
                if user_id in followers_data[other_user_id]["followers"]:
                    followers_data[other_user_id]["followers"].remove(user_id)
                if user_id in followers_data[other_user_id]["connections"]:
                    followers_data[other_user_id]["connections"].remove(user_id)
        del followers_data[user_id]
        save_followers(followers_data)
    
    # Delete user's private recipes
    private_recipes = load_recipes_private()
    private_recipes = [r for r in private_recipes if r.get("user_id") != user_id]
    save_recipes_private(private_recipes)
    
    # Delete user's public recipes
    public_recipes = load_recipes_public()
    public_recipes = [r for r in public_recipes if r.get("user_id") != user_id]
    save_recipes_public(public_recipes)
    
    return {"message": "Account deleted successfully"}

class ProfileResponse(BaseModel):
    user_id: str
    email: str
    username: Optional[str] = None
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    dietary_preferences: List[str] = []
    favorite_cuisines: List[str] = []
    created_at: str
    updated_at: Optional[str] = None
    recipes_count: int = 0
    public_recipes_count: int = 0

# Request model for search
class SearchQuery(BaseModel):
    query: Optional[str] = ""
    ingredients: Optional[List[str]] = Field(default=None, description="List of ingredients to filter by")
    time_minutes: Optional[int] = Field(default=None, description="Maximum cooking time in minutes")
    difficulty: Optional[str] = Field(default=None, description="Difficulty level (Fácil, Media, Difícil)")
    tags: Optional[List[str]] = None
    calories_max: Optional[int] = None

# Recipe model for creating new recipes
class RecipeCreate(BaseModel):
    title: str = Field(..., min_length=1, description="Recipe title")
    ingredients: str = Field(..., min_length=1, description="Comma-separated list of ingredients")
    time_minutes: int = Field(..., gt=0, description="Cooking time in minutes")
    difficulty: str = Field(..., description="Difficulty level (Fácil, Media, Difícil)")
    tags: str = Field(default="", description="Comma-separated tags")
    image_url: Optional[str] = Field(default="", description="URL of recipe image")
    description: str = Field(..., min_length=1, description="Recipe description/instructions")
    nutrients: str = Field(default="calories 0", description="Nutritional information (e.g., 'calories 300')")
    servings: Optional[float] = Field(default=4.0, description="Number of servings")
    calories_per_serving: Optional[int] = Field(default=None, description="Calories per serving (calculated from ingredients)")
    user_id: Optional[str] = Field(default="anonymous", description="User ID (for future authentication)")

@app.get("/recipes/general")
def get_general_recipes():
    """Get all precompiled recipes"""
    recipes = load_recipes_general()
    return {"recipes": recipes, "count": len(recipes), "type": "general"}

@app.put("/recipes/general/{recipe_id}")
def update_general_recipe(recipe_id: int, recipe: RecipeCreate, current_user: dict = Depends(get_current_user)):
    """Update a general recipe (only admin can edit general recipes)"""
    user_role = current_user.get("role", "user")
    
    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can edit general recipes")
    
    recipes = load_recipes_general()
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    # Update recipe
    updated_recipe = {
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "time_minutes": recipe.time_minutes,
        "difficulty": recipe.difficulty,
        "tags": recipe.tags,
        "image_url": recipe.image_url or "",
        "description": recipe.description,
        "nutrients": recipe.nutrients,
        "updated_at": datetime.now().isoformat()
    }
    
    # Preserve creation metadata
    if "created_at" in recipes[recipe_id]:
        updated_recipe["created_at"] = recipes[recipe_id]["created_at"]
    
    recipes[recipe_id] = updated_recipe
    
    # Save to file
    save_recipes_general(recipes)
    
    return {
        "message": "General recipe updated successfully",
        "recipe": updated_recipe,
        "id": recipe_id
    }

@app.delete("/recipes/general/{recipe_id}")
def delete_general_recipe(recipe_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a general recipe (only admin can delete general recipes)"""
    user_role = current_user.get("role", "user")
    
    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can delete general recipes")
    
    recipes = load_recipes_general()
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    deleted_recipe = recipes.pop(recipe_id)
    save_recipes_general(recipes)
    
    return {
        "message": "General recipe deleted successfully",
        "recipe": deleted_recipe
    }

@app.get("/recipes/public")
def get_public_recipes():
    """Get all public user-created recipes (no authentication required)"""
    recipes = load_recipes_public()
    print(f"📋 Returning {len(recipes)} public recipes")
    return {"recipes": recipes, "count": len(recipes), "type": "public"}

@app.get("/recipes/private")
def get_private_recipes(current_user: dict = Depends(get_current_user)):
    """Get private recipes for the authenticated user"""
    recipes = load_recipes_private()
    user_id = current_user["user_id"]
    user_recipes = [r for r in recipes if r.get("user_id") == user_id]
    return {"recipes": user_recipes, "count": len(user_recipes), "type": "private", "user_id": user_id}

@app.get("/recipes/all")
def get_all_recipes(current_user: dict = Depends(get_current_user)):
    """Get all recipes: general, public, and authenticated user's private recipes"""
    general = load_recipes_general()
    public = load_recipes_public()
    user_id = current_user["user_id"]
    private = [r for r in load_recipes_private() if r.get("user_id") == user_id]
    
    return {
        "general": {"recipes": general, "count": len(general)},
        "public": {"recipes": public, "count": len(public)},
        "private": {"recipes": private, "count": len(private)},
        "total": len(general) + len(public) + len(private)
    }

@app.post("/recipes/private")
def create_private_recipe(recipe: RecipeCreate, current_user: dict = Depends(get_current_user)):
    """Create a new private recipe for the authenticated user"""
    recipes = load_recipes_private()
    user_id = current_user["user_id"]
    
    # Calculate calories_per_serving from nutrients string if not provided
    calories_per_serving = recipe.calories_per_serving
    if calories_per_serving is None:
        # Try to extract from nutrients string (format: "calories 300, protein 20, ...")
        try:
            nutrients_parts = recipe.nutrients.split(',')
            for part in nutrients_parts:
                if 'calories' in part.lower():
                    calories_total = int(part.split()[-1])
                    servings = recipe.servings or 4.0
                    calories_per_serving = int(calories_total / servings)
                    break
        except:
            calories_per_serving = 0
    
    # Create recipe dictionary
    new_recipe = {
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "time_minutes": recipe.time_minutes,
        "difficulty": recipe.difficulty,
        "tags": recipe.tags,
        "image_url": recipe.image_url or "",
        "description": recipe.description,
        "nutrients": recipe.nutrients,
        "servings": recipe.servings or 4.0,
        "calories_per_serving": calories_per_serving or 0,
        "user_id": user_id,  # Use authenticated user ID
        "created_at": datetime.now().isoformat(),
        "is_public": False
    }
    
    # Add to private recipes list
    recipes.append(new_recipe)
    
    # Save to file
    save_recipes_private(recipes)
    
    return {
        "message": "Private recipe created successfully",
        "recipe": new_recipe,
        "id": len(recipes) - 1
    }

@app.put("/recipes/private/{recipe_id}")
def update_private_recipe(recipe_id: int, recipe: RecipeCreate, current_user: dict = Depends(get_current_user)):
    """Update a private recipe (only if it belongs to the authenticated user)"""
    recipes = load_recipes_private()
    user_id = current_user["user_id"]
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    # Check if recipe belongs to user
    if recipes[recipe_id].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="You don't have permission to update this recipe")
    
    # Calculate calories_per_serving from nutrients string if not provided
    calories_per_serving = recipe.calories_per_serving
    if calories_per_serving is None:
        try:
            nutrients_parts = recipe.nutrients.split(',')
            for part in nutrients_parts:
                if 'calories' in part.lower():
                    calories_total = int(part.split()[-1])
                    servings = recipe.servings or 4.0
                    calories_per_serving = int(calories_total / servings)
                    break
        except:
            calories_per_serving = recipes[recipe_id].get("calories_per_serving", 0)
    
    # Update recipe
    updated_recipe = {
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "time_minutes": recipe.time_minutes,
        "difficulty": recipe.difficulty,
        "tags": recipe.tags,
        "image_url": recipe.image_url or "",
        "description": recipe.description,
        "nutrients": recipe.nutrients,
        "servings": recipe.servings or recipes[recipe_id].get("servings", 4.0),
        "calories_per_serving": calories_per_serving or recipes[recipe_id].get("calories_per_serving", 0),
        "user_id": user_id,
        "updated_at": datetime.now().isoformat()
    }
    
    # Preserve creation metadata
    if "created_at" in recipes[recipe_id]:
        updated_recipe["created_at"] = recipes[recipe_id]["created_at"]
    if "is_public" in recipes[recipe_id]:
        updated_recipe["is_public"] = recipes[recipe_id]["is_public"]
    
    recipes[recipe_id] = updated_recipe
    
    # Save to file
    save_recipes_private(recipes)
    
    return {
        "message": "Private recipe updated successfully",
        "recipe": updated_recipe,
        "id": recipe_id
    }

@app.put("/recipes/public/{recipe_id}")
def update_public_recipe(recipe_id: int, recipe: RecipeCreate, current_user: dict = Depends(get_current_user)):
    """Update a public recipe (only admin can edit any public recipe, users can only edit their own)"""
    recipes = load_recipes_public()
    user_id = current_user["user_id"]
    user_role = current_user.get("role", "user")
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    # Admin can edit any public recipe, users can only edit their own
    if user_role != "admin" and recipes[recipe_id].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="You don't have permission to update this recipe. Only admins can edit all public recipes.")
    
    # Calculate calories_per_serving from nutrients string if not provided
    calories_per_serving = recipe.calories_per_serving
    if calories_per_serving is None:
        try:
            nutrients_parts = recipe.nutrients.split(',')
            for part in nutrients_parts:
                if 'calories' in part.lower():
                    calories_total = int(part.split()[-1])
                    servings = recipe.servings or 4.0
                    calories_per_serving = int(calories_total / servings)
                    break
        except:
            calories_per_serving = recipes[recipe_id].get("calories_per_serving", 0)
    
    # Update recipe
    updated_recipe = {
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "time_minutes": recipe.time_minutes,
        "difficulty": recipe.difficulty,
        "tags": recipe.tags,
        "image_url": recipe.image_url or "",
        "description": recipe.description,
        "nutrients": recipe.nutrients,
        "servings": recipe.servings or recipes[recipe_id].get("servings", 4.0),
        "calories_per_serving": calories_per_serving or recipes[recipe_id].get("calories_per_serving", 0),
        "user_id": user_id,
        "updated_at": datetime.now().isoformat()
    }
    
    # Preserve creation metadata
    if "created_at" in recipes[recipe_id]:
        updated_recipe["created_at"] = recipes[recipe_id]["created_at"]
    updated_recipe["is_public"] = True
    
    recipes[recipe_id] = updated_recipe
    
    # Save to file
    save_recipes_public(recipes)
    
    return {
        "message": "Public recipe updated successfully",
        "recipe": updated_recipe,
        "id": recipe_id
    }

@app.post("/recipes/private/{recipe_id}/make-public")
def make_recipe_public(recipe_id: int, current_user: dict = Depends(get_current_user)):
    """Move a recipe from private to public"""
    private_recipes = load_recipes_private()
    user_id = current_user["user_id"]
    
    # Try to find recipe by index first
    recipe_index = None
    if 0 <= recipe_id < len(private_recipes):
        if private_recipes[recipe_id].get("user_id") == user_id:
            recipe_index = recipe_id
    
    # If not found by index, search by title (for compatibility)
    if recipe_index is None:
        # Try to find by title if recipe_id is actually a title string
        for i, r in enumerate(private_recipes):
            if r.get("user_id") == user_id and str(r.get("title", "")) == str(recipe_id):
                recipe_index = i
                break
    
    if recipe_index is None:
        raise HTTPException(status_code=404, detail="Recipe not found or you don't have permission")
    
    # Get the recipe
    recipe = private_recipes[recipe_index].copy()
    recipe["is_public"] = True
    recipe["made_public_at"] = datetime.now().isoformat()
    
    # Keep in private (mark as public) AND add to public
    private_recipes[recipe_index]["is_public"] = True
    private_recipes[recipe_index]["made_public_at"] = datetime.now().isoformat()
    save_recipes_private(private_recipes)
    
    public_recipes = load_recipes_public()
    # Verificar que la receta no esté ya en públicas (evitar duplicados)
    recipe_title = recipe.get("title", "")
    existing_index = None
    for i, r in enumerate(public_recipes):
        if r.get("title") == recipe_title and r.get("user_id") == user_id:
            existing_index = i
            break
    
    if existing_index is not None:
        # Actualizar receta existente
        public_recipes[existing_index] = recipe
        print(f"✅ Updated existing public recipe: {recipe_title}")
    else:
        # Agregar nueva receta pública
        public_recipes.append(recipe)
        print(f"✅ Added new public recipe: {recipe_title}")
    
    save_recipes_public(public_recipes)
    print(f"📋 Total public recipes: {len(public_recipes)}")
    
    return {
        "message": "Recipe made public successfully",
        "recipe": recipe,
        "id": existing_index if existing_index is not None else len(public_recipes) - 1
    }

@app.delete("/recipes/private/{recipe_id}")
def delete_private_recipe(recipe_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a private recipe (only if it belongs to the authenticated user)"""
    recipes = load_recipes_private()
    user_id = current_user["user_id"]
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    # Check if recipe belongs to user
    if recipes[recipe_id].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="You don't have permission to delete this recipe")
    
    deleted_recipe = recipes.pop(recipe_id)
    save_recipes_private(recipes)
    
    return {
        "message": "Private recipe deleted successfully",
        "recipe": deleted_recipe
    }

@app.delete("/recipes/public/{recipe_id}")
def delete_public_recipe(recipe_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a public recipe (only admin can delete any public recipe, users can only delete their own)"""
    recipes = load_recipes_public()
    user_id = current_user["user_id"]
    user_role = current_user.get("role", "user")
    
    if not (0 <= recipe_id < len(recipes)):
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    # Admin can delete any public recipe, users can only delete their own
    if user_role != "admin" and recipes[recipe_id].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="You don't have permission to delete this recipe. Only admins can delete all public recipes.")
    
    deleted_recipe = recipes.pop(recipe_id)
    save_recipes_public(recipes)
    
    return {
        "message": "Public recipe deleted successfully",
        "recipe": deleted_recipe
    }

@app.post("/recipes/public/{recipe_id}/make-private")
def make_recipe_private(recipe_id: int, current_user: dict = Depends(get_current_user)):
    """Remove a recipe from public while keeping it in private (only owner can do this)"""
    public_recipes = load_recipes_public()
    user_id = current_user["user_id"]
    
    # Try to find recipe by index first
    recipe_index = None
    if 0 <= recipe_id < len(public_recipes):
        if public_recipes[recipe_id].get("user_id") == user_id:
            recipe_index = recipe_id
    
    # If not found by index, search by title (for compatibility)
    if recipe_index is None:
        for i, r in enumerate(public_recipes):
            if r.get("user_id") == user_id and str(r.get("title", "")) == str(recipe_id):
                recipe_index = i
                break
    
    if recipe_index is None:
        raise HTTPException(status_code=404, detail="Recipe not found or you don't have permission")
    
    # Get the recipe
    recipe = public_recipes[recipe_index].copy()
    
    # Remove from public
    public_recipes.pop(recipe_index)
    save_recipes_public(public_recipes)
    
    # Update in private: mark as not public
    private_recipes = load_recipes_private()
    for i, r in enumerate(private_recipes):
        if (r.get("user_id") == user_id and 
            r.get("title") == recipe.get("title") and 
            r.get("is_public") == True):
            private_recipes[i]["is_public"] = False
            if "made_public_at" in private_recipes[i]:
                del private_recipes[i]["made_public_at"]
            save_recipes_private(private_recipes)
            break
    
    return {
        "message": "Recipe removed from public successfully (kept in private)",
        "recipe": recipe
    }

@app.post("/search/private")
def search_private_recipes(filters: SearchQuery, user_id: Optional[str] = "anonymous"):
    """Search private recipes for a specific user. Returns exact matches and suggested alternatives."""
    all_private = load_recipes_private()
    user_recipes = [r for r in all_private if r.get("user_id") == user_id]
    
    # Calculate match scores for all user recipes
    recipes_with_scores = []
    for recipe in user_recipes:
        match_info = calculate_match_score(recipe, filters)
        recipe_copy = recipe.copy()
        recipe_copy["_match_info"] = match_info
        recipes_with_scores.append(recipe_copy)
    
    # Separate exact matches and suggestions
    exact_matches = []
    suggestions = []
    
    for recipe in recipes_with_scores:
        match_info = recipe["_match_info"]
        
        if match_info["is_exact_match"]:
            recipe.pop("_match_info", None)
            exact_matches.append(recipe)
        elif match_info["match_score"] > 0.3:
            match_info.pop("is_exact_match", None)
            recipe["match_details"] = match_info
            recipe.pop("_match_info", None)
            suggestions.append(recipe)
    
    # Sort suggestions by match score
    suggestions.sort(key=lambda x: x.get("match_details", {}).get("match_score", 0), reverse=True)
    suggestions = suggestions[:20]
    
    return {
        "exact_matches": exact_matches,
        "exact_matches_count": len(exact_matches),
        "suggestions": suggestions,
        "suggestions_count": len(suggestions),
        "filters_applied": {
            "ingredients": filters.ingredients,
            "time_minutes": filters.time_minutes,
            "difficulty": filters.difficulty,
            "query": filters.query,
            "calories_max": filters.calories_max,
            "tags": filters.tags
        }
    }

def normalize_ingredient(ingredient: str) -> str:
    """Normalize ingredient name for comparison"""
    return ingredient.lower().strip()

def get_recipe_ingredients(recipe: dict) -> List[str]:
    """Extract ingredients list from recipe"""
    ingredients_str = recipe.get("ingredients", "")
    if isinstance(ingredients_str, str):
        return [normalize_ingredient(ing) for ing in ingredients_str.split(",")]
    return []

def check_ingredient_match(recipe_ingredients: List[str], requested_ingredients: List[str]) -> dict:
    """Check how many requested ingredients match recipe ingredients"""
    if not requested_ingredients:
        return {"matches": 0, "total": 0, "matched_ingredients": [], "match_ratio": 1.0}
    
    requested_normalized = [normalize_ingredient(ing) for ing in requested_ingredients]
    matched = []
    
    for req_ing in requested_normalized:
        for rec_ing in recipe_ingredients:
            # Check if requested ingredient is in recipe ingredient (handles partial matches)
            if req_ing in rec_ing or rec_ing in req_ing:
                matched.append(req_ing)
                break
    
    match_ratio = len(matched) / len(requested_normalized) if requested_normalized else 0
    return {
        "matches": len(matched),
        "total": len(requested_normalized),
        "matched_ingredients": matched,
        "match_ratio": match_ratio
    }

def check_time_match(recipe_time: int, requested_time: Optional[int]) -> dict:
    """Check if recipe time matches requested time"""
    if requested_time is None:
        return {"matches": True, "time_diff": 0}
    
    time_diff = recipe_time - requested_time
    matches = recipe_time <= requested_time
    
    return {
        "matches": matches,
        "time_diff": time_diff,
        "recipe_time": recipe_time,
        "requested_time": requested_time
    }

def check_difficulty_match(recipe_difficulty: str, requested_difficulty: Optional[str]) -> dict:
    """Check if recipe difficulty matches requested difficulty"""
    if requested_difficulty is None:
        return {"matches": True}
    
    recipe_diff = normalize_ingredient(recipe_difficulty)
    requested_diff = normalize_ingredient(requested_difficulty)
    
    return {
        "matches": recipe_diff == requested_diff,
        "recipe_difficulty": recipe_difficulty,
        "requested_difficulty": requested_difficulty
    }

def calculate_match_score(recipe: dict, filters: SearchQuery) -> dict:
    """Calculate how well a recipe matches the search criteria"""
    recipe_ingredients = get_recipe_ingredients(recipe)
    recipe_time = recipe.get("time_minutes", 0)
    recipe_difficulty = recipe.get("difficulty", "")
    
    # Check each criterion
    ingredient_match = check_ingredient_match(recipe_ingredients, filters.ingredients or [])
    time_match = check_time_match(recipe_time, filters.time_minutes)
    difficulty_match = check_difficulty_match(recipe_difficulty, filters.difficulty)
    
    # Check calories
    calories_match = True
    if filters.calories_max is not None:
        nutrients = recipe.get("nutrients", "")
        try:
            if isinstance(nutrients, str):
                cal = int(nutrients.split()[1])
            elif isinstance(nutrients, dict):
                cal = int(nutrients.get("calories", 0))
            else:
                cal = 0
            calories_match = cal <= filters.calories_max
        except:
            calories_match = False
    
    # Check text query
    text_match = True
    if filters.query:
        text = filters.query.lower()
        text_match = (
            text in recipe.get("title", "").lower() or
            text in recipe.get("ingredients", "").lower() or
            text in recipe.get("description", "").lower()
        )
    
    # Check tags
    tags_match = True
    if filters.tags:
        recipe_tags = recipe.get("tags", "").lower()
        tags_match = any(
            tag.lower().strip() in recipe_tags
            for tag in filters.tags
        )
    
    # Calculate if it's an exact match (all criteria met)
    is_exact_match = (
        ingredient_match["match_ratio"] >= 1.0 and  # All ingredients match
        time_match["matches"] and
        difficulty_match["matches"] and
        calories_match and
        text_match and
        tags_match
    )
    
    # Calculate match score for suggestions (0-1 scale)
    score = 0.0
    criteria_count = 0
    
    if filters.ingredients:
        score += ingredient_match["match_ratio"] * 0.4  # Ingredients are most important
        criteria_count += 1
    if filters.time_minutes is not None:
        if time_match["matches"]:
            score += 1.0 * 0.3
        else:
            # Penalize but don't exclude if slightly over
            time_penalty = max(0, 1.0 - (abs(time_match["time_diff"]) / max(filters.time_minutes, 1)) * 0.1)
            score += time_penalty * 0.3
        criteria_count += 1
    if filters.difficulty:
        score += (1.0 if difficulty_match["matches"] else 0.5) * 0.2
        criteria_count += 1
    if filters.calories_max is not None:
        score += (1.0 if calories_match else 0.0) * 0.05
        criteria_count += 1
    if filters.query:
        score += (1.0 if text_match else 0.0) * 0.05
        criteria_count += 1
    
    if criteria_count > 0:
        score = score / (0.4 + 0.3 + 0.2 + 0.05 + 0.05)  # Normalize
    
    return {
        "is_exact_match": is_exact_match,
        "match_score": score,
        "ingredient_match": ingredient_match,
        "time_match": time_match,
        "difficulty_match": difficulty_match,
        "calories_match": calories_match,
        "text_match": text_match,
        "tags_match": tags_match
    }

@app.post("/search")
def search_recipes(filters: SearchQuery, include_general: bool = True, include_public: bool = True):
    """Search recipes with filters. Returns exact matches and suggested alternatives."""
    all_results = []
    
    # Search in general recipes
    if include_general:
        all_results.extend(load_recipes_general())
    
    # Search in public recipes
    if include_public:
        all_results.extend(load_recipes_public())
    
    # Calculate match scores for all recipes
    recipes_with_scores = []
    for recipe in all_results:
        match_info = calculate_match_score(recipe, filters)
        recipe_copy = recipe.copy()
        recipe_copy["_match_info"] = match_info
        recipes_with_scores.append(recipe_copy)
    
    # Separate exact matches and suggestions
    exact_matches = []
    suggestions = []
    
    for recipe in recipes_with_scores:
        match_info = recipe["_match_info"]
        
        if match_info["is_exact_match"]:
            # Remove internal match info before returning
            recipe.pop("_match_info", None)
            exact_matches.append(recipe)
        elif match_info["match_score"] > 0.3:  # Only include suggestions with reasonable match
            # Remove internal match info but add match details for frontend
            match_info.pop("is_exact_match", None)
            recipe["match_details"] = match_info
            recipe.pop("_match_info", None)
            suggestions.append(recipe)
    
    # Sort suggestions by match score (highest first)
    suggestions.sort(key=lambda x: x.get("match_details", {}).get("match_score", 0), reverse=True)
    
    # Limit suggestions to top 20
    suggestions = suggestions[:20]
    
    return {
        "exact_matches": exact_matches,
        "exact_matches_count": len(exact_matches),
        "suggestions": suggestions,
        "suggestions_count": len(suggestions),
        "filters_applied": {
            "ingredients": filters.ingredients,
            "time_minutes": filters.time_minutes,
            "difficulty": filters.difficulty,
            "query": filters.query,
            "calories_max": filters.calories_max,
            "tags": filters.tags
        }
    }





# ==================== TRACKING & NUTRITION ENDPOINTS ====================

# Helper functions for ingredient mapping
def find_food_by_ingredient(ingredient_name: str):
    """Find food in database by ingredient name using fuzzy matching"""
    foods = load_foods()
    ingredient_lower = ingredient_name.lower().strip()
    
    # Exact match in name or variations
    for food in foods:
        if food["name"].lower() == ingredient_lower:
            return {"food": food, "confidence": 1.0, "match_type": "exact_name"}
        for variation in food.get("name_variations", []):
            if variation.lower() == ingredient_lower:
                return {"food": food, "confidence": 1.0, "match_type": "exact_variation"}
    
    # Partial match
    for food in foods:
        if ingredient_lower in food["name"].lower() or food["name"].lower() in ingredient_lower:
            return {"food": food, "confidence": 0.8, "match_type": "partial"}
        for variation in food.get("name_variations", []):
            if ingredient_lower in variation.lower() or variation.lower() in ingredient_lower:
                return {"food": food, "confidence": 0.8, "match_type": "partial_variation"}
    
    return None

def calculate_nutrition(food: dict, quantity: float, unit: str):
    """Calculate nutrition values for a given quantity of food"""
    # Convert to grams
    unit_conversions = food.get("unit_conversions", {})
    if unit in unit_conversions:
        grams = quantity * unit_conversions[unit]
    else:
        grams = quantity  # Assume grams if unit not found
    
    # Calculate nutrition per gram
    nutrition_per_100g = food.get("nutrition_per_100g", {})
    multiplier = grams / 100.0
    
    return {
        "calories": round(nutrition_per_100g.get("calories", 0) * multiplier, 1),
        "protein": round(nutrition_per_100g.get("protein", 0) * multiplier, 1),
        "carbohydrates": round(nutrition_per_100g.get("carbohydrates", 0) * multiplier, 1),
        "fat": round(nutrition_per_100g.get("fat", 0) * multiplier, 1),
        "fiber": round(nutrition_per_100g.get("fiber", 0) * multiplier, 1),
        "sugar": round(nutrition_per_100g.get("sugar", 0) * multiplier, 1),
        "sodium": round(nutrition_per_100g.get("sodium", 0) * multiplier, 1),
    }

def calculate_stats_for_period(entries: list, start_date: str, end_date: str):
    """Calculate aggregated statistics for a date range"""
    from datetime import datetime, timedelta
    
    start = datetime.fromisoformat(start_date)
    end = datetime.fromisoformat(end_date)
    days = (end - start).days + 1
    
    total_calories = sum(entry.get("total_calories", 0) for entry in entries)
    total_nutrition = {
        "protein": 0.0,
        "carbohydrates": 0.0,
        "fat": 0.0,
        "fiber": 0.0,
        "sugar": 0.0,
        "sodium": 0.0,
    }
    
    for entry in entries:
        nutrition = entry.get("total_nutrition", {})
        for key in total_nutrition:
            total_nutrition[key] += nutrition.get(key, 0.0)
    
    return {
        "total_calories": round(total_calories, 1),
        "avg_daily_calories": round(total_calories / days if days > 0 else 0, 1),
        "total_nutrition": {k: round(v, 1) for k, v in total_nutrition.items()},
        "avg_daily_nutrition": {k: round(v / days if days > 0 else 0, 1) for k, v in total_nutrition.items()},
        "days": days,
    }

# Food endpoints
@app.get("/foods")
def get_foods(search: Optional[str] = None):
    """Get all foods or search foods"""
    foods = load_foods()
    if search:
        search_lower = search.lower()
        foods = [
            food for food in foods
            if search_lower in food["name"].lower() or
            any(search_lower in var.lower() for var in food.get("name_variations", []))
        ]
    return {"foods": foods, "count": len(foods)}

@app.get("/foods/{food_id}")
def get_food(food_id: str):
    """Get specific food by ID"""
    foods = load_foods()
    food = next((f for f in foods if f.get("food_id") == food_id), None)
    if not food:
        raise HTTPException(status_code=404, detail="Food not found")
    return food

# Ingredient mapping endpoints
@app.get("/mapping/ingredient/{ingredient_name}")
def get_ingredient_mapping(ingredient_name: str):
    """Get food mapping for an ingredient"""
    # Check existing mappings
    mappings = load_ingredient_mapping()
    existing = next((m for m in mappings if m.get("ingredient_name") == ingredient_name.lower()), None)
    if existing:
        foods = load_foods()
        food = next((f for f in foods if f.get("food_id") == existing.get("food_id")), None)
        return {
            "ingredient_name": ingredient_name,
            "mapping": existing,
            "food": food,
            "auto_matched": False
        }
    
    # Try auto-matching
    match = find_food_by_ingredient(ingredient_name)
    if match:
        return {
            "ingredient_name": ingredient_name,
            "mapping": {
                "ingredient_name": ingredient_name.lower(),
                "food_id": match["food"]["food_id"],
                "confidence": match["confidence"],
                "match_type": match["match_type"]
            },
            "food": match["food"],
            "auto_matched": True
        }
    
    return {
        "ingredient_name": ingredient_name,
        "mapping": None,
        "food": None,
        "auto_matched": False,
        "suggestions": [f["name"] for f in load_foods()[:5]]  # Top 5 suggestions
    }

@app.post("/mapping/ingredient-to-food")
def create_ingredient_mapping(
    ingredient_name: str,
    food_id: str,
    default_quantity: Optional[float] = None,
    default_unit: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Create or update ingredient to food mapping"""
    foods = load_foods()
    food = next((f for f in foods if f.get("food_id") == food_id), None)
    if not food:
        raise HTTPException(status_code=404, detail="Food not found")
    
    mappings = load_ingredient_mapping()
    # Remove existing mapping if any
    mappings = [m for m in mappings if m.get("ingredient_name") != ingredient_name.lower()]
    
    # Add new mapping
    new_mapping = {
        "ingredient_name": ingredient_name.lower(),
        "food_id": food_id,
        "confidence": 1.0,
        "default_quantity": default_quantity or food.get("unit_conversions", {}).get("unidades", 100.0),
        "default_unit": default_unit or food.get("default_unit", "gramos"),
        "created_by": current_user["user_id"],
        "created_at": datetime.now().isoformat()
    }
    mappings.append(new_mapping)
    save_ingredient_mapping(mappings)
    
    return {"message": "Mapping created", "mapping": new_mapping}

# Consumption endpoints
class FoodItem(BaseModel):
    food_id: str
    quantity: float
    unit: str

@app.post("/tracking/consumption")
def add_consumption(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    meal_type: str = Query(..., description="Meal type: desayuno, comida, cena, snack"),
    foods: List[FoodItem] = Body(..., description="List of food items"),
    current_user: dict = Depends(get_current_user)
):
    """Add consumption entry"""
    print(f"📥 Recibiendo consumo: date={date}, meal_type={meal_type}, foods={len(foods)} items")
    print(f"📥 Usuario: {current_user.get('user_id')}")
    print(f"📥 Alimentos recibidos: {foods}")
    
    user_id = current_user["user_id"]
    history = load_consumption_history()
    
    if user_id not in history:
        history[user_id] = {"entries": []}
    
    foods_db = load_foods()
    total_calories = 0.0
    total_nutrition = {
        "protein": 0.0,
        "carbohydrates": 0.0,
        "fat": 0.0,
        "fiber": 0.0,
        "sugar": 0.0,
        "sodium": 0.0,
    }
    
    processed_foods = []
    for food_item in foods:
        # Convertir Pydantic model a dict si es necesario
        if hasattr(food_item, 'dict'):
            food_dict = food_item.dict()
        elif hasattr(food_item, 'model_dump'):
            food_dict = food_item.model_dump()
        else:
            food_dict = food_item if isinstance(food_item, dict) else {}
        
        food_id = food_dict.get("food_id") or getattr(food_item, "food_id", None)
        if not food_id:
            print(f"⚠️ Alimento sin food_id: {food_dict}")
            continue
        
        print(f"🔍 Buscando alimento con food_id: {food_id}")
        
        # Si es una receta (food_id empieza con "recipe_"), usar calorías directamente
        if food_id.startswith("recipe_"):
            # Es una receta, usar las calorías proporcionadas
            recipe_calories = food_dict.get("calories") or 0.0
            recipe_name = food_dict.get("name") or "Receta"
            quantity = food_dict.get("quantity") or 1.0
            
            if recipe_calories > 0:
                processed_foods.append({
                    "food_id": food_id,
                    "name": recipe_name,
                    "quantity": quantity,
                    "unit": "ración",
                    "calories": recipe_calories * quantity,
                    "nutrition": {
                        "calories": recipe_calories * quantity,
                        "protein": 0.0,
                        "carbohydrates": 0.0,
                        "fat": 0.0,
                        "fiber": 0.0,
                        "sugar": 0.0,
                        "sodium": 0.0,
                    }
                })
                total_calories += recipe_calories * quantity
                print(f"✅ Receta añadida: {recipe_name} ({recipe_calories * quantity} kcal)")
            continue
        
        # Buscar el alimento en la base de datos
        food = next((f for f in foods_db if f.get("food_id") == food_id), None)
        if not food:
            print(f"❌ No se encontró alimento con food_id: {food_id} en la base de datos")
            print(f"   Alimento buscado: {food_dict}")
            # Intentar buscar por nombre como fallback
            food_name = food_dict.get("name")
            if food_name:
                food = next((f for f in foods_db if f.get("name", "").lower() == food_name.lower()), None)
                if food:
                    print(f"✅ Encontrado por nombre: {food_name} -> {food.get('food_id')}")
                    food_id = food.get("food_id")  # Actualizar food_id con el encontrado
                else:
                    # Intentar buscar en name_variations
                    for f in foods_db:
                        variations = f.get("name_variations", [])
                        if any(v.lower() == food_name.lower() for v in variations):
                            food = f
                            food_id = f.get("food_id")
                            print(f"✅ Encontrado por variación: {food_name} -> {food_id}")
                            break
                    if not food:
                        print(f"❌ No se encontró alimento con nombre: {food_name}")
                        continue
            else:
                continue
        
        quantity = food_dict.get("quantity", 0) or getattr(food_item, "quantity", 0)
        unit = food_dict.get("unit", "gramos") or getattr(food_item, "unit", "gramos")
        
        print(f"✅ Procesando alimento: {food.get('name')} - {quantity} {unit}")
        nutrition = calculate_nutrition(food, quantity, unit)
        
        processed_foods.append({
            "food_id": food["food_id"],
            "name": food["name"],
            "quantity": quantity,
            "unit": unit,
            "calories": nutrition["calories"],
            "nutrition": nutrition
        })
        
        total_calories += nutrition["calories"]
        for key in total_nutrition:
            total_nutrition[key] += nutrition[key]
    
    if not processed_foods:
        print("❌ No se pudo procesar ningún alimento")
        raise HTTPException(
            status_code=400,
            detail="No se pudo procesar ningún alimento. Verifica que los food_id sean correctos."
        )
    
    entry = {
        "entry_id": f"entry_{datetime.now().timestamp()}",
        "date": date,
        "meal_type": meal_type,
        "foods": processed_foods,
        "total_calories": round(total_calories, 1),
        "total_nutrition": {k: round(v, 1) for k, v in total_nutrition.items()},
        "created_at": datetime.now().isoformat()
    }
    
    history[user_id]["entries"].append(entry)
    save_consumption_history(history)
    
    print(f"✅ Consumo guardado correctamente: {len(processed_foods)} alimentos, {round(total_calories, 1)} calorías")
    
    # Update stats
    update_nutrition_stats(user_id, date)
    
    return {"message": "Consumption added", "entry": entry}

@app.get("/tracking/consumption")
def get_consumption(
    date: Optional[str] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get consumption entries"""
    user_id = current_user["user_id"]
    history = load_consumption_history()
    
    if user_id not in history:
        return {"entries": [], "count": 0}
    
    entries = history[user_id].get("entries", [])
    
    if date:
        entries = [e for e in entries if e.get("date") == date]
    elif start and end:
        entries = [e for e in entries if start <= e.get("date") <= end]
    
    return {"entries": entries, "count": len(entries)}

# Meal plan endpoints
@app.post("/tracking/meal-plan")
def create_meal_plan(
    date: str,
    meal_type: str,
    ingredients: List[dict],
    current_user: dict = Depends(get_current_user)
):
    """Create meal plan from ingredients"""
    user_id = current_user["user_id"]
    plans = load_meal_plans()
    
    if user_id not in plans:
        plans[user_id] = {"plans": []}
    
    foods_db = load_foods()
    mappings = load_ingredient_mapping()
    total_calories = 0.0
    estimated_foods = []
    
    for ingredient in ingredients:
        ing_name = ingredient.get("name", "").lower()
        quantity = ingredient.get("quantity", 0)
        unit = ingredient.get("unit", "unidades")
        
        # Find mapping
        mapping = next((m for m in mappings if m.get("ingredient_name") == ing_name), None)
        if not mapping:
            # Try auto-match
            match = find_food_by_ingredient(ing_name)
            if match:
                food = match["food"]
            else:
                continue
        else:
            food = next((f for f in foods_db if f.get("food_id") == mapping.get("food_id")), None)
            if not food:
                continue
        
        nutrition = calculate_nutrition(food, quantity, unit)
        estimated_foods.append({
            "food_id": food["food_id"],
            "name": food["name"],
            "quantity": quantity,
            "unit": unit,
            "estimated_calories": nutrition["calories"],
            "estimated_nutrition": nutrition
        })
        total_calories += nutrition["calories"]
    
    plan = {
        "plan_id": f"plan_{datetime.now().timestamp()}",
        "date": date,
        "meal_type": meal_type,
        "ingredients_used": ingredients,
        "estimated_foods": estimated_foods,
        "total_estimated_calories": round(total_calories, 1),
        "created_at": datetime.now().isoformat()
    }
    
    plans[user_id]["plans"].append(plan)
    save_meal_plans(plans)
    
    return {"message": "Meal plan created", "plan": plan}

@app.get("/tracking/meal-plan")
def get_meal_plan(
    date: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get meal plans"""
    user_id = current_user["user_id"]
    plans = load_meal_plans()
    
    if user_id not in plans:
        return {"plans": [], "count": 0}
    
    user_plans = plans[user_id].get("plans", [])
    if date:
        user_plans = [p for p in user_plans if p.get("date") == date]
    
    return {"plans": user_plans, "count": len(user_plans)}

# Statistics endpoints
def update_nutrition_stats(user_id: str, date: str):
    """Update nutrition statistics for a user"""
    history = load_consumption_history()
    stats = load_nutrition_stats()
    
    if user_id not in history:
        return
    
    entries = [e for e in history[user_id].get("entries", []) if e.get("date") == date]
    daily_total = sum(e.get("total_calories", 0) for e in entries)
    daily_nutrition = {
        "protein": sum(e.get("total_nutrition", {}).get("protein", 0) for e in entries),
        "carbohydrates": sum(e.get("total_nutrition", {}).get("carbohydrates", 0) for e in entries),
        "fat": sum(e.get("total_nutrition", {}).get("fat", 0) for e in entries),
    }
    
    if user_id not in stats:
        stats[user_id] = {
            "daily_stats": {},
            "weekly_stats": {},
            "monthly_stats": {},
            "yearly_stats": {}
        }
    
    stats[user_id]["daily_stats"][date] = {
        "consumed_calories": round(daily_total, 1),
        "nutrition": {k: round(v, 1) for k, v in daily_nutrition.items()},
        "meals_count": len(entries)
    }
    
    # Update weekly, monthly, yearly stats
    from datetime import datetime, timedelta
    date_obj = datetime.fromisoformat(date)
    week = f"{date_obj.year}-W{date_obj.isocalendar()[1]:02d}"
    month = f"{date_obj.year}-{date_obj.month:02d}"
    year = str(date_obj.year)
    
    # Weekly stats
    week_start = date_obj - timedelta(days=date_obj.weekday())
    week_end = week_start + timedelta(days=6)
    week_entries = [
        e for e in history[user_id].get("entries", [])
        if week_start.isoformat()[:10] <= e.get("date") <= week_end.isoformat()[:10]
    ]
    week_stats = calculate_stats_for_period(week_entries, week_start.isoformat()[:10], week_end.isoformat()[:10])
    stats[user_id]["weekly_stats"][week] = week_stats
    
    # Monthly stats
    month_start = date_obj.replace(day=1)
    if month_start.month == 12:
        month_end = month_start.replace(year=month_start.year + 1, month=1) - timedelta(days=1)
    else:
        month_end = month_start.replace(month=month_start.month + 1) - timedelta(days=1)
    month_entries = [
        e for e in history[user_id].get("entries", [])
        if month_start.isoformat()[:10] <= e.get("date") <= month_end.isoformat()[:10]
    ]
    month_stats = calculate_stats_for_period(month_entries, month_start.isoformat()[:10], month_end.isoformat()[:10])
    stats[user_id]["monthly_stats"][month] = month_stats
    
    # Yearly stats
    year_start = date_obj.replace(month=1, day=1)
    year_end = date_obj.replace(month=12, day=31)
    year_entries = [
        e for e in history[user_id].get("entries", [])
        if year_start.isoformat()[:10] <= e.get("date") <= year_end.isoformat()[:10]
    ]
    year_stats = calculate_stats_for_period(year_entries, year_start.isoformat()[:10], year_end.isoformat()[:10])
    stats[user_id]["yearly_stats"][year] = year_stats
    
    stats[user_id]["last_updated"] = datetime.now().isoformat()
    save_nutrition_stats(stats)

@app.get("/tracking/stats/daily")
def get_daily_stats(
    date: str,
    current_user: dict = Depends(get_current_user)
):
    """Get daily nutrition statistics"""
    user_id = current_user["user_id"]
    stats = load_nutrition_stats()
    
    if user_id not in stats:
        return {"date": date, "consumed_calories": 0, "nutrition": {}, "meals_count": 0}
    
    daily = stats[user_id].get("daily_stats", {}).get(date, {})
    goals = load_user_goals().get(user_id, {}).get("daily_goals", {})
    goal_calories = goals.get("calories", 2000)
    consumed = daily.get("consumed_calories", 0)
    
    return {
        "date": date,
        "consumed_calories": consumed,
        "planned_calories": daily.get("planned_calories", 0),
        "goal_calories": goal_calories,
        "remaining_calories": max(0, goal_calories - consumed),
        "nutrition": daily.get("nutrition", {}),
        "meals_count": daily.get("meals_count", 0)
    }

@app.get("/tracking/stats/weekly")
def get_weekly_stats(
    week: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get weekly nutrition statistics"""
    user_id = current_user["user_id"]
    stats = load_nutrition_stats()
    
    if user_id not in stats:
        return {"week": week, "avg_daily_calories": 0, "total_calories": 0}
    
    if not week:
        from datetime import datetime
        today = datetime.now()
        week = f"{today.year}-W{today.isocalendar()[1]:02d}"
    
    weekly = stats[user_id].get("weekly_stats", {}).get(week, {})
    return weekly

@app.get("/tracking/stats/monthly")
def get_monthly_stats(
    month: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get monthly nutrition statistics"""
    user_id = current_user["user_id"]
    stats = load_nutrition_stats()
    
    if user_id not in stats:
        return {"month": month, "avg_daily_calories": 0, "total_calories": 0}
    
    if not month:
        from datetime import datetime
        today = datetime.now()
        month = f"{today.year}-{today.month:02d}"
    
    monthly = stats[user_id].get("monthly_stats", {}).get(month, {})
    return monthly

@app.get("/tracking/stats/yearly")
def get_yearly_stats(
    year: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get yearly nutrition statistics"""
    user_id = current_user["user_id"]
    stats = load_nutrition_stats()
    
    if user_id not in stats:
        return {"year": year, "avg_daily_calories": 0, "total_calories": 0}
    
    if not year:
        from datetime import datetime
        year = str(datetime.now().year)
    
    yearly = stats[user_id].get("yearly_stats", {}).get(year, {})
    return yearly

# User goals endpoints
@app.get("/tracking/goals")
def get_user_goals(current_user: dict = Depends(get_current_user)):
    """Get user goals"""
    user_id = current_user["user_id"]
    goals = load_user_goals()
    
    if user_id not in goals:
        # Return default goals
        return {
            "user_id": user_id,
            "daily_goals": {
                "calories": 2000.0,
                "protein": 150.0,
                "carbohydrates": 250.0,
                "fat": 65.0,
                "fiber": 25.0
            }
        }
    
    return goals[user_id]

@app.put("/tracking/goals")
def update_user_goals(
    daily_goals: dict,
    current_user: dict = Depends(get_current_user)
):
    """Update user goals"""
    user_id = current_user["user_id"]
    goals = load_user_goals()
    
    if user_id not in goals:
        goals[user_id] = {}
    
    goals[user_id]["daily_goals"] = daily_goals
    goals[user_id]["updated_at"] = datetime.now().isoformat()
    save_user_goals(goals)
    
    return {"message": "Goals updated", "goals": goals[user_id]}

# Firebase sync endpoint
@app.post("/sync/update-files")
def sync_update_files(files_data: dict):
    """
    Recibe archivos JSON descargados desde Firebase y los guarda localmente.
    Este endpoint permite sincronizar los datos desde Firebase al backend.
    """
    results = {}
    
    # Mapeo de nombres de archivos a funciones de guardado
    file_handlers = {
        "recipes.json": (load_recipes_general, save_recipes_general),
        "foods.json": (load_foods, save_foods),
        "users.json": (load_users, save_users),
        "profiles.json": (load_profiles, save_profiles),
        "consumption_history.json": (load_consumption_history, save_consumption_history),
        "meal_plans.json": (load_meal_plans, save_meal_plans),
        "nutrition_stats.json": (load_nutrition_stats, save_nutrition_stats),
        "user_goals.json": (load_user_goals, save_user_goals),
        "ingredient_food_mapping.json": (load_ingredient_food_mapping, save_ingredient_food_mapping),
        "recipes_public.json": (load_recipes_public, save_recipes_public),
        "recipes_private.json": (load_recipes_private, save_recipes_private),
        "followers.json": (load_followers, save_followers),
    }
    
    for file_name, data in files_data.items():
        try:
            if file_name in file_handlers:
                load_func, save_func = file_handlers[file_name]
                
                # Si el archivo espera una lista pero recibimos un dict, convertir
                if file_name in ["recipes.json", "recipes_public.json", "recipes_private.json"]:
                    if isinstance(data, dict):
                        # Si es un dict, intentar extraer la lista
                        if "recipes" in data:
                            data = data["recipes"]
                        elif isinstance(data, list):
                            pass  # Ya es una lista
                        else:
                            # Convertir dict a lista si es necesario
                            data = [data] if data else []
                    
                    save_func(data)
                    results[file_name] = {"status": "success", "message": f"Saved {len(data) if isinstance(data, list) else 1} items"}
                else:
                    # Para otros archivos, guardar directamente
                    save_func(data)
                    if isinstance(data, dict):
                        count = len(data)
                    elif isinstance(data, list):
                        count = len(data)
                    else:
                        count = 1
                    results[file_name] = {"status": "success", "message": f"Saved {count} items"}
            else:
                results[file_name] = {"status": "skipped", "message": "File not in handler list"}
        except Exception as e:
            results[file_name] = {"status": "error", "message": str(e)}
    
    successful = sum(1 for r in results.values() if r.get("status") == "success")
    total = len(results)
    
    return {
        "message": f"Synchronized {successful}/{total} files",
        "results": results
    }