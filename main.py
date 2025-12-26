from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional
import json

app = FastAPI()

# Load recipes
with open("recipes.json", "r", encoding="utf-8") as f:
    recipes = json.load(f)

@app.get("/")
def read_root():
    return {"message": "Hello from Nutritrack backend!"}

# Request model
class SearchQuery(BaseModel):
    query: Optional[str] = ""
    difficulty: Optional[str] = None
    tags: Optional[List[str]] = None
    calories_max: Optional[int] = None

@app.post("/search")
def search_recipes(filters: SearchQuery):
    results = recipes

    # Text match in title or ingredients
    if filters.query:
        text = filters.query.lower()
        results = [
            r for r in results
            if text in r.get("title", "").lower()
            or text in r.get("ingredients", "").lower()
        ]

    # Difficulty filter
    if filters.difficulty:
        results = [
            r for r in results
            if r.get("difficulty", "").lower() == filters.difficulty.lower()
        ]

    # Tags filter (split string if tags are comma-separated)
    if filters.tags:
        results = [
            r for r in results
            if any(
                tag.lower().strip() in r.get("tags", "").lower()
                for tag in filters.tags
            )
        ]

    # Calories filter — parse from string like "calories 300"
    if filters.calories_max is not None:
        filtered = []
        for r in results:
            nutrients = r.get("nutrients", "")
            try:
                if isinstance(nutrients, str):
                    cal = int(nutrients.split()[1])
                elif isinstance(nutrients, dict):
                    cal = int(nutrients.get("calories", 0))
                else:
                    cal = 0
                if cal <= filters.calories_max:
                    filtered.append(r)
            except:
                pass
        results = filtered

    return results







# 1st select venv :Ctr + Shift + P -> Select interpreter python 3.12 (venv)
# iniciar sesion: 
#   escribir en terminal: 
#   uvicorn main:app --reload --host 0.0.0.0 --port 8000

#   escribir en nuevo terminal: 
#   cd C:\ngrok
#   .\ngrok config add-authtoken 2wJgQewhszdLGwUxzOVOqQrV0iB_Mgn4xr7t3G4YNLfit6ya
#   .\ngrok http 8000