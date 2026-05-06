import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev_secret_key_change_me')
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    PERMANENT_SESSION_LIFETIME = 30 * 24 * 60 * 60  # 30 days
    DATABASE_PATH = os.getenv('DATABASE_PATH', os.path.join(os.getcwd(), 'database.db'))
    # Use DATABASE_URL for Cloud (Supabase/PostgreSQL) or fallback to local SQLite
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL', f"sqlite:///{DATABASE_PATH}")
    # Fix for newer SQLAlchemy + Heroku/Render PostgreSQL URLs
    if SQLALCHEMY_DATABASE_URI.startswith("postgres://"):
        SQLALCHEMY_DATABASE_URI = SQLALCHEMY_DATABASE_URI.replace("postgres://", "postgresql://", 1)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
