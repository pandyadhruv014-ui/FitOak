import os
import json
import re
import random
import traceback
import resend
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, status, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from passlib.context import CryptContext
import google.generativeai as genai
from dotenv import load_dotenv
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import database
import models
from database import engine, get_db

load_dotenv()
app = FastAPI()

# In-Memory OTP Store (Email -> {"otp": "123456"})
otp_store = {}

# --- Automatic SQL Table & Column Patching ---
def sync_database_schema():
    schema_sql = """
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        dob VARCHAR(50) DEFAULT '',
        height_cm FLOAT DEFAULT 0.0,
        weight_kg FLOAT DEFAULT 0.0,
        age INTEGER DEFAULT 0,
        gender VARCHAR(50) DEFAULT '',
        goal VARCHAR(255) DEFAULT '',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS workouts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        workout_type VARCHAR(50) DEFAULT 'Strength',
        muscle VARCHAR(100),
        exercise VARCHAR(255),
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
        name VARCHAR(255),
        quantity VARCHAR(100) DEFAULT '',
        calories INTEGER DEFAULT 0,
        protein FLOAT DEFAULT 0.0,
        carbs FLOAT DEFAULT 0.0,
        fat FLOAT DEFAULT 0.0,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Automatically patch missing columns on existing tables
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS user_id INTEGER;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS workout_type VARCHAR(50) DEFAULT 'Strength';
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS muscle VARCHAR(100);
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS exercise VARCHAR(255);
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS sets_count INTEGER DEFAULT 0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS max_weight FLOAT DEFAULT 0.0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS duration_mins INTEGER DEFAULT 0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS speed_kmh FLOAT DEFAULT 0.0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS incline FLOAT DEFAULT 0.0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS calories_burned INTEGER DEFAULT 0;
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS estimated_fat_loss_g FLOAT DEFAULT 0.0;

    ALTER TABLE meals ADD COLUMN IF NOT EXISTS user_id INTEGER;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS name VARCHAR(255);
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS quantity VARCHAR(100) DEFAULT '';
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS calories INTEGER DEFAULT 0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS protein FLOAT DEFAULT 0.0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS carbs FLOAT DEFAULT 0.0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS fat FLOAT DEFAULT 0.0;

    CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
    CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
    CREATE INDEX IF NOT EXISTS ix_meals_user_id ON meals (user_id);
    CREATE INDEX IF NOT EXISTS ix_workouts_user_id ON workouts (user_id);
    """
    try:
        with engine.begin() as conn:
            conn.execute(text(schema_sql))
        print("✅ Schema sync complete: All tables and columns verified/patched.")
    except Exception as e:
        print(f"❌ Database schema sync error: {e}")
        print(traceback.format_exc())

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting FitOak Backend...")
    db_url = os.getenv("DATABASE_URL", "NOT_SET")
    print(f"📊 DATABASE_URL configured: {db_url[:50]}..." if db_url != "NOT_SET" else "❌ DATABASE_URL NOT SET!")
    
    sync_database_schema()
    
    try:
        models.Base.metadata.create_all(bind=engine)
        print("✅ SQLAlchemy models initialized")
    except Exception as e:
        print(f"❌ ORM initialization error: {e}")
        print(traceback.format_exc())
    
    yield
    print("🛑 Shutting down FitOak Backend...")

app = FastAPI(title="FitOak Backend", lifespan=lifespan)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"❌ Unhandled exception: {exc}")
    print(traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "detail": str(exc),
            "type": type(exc).__name__,
            "path": str(request.url)
        }
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    print(f"✅ Gemini AI configured successfully")
else:
    print("⚠️ GEMINI_API_KEY not found in environment")

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

class ForgotPasswordRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

class NutritionRequest(BaseModel):
    dish_name: str
    quantity: str = "1 serving"

class AIChatRequest(BaseModel):
    prompt: str

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

# --- HELPER: ASYNCHRONOUS SMTP EMAIL DISPATCH ---
def send_smtp_email_async(to_email: str, otp_code: str):
    sender_email = os.getenv("SENDER_EMAIL")
    sender_password = os.getenv("SENDER_PASSWORD")
    
    # 1. Print verification status directly to Render logs
    if not sender_email or not sender_password:
        print(f"❌ SMTP SKIPPED: Missing environment variables on Render! (SENDER_EMAIL: {bool(sender_email)}, SENDER_PASSWORD: {bool(sender_password)})")
        return

    try:
        print(f"🔄 Attempting to send email from {sender_email} to {to_email} via smtp.gmail.com:587...")
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "FitOak Password Reset Code"
        msg["From"] = f"FitOak Security <{sender_email}>"
        msg["To"] = to_email

        html_content = f"""
        <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #1e1e1e; color: #ffffff; border-radius: 10px;">
            <h2 style="color: #ff5722;">FitOak Password Reset</h2>
            <p>Your 6-digit verification code is:</p>
            <h1 style="color: #ff5722; letter-spacing: 4px;">{otp_code}</h1>
            <p style="color: #888888;">If you did not request this code, please ignore this email.</p>
        </div>
        """
        msg.attach(MIMEText(html_content, "html"))

        # Port 587 with STARTTLS for cloud compatibility
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, to_email, msg.as_string())
            
        print(f"✉️ SUCCESS: Password reset email sent directly to {to_email}")
    except Exception as mail_err:
        print(f"❌ SMTP ERROR: {mail_err}")

@app.get("/")
def read_root():
    return {"status": "online", "message": "FitOak Backend is running successfully!"}

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "FitOak FastAPI Engine"}

@app.get("/debug/db-status")
def debug_db_status():
    try:
        db_url = os.getenv("DATABASE_URL", "NOT_SET")
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();"))
            pg_version = result.fetchone()[0]
            tables_result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public';
            """))
            tables = [row[0] for row in tables_result.fetchall()]
            users_count = conn.execute(text("SELECT COUNT(*) FROM users;")).fetchone()[0]
            meals_count = conn.execute(text("SELECT COUNT(*) FROM meals;")).fetchone()[0]
            workouts_count = conn.execute(text("SELECT COUNT(*) FROM workouts;")).fetchone()[0]
            
            return {
                "status": "healthy",
                "database_url_set": db_url != "NOT_SET",
                "database_url_prefix": db_url[:30] if db_url != "NOT_SET" else "NOT_SET",
                "postgres_version": pg_version,
                "tables": tables,
                "record_counts": {
                    "users": users_count,
                    "meals": meals_count,
                    "workouts": workouts_count
                }
            }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "traceback": traceback.format_exc()
        }

# --- AUTHENTICATION ENDPOINTS ---
@app.post("/api/register")
@app.post("/api/auth/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    try:
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
            "userId": db_user.id,
            "id": db_user.id,
            "token": f"fitoak_token_{db_user.id}",
            "user": {
                "id": db_user.id,
                "name": db_user.name,
                "email": db_user.email,
                "dob": db_user.dob,
                "height_cm": db_user.height_cm,
                "weight_kg": db_user.weight_kg
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Registration error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/api/login")
@app.post("/api/auth/login")
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    try:
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
            "userId": user.id,
            "id": user.id,
            "token": f"fitoak_token_{user.id}",
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
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Login error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Login failed: {str(e)}")

# --- FORGOT & RESET PASSWORD ENDPOINTS ---
@app.post("/api/auth/forgot-password")
@app.post("/api/forgot-password")
def request_password_reset(
    request: ForgotPasswordRequest, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    try:
        user = db.query(models.User).filter(models.User.email == request.email).first()
        if not user:
            raise HTTPException(
                status_code=404,
                detail="No account registered with this email address."
            )
        
        # Generate 6-digit OTP
        otp_code = str(random.randint(100000, 999999))
        otp_store[request.email] = otp_code
        
        # Schedule asynchronous email dispatch so FastAPI returns a immediate response to Flutter
        background_tasks.add_task(send_smtp_email_async, request.email, otp_code)

        return {
            "status": "success",
            "message": "Reset code generated and email dispatch scheduled.",
            "otp_preview": otp_code
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Forgot password error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate reset code: {str(e)}")

@app.post("/api/auth/reset-password")
@app.post("/api/reset-password")
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    try:
        stored_otp = otp_store.get(request.email)
        if not stored_otp or stored_otp != request.otp.strip():
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired OTP verification code."
            )
        
        user = db.query(models.User).filter(models.User.email == request.email).first()
        if not user:
            raise HTTPException(status_code=404, detail="User account not found.")
        
        # Update and hash new password
        user.password = pwd_context.hash(request.new_password)
        db.commit()
        
        # Clear used OTP
        otp_store.pop(request.email, None)
        
        return {
            "status": "success",
            "message": "Password updated successfully! Please log in with your new password."
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Reset password error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to reset password: {str(e)}")

@app.get("/api/user/{user_id}")
@app.get("/api/auth/me")
def get_user_profile(user_id: int = 1, db: Session = Depends(get_db)):
    try:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return {
            "id": user.id,
            "userId": user.id,
            "name": user.name,
            "email": user.email,
            "dob": user.dob,
            "height_cm": user.height_cm,
            "weight_kg": user.weight_kg,
            "age": user.age,
            "gender": user.gender,
            "goal": user.goal
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Get user error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to get user: {str(e)}")

class DeleteAccountRequest(BaseModel):
    user_id: int
    password: str

@app.delete("/api/user/delete")
def delete_user_account(request: DeleteAccountRequest, db: Session = Depends(get_db)):
    try:
        sync_database_schema()

        user = db.query(models.User).filter(models.User.id == request.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if not pwd_context.verify(request.password, user.password):
            raise HTTPException(
                status_code=401,
                detail="Incorrect password. Account deletion cancelled."
            )

        db.query(models.Meal).filter(models.Meal.user_id == request.user_id).delete()
        db.query(models.Workout).filter(models.Workout.user_id == request.user_id).delete()
        db.delete(user)
        db.commit()

        return {
            "status": "success",
            "message": "Account and all associated data deleted successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Delete account error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to delete account: {str(e)}")

# --- GEMINI AI NUTRITION & CHAT ENDPOINTS ---
@app.post("/api/ai/nutrition")
def analyze_nutrition(request: NutritionRequest):
    dish = request.dish_name.strip()
    qty = request.quantity.strip() if request.quantity else "1 portion"

    if not dish:
        raise HTTPException(status_code=400, detail="Dish name cannot be empty.")

    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY environment variable is missing on server.")

    prompt = f"""
    You are an accurate nutritional database engine. Calculate real-time estimated macros for:
    Food: "{dish}", Portion: "{qty}".

    Provide accurate, genuine numbers for this exact portion.
    Return ONLY a raw JSON object string without markdown code blocks or extra text:
    {{
      "meal_name": "{dish} ({qty})",
      "calories": 250,
      "protein_g": 20.0,
      "carbs_g": 15.0,
      "fat_g": 8.0
    }}
    """

    candidate_models = ['gemini-3.8-flash', 'gemini-3.5-flash-lite']
    last_error = None

    for model_name in candidate_models:
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            raw_text = response.text.strip()
            json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group(0))
                return {"status": "success", "data": data}
        except Exception as e:
            print(f"⚠️ Model {model_name} failed: {e}")
            last_error = str(e)
            continue

    raise HTTPException(
        status_code=500,
        detail=f"FitOak-AI Analysis failed on all models. Details: {last_error}"
    )

@app.post("/api/ai/chat")
def ai_chat_handler(request: AIChatRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY environment variable is missing on server.")

    candidate_models = ['gemini-3.8-flash', 'gemini-3.5-flash-lite']
    last_error = None

    for model_name in candidate_models:
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(request.prompt)
            return {"response": response.text}
        except Exception as e:
            print(f"⚠️ Model {model_name} failed: {e}")
            last_error = str(e)
            continue

    raise HTTPException(
        status_code=500,
        detail=f"FitOak-AI chat failed on all models. Details: {last_error}"
    )

# --- POSTGRESQL DATABASE SYNC ENDPOINTS ---
@app.post("/api/workouts")
def create_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    try:
        calories = 0
        fat_loss = 0.0
        
        if workout.workout_type == "Cardio":
            calories = int(workout.duration_mins * (workout.speed_kmh * 0.8 + 3.0))
            fat_loss = round((calories / 7700.0) * 1000.0, 2)
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
    except Exception as e:
        print(f"❌ Create workout error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to create workout: {str(e)}")

@app.get("/api/workouts/{user_id}")
def get_user_workouts(user_id: int, db: Session = Depends(get_db)):
    try:
        print(f"📊 Fetching workouts for user_id: {user_id}")
        workouts = db.query(models.Workout).filter(models.Workout.user_id == user_id).all()
        print(f"✅ Found {len(workouts)} workouts")
        return {"status": "success", "workouts": workouts}
    except Exception as e:
        print(f"❌ Get workouts error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to fetch workouts: {str(e)}")

@app.post("/api/meals")
def create_meal(meal: MealCreate, db: Session = Depends(get_db)):
    try:
        print(f"📥 Creating meal for user_id: {meal.user_id}, name: {meal.name}")
        
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
        
        print(f"✅ Meal created successfully with id: {db_meal.id}")
        return {"status": "success", "meal": db_meal}
    except Exception as e:
        print(f"❌ Create meal error: {e}")
        print(traceback.format_exc())
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create meal: {str(e)}")

@app.get("/api/meals/{user_id}")
def get_user_meals(user_id: int, db: Session = Depends(get_db)):
    try:
        print(f"📊 Fetching meals for user_id: {user_id}")
        meals = db.query(models.Meal).filter(models.Meal.user_id == user_id).all()
        print(f"✅ Found {len(meals)} meals")
        return {"status": "success", "meals": meals}
    except Exception as e:
        print(f"❌ Get meals error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to fetch meals: {str(e)}")

@app.delete("/api/meals/{meal_id}")
def delete_meal(meal_id: int, db: Session = Depends(get_db)):
    meal = db.query(models.Meal).filter(models.Meal.id == meal_id).first()
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")
    db.delete(meal)
    db.commit()
    return {"status": "success", "message": "Meal deleted successfully"}

@app.delete("/api/workouts/{workout_id}")
def delete_workout(workout_id: int, db: Session = Depends(get_db)):
    workout = db.query(models.Workout).filter(models.Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    db.delete(workout)
    db.commit()
    return {"status": "success", "message": "Workout deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)