# Configurar Generación de Recetas con IA

## 🤖 Funcionalidad

La app ahora puede generar recetas usando IA (OpenAI GPT-3.5-turbo). El usuario puede:
- Seleccionar tipo de comida (Desayuno, Comida, Cena)
- Opcionalmente usar sus ingredientes guardados
- Generar 5 recetas que se muestran como tarjetas (igual que en el apartado de recetas)
- Hacer clic en cada receta para ver el detalle completo

## 🔑 Configuración de OpenAI API

### Opción 1: OpenAI (Recomendado - Barato)

1. Ve a [OpenAI Platform](https://platform.openai.com/)
2. Crea una cuenta o inicia sesión
3. Ve a **API Keys** → **Create new secret key**
4. Copia la clave (empieza con `sk-...`)
5. **Costo**: GPT-3.5-turbo cuesta ~$0.50 por 1 millón de tokens
   - Generar 5 recetas ≈ 2000-3000 tokens ≈ $0.001-0.002 por generación

### Opción 2: Groq (Gratis con límites)

Groq ofrece acceso gratuito pero con límites de rate. Para usarlo:

1. Ve a [Groq Console](https://console.groq.com/)
2. Crea una cuenta
3. Obtén tu API key
4. Modifica `main.py` para usar Groq en lugar de OpenAI

## ⚙️ Configurar en Render

1. Ve a **Render Dashboard** → Tu servicio → **Settings** → **Environment Variables**
2. Añade:
   ```
   OPENAI_API_KEY=sk-tu-clave-aqui
   ```
3. Haz clic en **Save Changes**
4. Haz deploy del último commit

## 📱 Uso en la App

1. Ve a **Alimentación** → **Mis ingredientes**
2. Haz clic en **"Generar Recetas con IA"**
3. Selecciona el tipo de comida (Desayuno, Comida, Cena)
4. Haz clic en **"Generar 5 Recetas"**
5. Las recetas aparecerán como tarjetas
6. Toca una receta para ver el detalle completo

## 🔧 Endpoint del Backend

**POST** `/ai/generate-recipes`

**Request:**
```json
{
  "meal_type": "Comida",  // "Desayuno", "Comida", o "Cena"
  "ingredients": ["pollo", "cebolla", "tomate"],  // Opcional
  "num_recipes": 5
}
```

**Response:**
```json
{
  "message": "Recetas generadas exitosamente para Comida",
  "recipes": [
    {
      "title": "Nombre de la receta",
      "description": "Descripción breve",
      "ingredients": "ingrediente1,ingrediente2,ingrediente3",
      "time_minutes": 30,
      "difficulty": "Fácil",
      "tags": "tag1,tag2",
      "nutrients": "calories 450,protein 25.0g,carbs 50.0g,fat 15.0g",
      "servings": 4,
      "calories_per_serving": 450,
      "image_url": "...",
      "is_ai_generated": true,
      "meal_type": "Comida"
    },
    ...
  ],
  "meal_type": "Comida",
  "ai_generated": true
}
```

## 💰 Costos Estimados

- **OpenAI GPT-3.5-turbo**: 
  - Input: ~$0.50 por 1M tokens
  - Output: ~$1.50 por 1M tokens
  - **Costo por generación de 5 recetas**: ~$0.001-0.002 (menos de 1 centavo)

- **Groq** (si se implementa):
  - Gratis con límites de rate
  - Perfecto para desarrollo y uso moderado

## 🐛 Troubleshooting

### Error: "OpenAI API key not configured"

**Solución**: Añade `OPENAI_API_KEY` en Render environment variables

### Error: "Error parseando respuesta de IA"

**Causa**: La IA devolvió un formato JSON inválido
**Solución**: El endpoint intenta limpiar la respuesta automáticamente. Si persiste, revisa los logs.

### Las recetas no aparecen

**Verifica**:
1. Que `OPENAI_API_KEY` esté configurado correctamente
2. Que tengas créditos en tu cuenta de OpenAI
3. Los logs del backend para ver errores específicos

## 📝 Notas

- Las recetas generadas tienen `is_ai_generated: true`
- Se pueden guardar como favoritas o como recetas privadas
- El formato es compatible con el formato de `recipes.json`
- Las recetas incluyen: título, descripción, ingredientes, tiempo, dificultad, raciones, calorías por ración, nutrientes
