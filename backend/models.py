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
    age = Column(Integer, default=0)
    gender = Column(String, default="")
    goal = Column(String, default="")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Workout(Base):
    __tablename__ = "workouts"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    muscle = Column(String, index=True)
    exercise = Column(String)
    sets_count = Column(Integer)
    max_weight = Column(Float)
    calories_burned = Column(Integer)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class Meal(Base):
    __tablename__ = "meals"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    calories = Column(Integer)
    protein = Column(Integer)
    carbs = Column(Integer)
    fat = Column(Integer)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)