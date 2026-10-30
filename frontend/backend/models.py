import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from sqlalchemy.sql import func
from database import Base

class User(Base):
    __tablename__ = "users"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)
    dob = Column(String, default="")
    height_cm = Column(Float, default=0.0)
    weight_kg = Column(Float, default=0.0)
    age = Column(Integer, default=0)
    gender = Column(String, default="")
    goal = Column(String, default="")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Workout(Base):
    __tablename__ = "workouts"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    workout_type = Column(String, default="Strength")  # Strength / Cardio
    muscle = Column(String, index=True)
    exercise = Column(String)
    sets_count = Column(Integer, default=0)
    max_weight = Column(Float, default=0.0)
    duration_mins = Column(Integer, default=0)
    speed_kmh = Column(Float, default=0.0)
    incline = Column(Float, default=0.0)
    calories_burned = Column(Integer, default=0)
    estimated_fat_loss_g = Column(Float, default=0.0)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class Meal(Base):
    __tablename__ = "meals"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    name = Column(String)
    quantity = Column(String, default="")
    calories = Column(Integer, default=0)
    protein = Column(Float, default=0.0)
    carbs = Column(Float, default=0.0)
    fat = Column(Float, default=0.0)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
