import os
import json
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from passlib.context import CryptContext
from google import genai
from dotenv import load_dotenv
import models
import database
from database import engine, get_db

# Create tables automatically if they don't exist
models.Base.metadata.create_all(bind=database.engine)

# Load environment variables
load_dotenv()

app = FastAPI(title="FitOak Backend")

# --- CORS Setup ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Database Setup (Neon PostgreSQL / Local SQLite Fallback) ---
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./fitoak.db")

if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace("postgres://", "postgresql://", 1)

if "sqlite" in SQLALCHEMY_DATABASE_URL:
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    age = Column(Integer, default=0)
    gender = Column(String, default="")
    goal = Column(String, default="")

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Security / Password Hashing ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Gemini AI Client Setup ---
gemini_api_key = os.getenv("GEMINI_API_KEY")
gemini_client = genai.Client(api_key=gemini_api_key) if gemini_api_key else None

# --- Pydantic Models ---
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
    return {"message": "FitOak Backend is running successfully!"}

@app.post("/api/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    existing_user = db.query(UserDB).filter(UserDB.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered. Please login.")
    
    hashed_password = pwd_context.hash(user.password)
    
    db_user = UserDB(
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
    return {"status": "success", "message": "User registered successfully!", "user_id": db_user.id}

@app.post("/api/login")
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(UserDB).filter(UserDB.email == credentials.email).first()
    
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
            "name": user.name,
            "email": user.email
        }
    }

# --- Gemini AI Nutrition Analyzer Endpoint ---
@app.post("/api/ai/nutrition")
def analyze_nutrition(request: NutritionRequest):
    if not gemini_client:
        raise HTTPException(
            status_code=500, 
            detail="GEMINI_API_KEY environment variable is not configured."
        )
    
    prompt = f"""
    Analyze the following meal and calculate its nutritional breakdown: "{request.meal_description}".
    Return ONLY a valid JSON object without markdown or formatting block, matching this structure:
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
        
        # Clean response string and parse JSON
        raw_text = response.text.strip().replace("```json", "").replace("```", "").strip()
        nutrition_data = json.loads(raw_text)
        
        return {"status": "success", "data": nutrition_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini AI processing failed: {str(e)}")