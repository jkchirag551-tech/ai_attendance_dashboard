try:
    from sqlalchemy import text
    print("SQLAlchemy import successful")
except ImportError as e:
    print(f"SQLAlchemy import failed: {e}")

try:
    from flask import Flask
    print("Flask import successful")
except ImportError as e:
    print(f"Flask import failed: {e}")
