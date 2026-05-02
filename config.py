import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev_secret_key_change_me')
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    DATABASE_PATH = os.getenv('DATABASE_PATH', os.path.join(os.getcwd(), 'database.db'))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{DATABASE_PATH}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
