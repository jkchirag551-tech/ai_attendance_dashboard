from flask_sqlalchemy import SQLAlchemy


db = SQLAlchemy()


class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    role = db.Column(db.String(32), nullable=False)
    fullname = db.Column(db.String(128), nullable=False)
    userid = db.Column(db.String(64), nullable=False)
    username = db.Column(db.String(64), unique=True, nullable=False)
    password = db.Column(db.String(256), nullable=False)
    email = db.Column(db.String(120), nullable=True)
    phone = db.Column(db.String(20), nullable=True)
    face_encoding = db.Column(db.Text, nullable=True)
    fcm_token = db.Column(db.String(256), nullable=True)

    attendance_records = db.relationship(
        'Attendance', back_populates='user', cascade='all, delete-orphan'
    )


class Attendance(db.Model):
    __tablename__ = 'attendance'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    username = db.Column(db.String(64), nullable=False)
    subject = db.Column(db.String(64), nullable=True)
    date = db.Column(db.String(20), nullable=False)
    time = db.Column(db.String(20), nullable=False)
    match_score = db.Column(db.String(20), nullable=False)
    status = db.Column(db.String(32), nullable=False)
    proof_path = db.Column(db.String(256), nullable=True)

    user = db.relationship('User', back_populates='attendance_records')


class Settings(db.Model):
    __tablename__ = 'settings'

    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(64), unique=True, nullable=False)
    value = db.Column(db.Text, nullable=False)


class Notice(db.Model):
    __tablename__ = 'notices'

    id = db.Column(db.Integer, primary_key=True)
    author_name = db.Column(db.String(128), nullable=False)
    author_role = db.Column(db.String(32), nullable=False)
    content = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(32), nullable=False, default='Info')
    created_at = db.Column(db.String(64), nullable=False)


class CalendarEvent(db.Model):
    __tablename__ = 'calendar_events'
    id = db.Column(db.Integer, primary_key=True)
    date = db.Column(db.String(20), nullable=False, unique=True)
    title = db.Column(db.String(128), nullable=False)
    type = db.Column(db.String(32), nullable=False)  # 'holiday' or 'working'
