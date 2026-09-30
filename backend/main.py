import os
import json
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from passlib.context import CryptContext
from google import genai
from dotenv import load_dotenv

import database
import models
from database import engine, get_db

load_dotenv()

# --- Automatic SQL Table & Column Patching ---
def sync_database_schema():
    schema_sql = """
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR NOT NULL,
        email VARCHAR UNIQUE NOT NULL,
        password VARCHAR NOT NULL,
        dob VARCHAR DEFAULT '',
        height_cm FLOAT DEFAULT 0.0,
        weight_kg FLOAT DEFAULT 0.0,
        age INTEGER DEFAULT 0,
        gender VARCHAR DEFAULT '',
        goal VARCHAR DEFAULT '',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    
    ALTER TABLE users ADD COLUMN IF NOT EXISTS dob VARCHAR DEFAULT '';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS height_cm FLOAT DEFAULT 0.0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS weight_kg FLOAT DEFAULT 0.0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER DEFAULT 0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR DEFAULT '';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS goal VARCHAR DEFAULT '';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

    CREATE TABLE IF NOT EXISTS workouts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        workout_type VARCHAR DEFAULT 'Strength',
        muscle VARCHAR,
        exercise VARCHAR,
        sets_count INTEGER DEFAULT 0,
        max_weight FLOAT DEFAULT 0.0,
        duration_mins INTEGER DEFAULT 0,
        speed_kmh FLOAT DEFAULT 0.0,
        incline FLOAT DEFAULT 0.0,
        calories_burned INTEGER DEFAULT 0,
        estimated_fat_loss_g FLOAT DEFAULT 0.0,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS meals (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        name VARCHAR,
        quantity VARCHAR DEFAULT '',
        calories INTEGER DEFAULT 0,
        protein FLOAT DEFAULT 0.0,
        carbs FLOAT DEFAULT 0.0,
        fat FLOAT DEFAULT 0.0,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
    CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
    """
    try:
        with engine.begin() as conn:
            conn.execute(text(schema_sql))
        print("Schema sync complete: Verified tables and applied migrations.")
    except Exception as e:
        print(f"Database schema sync warning: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    sync_database_schema()
    try:
        models.Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"ORM initialization error: {e}")
    yield

app = FastAPI(title="FitOak Backend", lifespan=lifespan)

# --- CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Password Hashing Setup ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Gemini AI Client Setup ---
gemini_api_key = os.getenv("GEMINI_API_KEY")
gemini_client = genai.Client(api_key=gemini_api_key) if gemini_api_key else None

# --- Pydantic Data Models ---
class UserRegister(BaseModel):
    name: str
    email: str
    password: str
    dob: str = ""
    height_cm: float = 0.0
    weight_kg: float = 0.0
    age: int = 0
    gender: str = ""
    goal: str = ""

class UserLogin(BaseModel):
    email: str
    password: str

class NutritionRequest(BaseModel):
    dish_name: str
    quantity: str

class WorkoutCreate(BaseModel):
    user_id: int
    workout_type: str = "Strength"
    muscle: str = ""
    exercise: str = ""
    sets_count: int = 0
    max_weight: float = 0.0
    duration_mins: int = 0
    speed_kmh: float = 0.0
    incline: float = 0.0

class MealCreate(BaseModel):
    user_id: int
    name: str
    quantity: str
    calories: int
    protein: float
    carbs: float
    fat: float


# --- API ENDPOINTS ---

@app.get("/")
def read_root():
    return {"status": "online", "message": "FitOak Backend is running successfully!"}

@app.post("/api/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    sync_database_schema()
    existing_user = db.query(models.User).filter(models.User.email == user.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered. Please login instead."
        )
    
    hashed_password = pwd_context.hash(user.password)
    
    db_user = models.User(
        name=user.name,
        email=user.email,
        password=hashed_password,
        dob=user.dob,
        height_cm=user.height_cm,
        weight_kg=user.weight_kg,
        age=user.age,
        gender=user.gender,
        goal=user.goal
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return {
        "status": "success",
        "message": "User registered successfully!",
        "user": {
            "id": db_user.id,
            "name": db_user.name,
            "email": db_user.email,
            "dob": db_user.dob,
            "height_cm": db_user.height_cm,
            "weight_kg": db_user.weight_kg
        }
    }

@app.post("/api/login")
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    sync_database_schema()
    user = db.query(models.User).filter(models.User.email == credentials.email).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found. Please register first."
        )
    
    if not pwd_context.verify(credentials.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password. Please try again."
        )
    
    return {
        "status": "success",
        "message": "Login successful",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "dob": user.dob,
            "height_cm": user.height_cm,
            "weight_kg": user.weight_kg,
            "age": user.age,
            "gender": user.gender,
            "goal": user.goal
        }
    }

@app.get("/api/user/{user_id}")
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "dob": user.dob,
        "height_cm": user.height_cm,
        "weight_kg": user.weight_kg,
        "age": user.age,
        "gender": user.gender,
        "goal": user.goal
    }

# --- Gemini AI Automated Nutrition Analyzer Endpoint ---
@app.post("/api/ai/nutrition")
def analyze_nutrition(request: NutritionRequest):
    if not gemini_client:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY environment variable is missing on server."
        )
    
    prompt = f"""
    Calculate precise nutrition for dish: "{request.dish_name}", quantity/portion: "{request.quantity}".
    Return ONLY a valid JSON object matching this structure:
    {{
      "meal_name": "{request.dish_name}",
      "calories": 250,
      "protein_g": 15.0,
      "carbs_g": 30.0,
      "fat_g": 8.0,
      "health_score": "8/10",
      "tips": "Good balance of macronutrients."
    }}
    """
    
    try:
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
        )
        raw_text = response.text.strip().replace("```json", "").replace("```", "").strip()
        nutrition_data = json.loads(raw_text)
        return {"status": "success", "data": nutrition_data}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Gemini AI processing failed: {str(e)}"
        )

# --- Workouts & Meals Logging API ---
@app.post("/api/workouts")
def create_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    calories = 0
    fat_loss = 0.0
    
    if workout.workout_type == "Cardio":
        # Estimate cardio calories & fat loss
        calories = int(workout.duration_mins * (workout.speed_kmh * 0.8 + 3.0))
        fat_loss = round((calories / 7700.0) * 1000.0, 2)  # Grams of fat
    else:
        calories = workout.sets_count * 15

    db_workout = models.Workout(
        user_id=workout.user_id,
        workout_type=workout.workout_type,
        muscle=workout.muscle,
        exercise=workout.exercise,
        sets_count=workout.sets_count,
        max_weight=workout.max_weight,
        duration_mins=workout.duration_mins,
        speed_kmh=workout.speed_kmh,
        incline=workout.incline,
        calories_burned=calories,
        estimated_fat_loss_g=fat_loss
    )
    db.add(db_workout)
    db.commit()
    db.refresh(db_workout)
    return {"status": "success", "workout": db_workout}

@app.get("/api/workouts/{user_id}")
def get_user_workouts(user_id: int, db: Session = Depends(get_db)):
    workouts = db.query(models.Workout).filter(models.Workout.user_id == user_id).all()
    return {"status": "success", "workouts": workouts}

@app.post("/api/meals")
def create_meal(meal: MealCreate, db: Session = Depends(get_db)):
    db_meal = models.Meal(
        user_id=meal.user_id,
        name=meal.name,
        quantity=meal.quantity,
        calories=meal.calories,
        protein=meal.protein,
        carbs=meal.carbs,
        fat=meal.fat
    )
    db.add(db_meal)
    db.commit()
    db.refresh(db_meal)
    return {"status": "success", "meal": db_meal}

@app.get("/api/meals/{user_id}")
def get_user_meals(user_id: int, db: Session = Depends(get_db)):
    meals = db.query(models.Meal).filter(models.Meal.user_id == user_id).all()
    return {"status": "success", "meals": meals}