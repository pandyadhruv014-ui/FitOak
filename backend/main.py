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

# --- Force SQL Table Creation ---
def create_tables_directly():
    create_users_table_sql = """
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR NOT NULL,
        email VARCHAR UNIQUE NOT NULL,
        password VARCHAR NOT NULL,
        age INTEGER DEFAULT 0,
        gender VARCHAR DEFAULT '',
        goal VARCHAR DEFAULT '',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
    CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
    """
    try:
        with engine.begin() as conn:
            conn.execute(text(create_users_table_sql))
        print("Explicit SQL: Created 'users' table successfully.")
    except Exception as e:
        print(f"Explicit SQL execution error: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Execute direct SQL table creation on boot
    create_tables_directly()
    try:
        models.Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"ORM metadata initialization error: {e}")
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

# --- Security & Hashing ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Gemini AI Client Setup ---
gemini_api_key = os.getenv("GEMINI_API_KEY")
gemini_client = genai.Client(api_key=gemini_api_key) if gemini_api_key else None

# --- Pydantic Data Models ---
class UserRegister(BaseModel):
    name: str
    email: str
    password: str
    age: int = 0
    gender: str = ""
    goal: str = ""

class UserLogin(BaseModel):
    email: str
    password: str

class NutritionRequest(BaseModel):
    meal_description: str


# --- API ENDPOINTS ---

@app.get("/")
def read_root():
    return {"status": "online", "message": "FitOak Backend is running successfully!"}

@app.post("/api/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    # Safety fallback to verify table exists right before query
    create_tables_directly()
    
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
        "user_id": db_user.id
    }

@app.post("/api/login")
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    create_tables_directly()
    
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
            "email": user.email
        }
    }

@app.post("/api/ai/nutrition")
def analyze_nutrition(request: NutritionRequest):
    if not gemini_client:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY environment variable is missing on server."
        )
    
    prompt = f"""
    Analyze the following meal and calculate its nutritional breakdown: "{request.meal_description}".
    Return ONLY a valid JSON object without markdown formatting blocks, matching this structure:
    {{
      "meal_name": "Short summary name of meal",
      "calories": 0,
      "protein_g": 0.0,
      "carbs_g": 0.0,
      "fat_g": 0.0,
      "health_score": "1-10 string rating",
      "tips": "Brief actionable nutrition advice"
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