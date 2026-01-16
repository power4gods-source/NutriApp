#!/usr/bin/env python3
"""Script para crear el usuario de prueba mn@gmail.com con contraseña mnmnmn"""
import json
from passlib.context import CryptContext
from datetime import datetime

# Configurar bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Generar hash de la contraseña
password = "mnmnmn"
hashed_password = pwd_context.hash(password)

# Crear usuario
user_id = "mn_at_gmail_com"
user_data = {
    "email": "mn@gmail.com",
    "hashed_password": hashed_password,
    "username": "mn",
    "role": "user",
    "created_at": datetime.now().isoformat()
}

# Leer usuarios existentes
try:
    with open("users.json", "r", encoding="utf-8") as f:
        users = json.load(f)
except FileNotFoundError:
    users = {}

# Añadir o actualizar usuario
users[user_id] = user_data

# Guardar usuarios
with open("users.json", "w", encoding="utf-8") as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"✅ Usuario creado exitosamente:")
print(f"   Email: {user_data['email']}")
print(f"   Username: {user_data['username']}")
print(f"   Password: {password}")
print(f"   Role: {user_data['role']}")
print(f"   Hash: {hashed_password}")
