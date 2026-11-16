import os
import json
import re
import time
import random
import traceback
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, status, Request, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from passlib.context import CryptContext
import google.generativeai as genai
from google.api_core import exceptions as google_exceptions
from dotenv import load_dotenv
import urllib.request
import firebase_admin
from firebase_admin import credentials, messaging

import database
import models
from database import engine, get_db

load_dotenv()

# --- Initialize Firebase Admin SDK from Render Env Var ---
if not firebase_admin._apps:
    firebase_creds_raw = os.getenv("FIREBASE_CREDENTIALS_JSON", "").strip()
    if firebase_creds_raw:
        try:
            cred_dict = json.loads(firebase_creds_raw)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized for FCM push notifications.")
        except Exception as fb_err:
            print(f"❌ Firebase Admin SDK init error: {fb_err}")

otp_store = {}
IST = timezone(timedelta(hours=5, minutes=30))

def get_ist_today_str() -> str:
    return datetime.now(IST).strftime("%Y-%m-%d")

def get_ist_now() -> datetime:
    return datetime.now(IST).replace(tzinfo=None)

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

    CREATE TABLE IF NOT EXISTS user_fcm_tokens (
        user_id INTEGER PRIMARY KEY,
        fcm_token TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
        logged_by VARCHAR(255) DEFAULT '',
        log_date VARCHAR(20) DEFAULT '',
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
        log_date VARCHAR(20) DEFAULT '',
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS water_logs (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        log_date VARCHAR(20) NOT NULL,
        glasses INTEGER DEFAULT 0,
        ml_total INTEGER DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, log_date)
    );

    CREATE TABLE IF NOT EXISTS gym_groups (
        id SERIAL PRIMARY KEY,
        group_name VARCHAR(120) NOT NULL,
        entry_pass VARCHAR(32) UNIQUE NOT NULL,
        created_by INTEGER NOT NULL,
        gym_reminder_hour INTEGER DEFAULT NULL,
        gym_reminder_minute INTEGER DEFAULT NULL,
        reminder_updated_by VARCHAR(120) DEFAULT '',
        reminder_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS gym_group_members (
        id SERIAL PRIMARY KEY,
        group_id INTEGER REFERENCES gym_groups(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL,
        user_name VARCHAR(255) NOT NULL,
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(group_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS group_messages (
        id SERIAL PRIMARY KEY,
        group_id INTEGER NOT NULL REFERENCES gym_groups(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL,
        user_name VARCHAR(120) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Patch existing tables safely
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
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS logged_by VARCHAR(255) DEFAULT '';
    ALTER TABLE workouts ADD COLUMN IF NOT EXISTS log_date VARCHAR(20) DEFAULT '';

    ALTER TABLE meals ADD COLUMN IF NOT EXISTS user_id INTEGER;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS name VARCHAR(255);
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS quantity VARCHAR(100) DEFAULT '';
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS calories INTEGER DEFAULT 0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS protein FLOAT DEFAULT 0.0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS carbs FLOAT DEFAULT 0.0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS fat FLOAT DEFAULT 0.0;
    ALTER TABLE meals ADD COLUMN IF NOT EXISTS log_date VARCHAR(20) DEFAULT '';

    -- Backfill log_date from timestamp for legacy rows so historical rows don't show up as today
    UPDATE meals
    SET log_date = TO_CHAR((timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD')
    WHERE (log_date IS NULL OR log_date = '') AND timestamp IS NOT NULL;

    UPDATE workouts
    SET log_date = TO_CHAR((timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD')
    WHERE (log_date IS NULL OR log_date = '') AND timestamp IS NOT NULL;

    CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
    CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
    CREATE INDEX IF NOT EXISTS ix_meals_user_date ON meals (user_id, log_date);
    CREATE INDEX IF NOT EXISTS ix_workouts_user_date ON workouts (user_id, log_date);
    CREATE INDEX IF NOT EXISTS ix_water_user_date ON water_logs (user_id, log_date);
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
    sync_database_schema()
    try:
        models.Base.metadata.create_all(bind=engine)
        print("✅ SQLAlchemy models initialized")
    except Exception as e:
        print(f"❌ ORM initialization error: {e}")
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

CANDIDATE_MODELS = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
    'gemini-pro-latest',
]

def generate_with_resilience(prompt: str, force_json: bool = False) -> str:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY environment variable is missing on server.")

    generation_config = genai.GenerationConfig(
        temperature=0.2 if force_json else 0.7,
        response_mime_type="application/json" if force_json else "text/plain",
    )

    last_error = None
    for model_name in CANDIDATE_MODELS:
        try:
            model = genai.GenerativeModel(
                model_name=model_name,
                generation_config=generation_config
            )
            response = model.generate_content(prompt, request_options={"timeout": 15})
            if response and response.text:
                return response.text.strip()
        except google_exceptions.ResourceExhausted as rate_err:
            last_error = str(rate_err)
            time.sleep(0.5)
            continue
        except Exception as e:
            last_error = str(e)
            continue

    raise HTTPException(status_code=503, detail=f"FitOak-AI failed on all fallback models. Details: {last_error}")

# --- Pydantic Models ---
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
    log_date: Optional[str] = None
    buddy_user_ids: List[int] = []
    logged_by_name: str = ""

class MealCreate(BaseModel):
    user_id: int
    name: str
    quantity: str
    calories: int
    protein: float
    carbs: float
    fat: float
    log_date: Optional[str] = None

class WaterLogUpdate(BaseModel):
    user_id: int
    glasses: int
    ml_total: int = 0
    log_date: Optional[str] = None

class GroupCreateRequest(BaseModel):
    user_id: int
    user_name: str
    group_name: str
    entry_pass: str

class GroupJoinRequest(BaseModel):
    user_id: int
    user_name: str
    entry_pass: str

class GroupReminderUpdate(BaseModel):
    user_id: int
    user_name: str
    hour: int
    minute: int

class DeleteAccountRequest(BaseModel):
    user_id: int
    password: str

class GroupMessageCreate(BaseModel):
    user_id: int
    user_name: str
    message: str

class FcmTokenPayload(BaseModel):
    user_id: int
    fcm_token: str

# --- Email Helper ---
def send_smtp_email_async(to_email: str, otp_code: str):
    api_key = os.getenv("BREVO_API_KEY")
    sender_email = os.getenv("SENDER_EMAIL", "fitoak.recovery@gmail.com")
    if not api_key:
        return
    url = "https://api.brevo.com/v3/smtp/email"
    headers = {"accept": "application/json", "api-key": api_key, "content-type": "application/json"}
    html_content = f"""
    <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #1e1e1e; color: #ffffff; border-radius: 10px;">
        <h2 style="color: #ff5722;">FitOak Password Reset</h2>
        <p>Your 6-digit verification code is:</p>
        <h1 style="color: #ff5722; letter-spacing: 4px;">{otp_code}</h1>
    </div>
    """
    payload = {
        "sender": {"name": "FitOak Security", "email": sender_email},
        "to": [{"email": to_email}],
        "subject": "FitOak Password Reset Code",
        "htmlContent": html_content
    }
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=15):
            pass
    except Exception as mail_err:
        print(f"❌ HTTPS API ERROR: {mail_err}")

@app.get("/")
def read_root():
    return {"status": "online", "message": "FitOak Backend is running successfully!"}

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "FitOak FastAPI Engine", "ist_date": get_ist_today_str()}

# --- FCM TOKEN & PUSH NOTIFICATION HELPERS ---
@app.post("/api/users/fcm-token")
def register_fcm_token(payload: FcmTokenPayload):
    token = payload.fcm_token.strip()
    if payload.user_id <= 0 or not token:
        raise HTTPException(status_code=400, detail="Invalid user_id or FCM token.")

    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS user_fcm_tokens (
                user_id INTEGER PRIMARY KEY,
                fcm_token TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(
            text("""
                INSERT INTO user_fcm_tokens (user_id, fcm_token, updated_at)
                VALUES (:uid, :tok, :ts)
                ON CONFLICT (user_id)
                DO UPDATE SET fcm_token = EXCLUDED.fcm_token, updated_at = EXCLUDED.updated_at
            """),
            {"uid": payload.user_id, "tok": token, "ts": get_ist_now()},
        )
    return {"status": "registered"}

def _send_group_push_notification(
    conn,
    group_id: int,
    sender_id: int,
    sender_name: str,
    message_text: str,
):
    if not firebase_admin._apps:
        return

    group_row = conn.execute(
        text("SELECT group_name FROM gym_groups WHERE id = :gid"),
        {"gid": group_id},
    ).fetchone()
    group_name = group_row[0] if group_row else "Gym Squad"

    token_rows = conn.execute(
        text("""
            SELECT DISTINCT t.fcm_token
            FROM gym_group_members m
            JOIN user_fcm_tokens t ON m.user_id = t.user_id
            WHERE m.group_id = :gid
              AND m.user_id != :sender_id
              AND t.fcm_token IS NOT NULL
              AND t.fcm_token != ''
        """),
        {"gid": group_id, "sender_id": sender_id},
    ).fetchall()

    tokens = [r[0] for r in token_rows]
    if not tokens:
        return

    multicast_msg = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=f"{sender_name} • {group_name}",
            body=message_text,
        ),
        data={
            "type": "group_message",
            "group_id": str(group_id),
            "sender_id": str(sender_id),
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="gym_squad_chat_channel",
                sound="default",
            ),
        ),
        tokens=tokens,
    )

    try:
        messaging.send_each_for_multicast(multicast_msg)
    except Exception as fcm_err:
        print(f"⚠️ FCM push failed: {fcm_err}")

# --- AUTHENTICATION ENDPOINTS ---
@app.post("/api/register")
@app.post("/api/auth/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered. Please login instead.")
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

@app.post("/api/login")
@app.post("/api/auth/login")
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == credentials.email).first()
    if not user or not pwd_context.verify(credentials.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid email or password.")
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

@app.post("/api/auth/forgot-password")
@app.post("/api/forgot-password")
def request_password_reset(request: ForgotPasswordRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account registered with this email address.")
    otp_code = str(random.randint(100000, 999999))
    otp_store[request.email] = otp_code
    background_tasks.add_task(send_smtp_email_async, request.email, otp_code)
    return {"status": "success", "message": "A 6-digit verification code has been sent to your email address."}

@app.post("/api/auth/reset-password")
@app.post("/api/reset-password")
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    stored_otp = otp_store.get(request.email)
    if not stored_otp or stored_otp != request.otp.strip():
        raise HTTPException(status_code=400, detail="Invalid or expired OTP verification code.")
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User account not found.")
    user.password = pwd_context.hash(request.new_password)
    db.commit()
    otp_store.pop(request.email, None)
    return {"status": "success", "message": "Password updated successfully!"}

@app.delete("/api/user/delete")
def delete_user_account(request: DeleteAccountRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not pwd_context.verify(request.password, user.password):
        raise HTTPException(status_code=401, detail="Incorrect password. Account deletion cancelled.")
    db.query(models.Meal).filter(models.Meal.user_id == request.user_id).delete()
    db.query(models.Workout).filter(models.Workout.user_id == request.user_id).delete()
    db.execute(text("DELETE FROM water_logs WHERE user_id = :uid"), {"uid": request.user_id})
    db.execute(text("DELETE FROM gym_group_members WHERE user_id = :uid"), {"uid": request.user_id})
    db.execute(text("DELETE FROM user_fcm_tokens WHERE user_id = :uid"), {"uid": request.user_id})
    db.delete(user)
    db.commit()
    return {"status": "success", "message": "Account and all associated data deleted successfully"}

# --- GEMINI AI ENDPOINTS ---
@app.post("/api/ai/nutrition")
def analyze_nutrition(request: NutritionRequest):
    dish = request.dish_name.strip()
    qty = request.quantity.strip() if request.quantity else "1 portion"
    if not dish:
        raise HTTPException(status_code=400, detail="Dish name cannot be empty.")

    prompt = f"""
    You are an accurate nutritional database engine. Calculate real-time estimated macros for:
    Food: "{dish}", Portion: "{qty}".
    Return ONLY a raw JSON object string without markdown code blocks or extra text:
    {{
      "meal_name": "{dish} ({qty})",
      "calories": 250,
      "protein_g": 20.0,
      "carbs_g": 15.0,
      "fat_g": 8.0
    }}
    """
    raw_text = generate_with_resilience(prompt, force_json=True)
    try:
        cleaned = re.sub(r'```json\s*|\s*```', '', raw_text).strip()
        json_match = re.search(r'\{.*\}', cleaned, re.DOTALL)
        data = json.loads(json_match.group(0))
        sanitized_data = {
            "meal_name": str(data.get("meal_name", f"{dish} ({qty})")),
            "calories": int(float(data.get("calories", 0))),
            "protein_g": round(float(data.get("protein_g", 0.0)), 1),
            "carbs_g": round(float(data.get("carbs_g", 0.0)), 1),
            "fat_g": round(float(data.get("fat_g", 0.0)), 1),
        }
        return {"status": "success", "data": sanitized_data}
    except Exception:
        raise HTTPException(status_code=500, detail="FitOak-AI returned an unexpected format. Please try again.")

@app.post("/api/ai/chat")
def ai_chat_handler(request: AIChatRequest):
    if not request.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty.")
    reply = generate_with_resilience(request.prompt, force_json=False)
    return {"status": "success", "response": reply}

# --- DATE-FILTERED MEALS ENDPOINTS ---
@app.post("/api/meals")
def create_meal(meal: MealCreate, db: Session = Depends(get_db)):
    target_date = meal.log_date if meal.log_date else get_ist_today_str()
    try:
        result = db.execute(
            text("""
                INSERT INTO meals (user_id, name, quantity, calories, protein, carbs, fat, log_date, timestamp)
                VALUES (:user_id, :name, :quantity, :calories, :protein, :carbs, :fat, :log_date, :ts)
                RETURNING id, user_id, name, quantity, calories, protein, carbs, fat, log_date
            """),
            {
                "user_id": meal.user_id,
                "name": meal.name,
                "quantity": meal.quantity,
                "calories": meal.calories,
                "protein": meal.protein,
                "carbs": meal.carbs,
                "fat": meal.fat,
                "log_date": target_date,
                "ts": get_ist_now(),
            },
        )
        row = result.fetchone()
        db.commit()
        return {"status": "success", "meal": dict(row._mapping)}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create meal: {str(e)}")

@app.get("/api/meals/{user_id}")
def get_user_meals(user_id: int, date: Optional[str] = Query(default=None), db: Session = Depends(get_db)):
    target_date = date if date else get_ist_today_str()
    try:
        rows = db.execute(
            text("""
                SELECT id, user_id, name, quantity, calories, protein, carbs, fat, log_date
                FROM meals
                WHERE user_id = :uid AND log_date = :target_date
                ORDER BY id ASC
            """),
            {"uid": user_id, "target_date": target_date},
        ).fetchall()
        return {"status": "success", "date": target_date, "meals": [dict(r._mapping) for r in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch meals: {str(e)}")

@app.get("/api/meals/weekly/{user_id}")
def get_weekly_meals_summary(user_id: int, db: Session = Depends(get_db)):
    today = datetime.now(IST).date()
    start_of_week = today - timedelta(days=today.weekday())  # Monday
    dates = [(start_of_week + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]

    rows = db.execute(
        text("""
            SELECT log_date, COALESCE(SUM(calories), 0) AS total_calories
            FROM meals
            WHERE user_id = :uid AND log_date = ANY(:dates)
            GROUP BY log_date
        """),
        {"uid": user_id, "dates": dates},
    ).fetchall()
    totals_map = {r.log_date: int(r.total_calories) for r in rows}
    return {
        "status": "success",
        "days": [{"date": d, "calories": totals_map.get(d, 0)} for d in dates],
    }

@app.delete("/api/meals/{meal_id}")
def delete_meal(meal_id: int, db: Session = Depends(get_db)):
    db.execute(text("DELETE FROM meals WHERE id = :mid"), {"mid": meal_id})
    db.commit()
    return {"status": "success", "message": "Meal deleted successfully"}

# --- WORKOUTS + CO-LOGGING FOR GYM BUDDIES ---
@app.post("/api/workouts")
def create_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    target_date = workout.log_date if workout.log_date else get_ist_today_str()
    try:
        if workout.workout_type == "Cardio":
            calories = int(workout.duration_mins * (workout.speed_kmh * 0.8 + 3.0))
            fat_loss = round((calories / 7700.0) * 1000.0, 2)
        else:
            calories = workout.sets_count * 15
            fat_loss = 0.0

        now_ist = get_ist_now()
        res = db.execute(
            text("""
                INSERT INTO workouts (
                    user_id, workout_type, muscle, exercise, sets_count, max_weight,
                    duration_mins, speed_kmh, incline, calories_burned, estimated_fat_loss_g,
                    logged_by, log_date, timestamp
                )
                VALUES (
                    :user_id, :workout_type, :muscle, :exercise, :sets_count, :max_weight,
                    :duration_mins, :speed_kmh, :incline, :calories_burned, :estimated_fat_loss_g,
                    '', :log_date, :ts
                )
                RETURNING *
            """),
            {
                "user_id": workout.user_id,
                "workout_type": workout.workout_type,
                "muscle": workout.muscle,
                "exercise": workout.exercise,
                "sets_count": workout.sets_count,
                "max_weight": workout.max_weight,
                "duration_mins": workout.duration_mins,
                "speed_kmh": workout.speed_kmh,
                "incline": workout.incline,
                "calories_burned": calories,
                "estimated_fat_loss_g": fat_loss,
                "log_date": target_date,
                "ts": now_ist,
            },
        )
        created_row = dict(res.fetchone()._mapping)

        unique_buddies = {bid for bid in workout.buddy_user_ids if bid > 0 and bid != workout.user_id}
        logger_label = workout.logged_by_name.strip() or f"Buddy #{workout.user_id}"
        for buddy_id in unique_buddies:
            db.execute(
                text("""
                    INSERT INTO workouts (
                        user_id, workout_type, muscle, exercise, sets_count, max_weight,
                        duration_mins, speed_kmh, incline, calories_burned, estimated_fat_loss_g,
                        logged_by, log_date, timestamp
                    )
                    VALUES (
                        :user_id, :workout_type, :muscle, :exercise, :sets_count, :max_weight,
                        :duration_mins, :speed_kmh, :incline, :calories_burned, :estimated_fat_loss_g,
                        :logged_by, :log_date, :ts
                    )
                """),
                {
                    "user_id": buddy_id,
                    "workout_type": workout.workout_type,
                    "muscle": workout.muscle,
                    "exercise": workout.exercise,
                    "sets_count": workout.sets_count,
                    "max_weight": workout.max_weight,
                    "duration_mins": workout.duration_mins,
                    "speed_kmh": workout.speed_kmh,
                    "incline": workout.incline,
                    "calories_burned": calories,
                    "estimated_fat_loss_g": fat_loss,
                    "logged_by": logger_label,
                    "log_date": target_date,
                    "ts": now_ist,
                },
            )

        db.commit()
        return {
            "status": "success",
            "workout": created_row,
            "shared_with_count": len(unique_buddies),
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create workout: {str(e)}")

@app.get("/api/workouts/{user_id}")
def get_user_workouts(user_id: int, date: Optional[str] = Query(default=None), db: Session = Depends(get_db)):
    target_date = date if date else get_ist_today_str()
    try:
        rows = db.execute(
            text("""
                SELECT *
                FROM workouts
                WHERE user_id = :uid AND log_date = :target_date
                ORDER BY id ASC
            """),
            {"uid": user_id, "target_date": target_date},
        ).fetchall()
        return {"status": "success", "date": target_date, "workouts": [dict(r._mapping) for r in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch workouts: {str(e)}")

@app.delete("/api/workouts/{workout_id}")
def delete_workout(workout_id: int, db: Session = Depends(get_db)):
    db.execute(text("DELETE FROM workouts WHERE id = :wid"), {"wid": workout_id})
    db.commit()
    return {"status": "success", "message": "Workout deleted successfully"}

# --- WATER WEEKLY TRACKING ENDPOINTS ---
@app.post("/api/water")
def upsert_water_log(payload: WaterLogUpdate, db: Session = Depends(get_db)):
    target_date = payload.log_date if payload.log_date else get_ist_today_str()
    ml_val = payload.ml_total if payload.ml_total > 0 else payload.glasses * 250
    try:
        db.execute(
            text("""
                INSERT INTO water_logs (user_id, log_date, glasses, ml_total, updated_at)
                VALUES (:uid, :log_date, :glasses, :ml_total, :ts)
                ON CONFLICT (user_id, log_date)
                DO UPDATE SET glasses = EXCLUDED.glasses, ml_total = EXCLUDED.ml_total, updated_at = EXCLUDED.updated_at
            """),
            {
                "uid": payload.user_id,
                "log_date": target_date,
                "glasses": payload.glasses,
                "ml_total": ml_val,
                "ts": get_ist_now(),
            },
        )
        db.commit()
        return {"status": "success", "date": target_date, "glasses": payload.glasses}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to sync water log: {str(e)}")

@app.get("/api/water/weekly/{user_id}")
def get_weekly_water(user_id: int, db: Session = Depends(get_db)):
    today = datetime.now(IST).date()
    start_of_week = today - timedelta(days=today.weekday())  # Monday
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    dates = [(start_of_week + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]

    rows = db.execute(
        text("""
            SELECT log_date, glasses, ml_total
            FROM water_logs
            WHERE user_id = :uid AND log_date = ANY(:dates)
        """),
        {"uid": user_id, "dates": dates},
    ).fetchall()

    water_map = {r.log_date: {"glasses": r.glasses, "ml_total": r.ml_total} for r in rows}
    today_str = today.strftime("%Y-%m-%d")

    weekly_list = []
    for i, d in enumerate(dates):
        entry = water_map.get(d, {"glasses": 0, "ml_total": 0})
        weekly_list.append({
            "date": d,
            "day": day_names[i],
            "is_today": d == today_str,
            "glasses": entry["glasses"],
            "ml_total": entry["ml_total"],
        })

    return {"status": "success", "weekly": weekly_list}

# --- GYM BUDDY GROUPS ENDPOINTS ---
@app.post("/api/groups/create")
def create_gym_group(req: GroupCreateRequest, db: Session = Depends(get_db)):
    clean_pass = req.entry_pass.strip().upper()
    if len(clean_pass) < 4:
        raise HTTPException(status_code=400, detail="Entry pass must be at least 4 characters.")

    existing = db.execute(
        text("SELECT id FROM gym_groups WHERE entry_pass = :pass"),
        {"pass": clean_pass},
    ).fetchone()
    if existing:
        raise HTTPException(status_code=400, detail="This entry pass is already taken. Choose another pass.")

    try:
        res = db.execute(
            text("""
                INSERT INTO gym_groups (group_name, entry_pass, created_by)
                VALUES (:name, :pass, :uid)
                RETURNING id, group_name, entry_pass, created_by, gym_reminder_hour, gym_reminder_minute, reminder_updated_by, reminder_updated_at
            """),
            {"name": req.group_name.strip(), "pass": clean_pass, "uid": req.user_id},
        )
        group = dict(res.fetchone()._mapping)

        db.execute(
            text("""
                INSERT INTO gym_group_members (group_id, user_id, user_name)
                VALUES (:gid, :uid, :uname)
                ON CONFLICT (group_id, user_id) DO NOTHING
            """),
            {"gid": group["id"], "uid": req.user_id, "uname": req.user_name.strip()},
        )
        db.commit()
        return {"status": "success", "group": _build_group_payload(db, group["id"])}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create group: {str(e)}")

@app.post("/api/groups/join")
def join_gym_group(req: GroupJoinRequest, db: Session = Depends(get_db)):
    clean_pass = req.entry_pass.strip().upper()
    row = db.execute(
        text("SELECT id FROM gym_groups WHERE entry_pass = :pass"),
        {"pass": clean_pass},
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Invalid entry pass. No gym group found.")

    group_id = row.id
    try:
        db.execute(
            text("""
                INSERT INTO gym_group_members (group_id, user_id, user_name)
                VALUES (:gid, :uid, :uname)
                ON CONFLICT (group_id, user_id) DO UPDATE SET user_name = EXCLUDED.user_name
            """),
            {"gid": group_id, "uid": req.user_id, "uname": req.user_name.strip()},
        )
        db.commit()
        return {"status": "success", "group": _build_group_payload(db, group_id)}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to join group: {str(e)}")

@app.get("/api/groups/my/{user_id}")
def get_my_gym_group(user_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT group_id FROM gym_group_members
            WHERE user_id = :uid
            ORDER BY joined_at DESC
            LIMIT 1
        """),
        {"uid": user_id},
    ).fetchone()

    if not row:
        return {"status": "success", "group": None}

    return {"status": "success", "group": _build_group_payload(db, row.group_id)}

@app.put("/api/groups/{group_id}/reminder")
def update_group_gym_reminder(group_id: int, req: GroupReminderUpdate, db: Session = Depends(get_db)):
    now_ist = get_ist_now()
    try:
        res = db.execute(
            text("""
                UPDATE gym_groups
                SET gym_reminder_hour = :h,
                    gym_reminder_minute = :m,
                    reminder_updated_by = :uname,
                    reminder_updated_at = :ts
                WHERE id = :gid
                RETURNING id
            """),
            {
                "h": req.hour,
                "m": req.minute,
                "uname": req.user_name.strip(),
                "ts": now_ist,
                "gid": group_id,
            },
        ).fetchone()
        if not res:
            raise HTTPException(status_code=404, detail="Gym group not found.")
        db.commit()
        return {"status": "success", "group": _build_group_payload(db, group_id)}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update group reminder: {str(e)}")

@app.post("/api/groups/{group_id}/leave/{user_id}")
def leave_gym_group(group_id: int, user_id: int, db: Session = Depends(get_db)):
    db.execute(
        text("DELETE FROM gym_group_members WHERE group_id = :gid AND user_id = :uid"),
        {"gid": group_id, "uid": user_id},
    )
    db.commit()
    return {"status": "success", "message": "Left gym group."}

def _build_group_payload(db: Session, group_id: int) -> dict:
    g = db.execute(
        text("SELECT * FROM gym_groups WHERE id = :gid"),
        {"gid": group_id},
    ).fetchone()
    members = db.execute(
        text("SELECT user_id, user_name FROM gym_group_members WHERE group_id = :gid ORDER BY joined_at ASC"),
        {"gid": group_id},
    ).fetchall()
    return {
        "id": g.id,
        "group_name": g.group_name,
        "entry_pass": g.entry_pass,
        "created_by": g.created_by,
        "gym_reminder_hour": g.gym_reminder_hour,
        "gym_reminder_minute": g.gym_reminder_minute,
        "reminder_updated_by": g.reminder_updated_by or "",
        "reminder_updated_at": g.reminder_updated_at.isoformat() if g.reminder_updated_at else "",
        "members": [{"user_id": m.user_id, "user_name": m.user_name} for m in members],
    }

# --- GROUP CHAT ENDPOINTS + FCM PUSH NOTIFICATIONS ---
@app.get("/api/groups/{group_id}/messages")
def get_group_messages(group_id: int, limit: int = 100):
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS group_messages (
                id SERIAL PRIMARY KEY,
                group_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                user_name VARCHAR(120) NOT NULL,
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        rows = conn.execute(
            text("""
                SELECT id, group_id, user_id, user_name, message, created_at
                FROM group_messages
                WHERE group_id = :gid
                ORDER BY id ASC
                LIMIT :lim
            """),
            {"gid": group_id, "lim": limit},
        ).fetchall()

        messages = [
            {
                "id": r[0],
                "group_id": r[1],
                "user_id": r[2],
                "user_name": r[3],
                "message": r[4],
                "created_at": r[5].isoformat() if r[5] else "",
            }
            for r in rows
        ]
        return {"messages": messages}

@app.post("/api/groups/{group_id}/messages")
def post_group_message(group_id: int, payload: GroupMessageCreate):
    text_msg = payload.message.strip()
    if not text_msg:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS group_messages (
                id SERIAL PRIMARY KEY,
                group_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                user_name VARCHAR(120) NOT NULL,
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        row = conn.execute(
            text("""
                INSERT INTO group_messages (group_id, user_id, user_name, message)
                VALUES (:gid, :uid, :uname, :msg)
                RETURNING id, created_at
            """),
            {
                "gid": group_id,
                "uid": payload.user_id,
                "uname": payload.user_name,
                "msg": text_msg,
            },
        ).fetchone()

        _send_group_push_notification(
            conn=conn,
            group_id=group_id,
            sender_id=payload.user_id,
            sender_name=payload.user_name,
            message_text=text_msg,
        )

        return {
            "status": "sent",
            "message": {
                "id": row[0],
                "group_id": group_id,
                "user_id": payload.user_id,
                "user_name": payload.user_name,
                "message": text_msg,
                "created_at": row[1].isoformat() if row[1] else "",
            },
        }

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
