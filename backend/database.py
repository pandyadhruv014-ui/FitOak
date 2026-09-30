import os
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import datetime

# SQLite database file URL (creates fitoak.db in your project directory)
SQLALCHEMY_DATABASE_URL = "sqlite:///./fitoak.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# --- DATABASE TABLES ---

class UserDB(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    age = Column(Integer)
    gender = Column(String)
    goal = Column(String)

class WorkoutDB(Base):
    __tablename__ = "workouts"

    id = Column(Integer, primary_key=True, index=True)
    muscle = Column(String, index=True)
    exercise = Column(String)
    sets_count = Column(Integer)
    max_weight = Column(Float)
    calories_burned = Column(Integer)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class MealDB(Base):
    __tablename__ = "meals"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    calories = Column(Integer)
    protein = Column(Integer)
    carbs = Column(Integer)
    fat = Column(Integer)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

# Create the tables in the database file
def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()