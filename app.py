import os
import uuid
import json
from datetime import date, datetime, timedelta

import cv2
import face_recognition
import numpy as np
import pandas as pd
import firebase_admin
from firebase_admin import credentials, messaging
from flask import Flask, request, jsonify, send_from_directory, render_template
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from flask_mail import Mail, Message as MailMessage
from sqlalchemy import text
from werkzeug.security import generate_password_hash, check_password_hash

from config import Config
from models import Attendance, db, User, Notice, Settings, CalendarEvent
from routes.auth import auth_bp
from routes.admin import admin_bp, calculate_attendance_percentage, get_working_days, get_setting_value
from routes.student import student_bp
from routes.face import face_bp
from routes.teacher import teacher_bp

# Initialize SocketIO globally
socketio = SocketIO(cors_allowed_origins="*")
mail = Mail()

def ensure_schema(app):
    with app.app_context():
        connection = db.engine.connect()
        # Users table updates
        users_columns = [row['name'] for row in connection.execute(text('PRAGMA table_info(users)')).mappings()]
        if 'face_encoding' not in users_columns:
            connection.execute(text('ALTER TABLE users ADD COLUMN face_encoding TEXT'))
        if 'email' not in users_columns:
            connection.execute(text('ALTER TABLE users ADD COLUMN email TEXT'))
        if 'phone' not in users_columns:
            connection.execute(text('ALTER TABLE users ADD COLUMN phone TEXT'))
        if 'fcm_token' not in users_columns:
            connection.execute(text('ALTER TABLE users ADD COLUMN fcm_token TEXT'))
        if 'is_approved' not in users_columns:
            connection.execute(text('ALTER TABLE users ADD COLUMN is_approved BOOLEAN DEFAULT 1'))

        # Attendance table updates
        attendance_columns = [row['name'] for row in connection.execute(text('PRAGMA table_info(attendance)')).mappings()]
        if 'user_id' not in attendance_columns:
            connection.execute(text('ALTER TABLE attendance ADD COLUMN user_id INTEGER'))
        if 'subject' not in attendance_columns:
            connection.execute(text('ALTER TABLE attendance ADD COLUMN subject TEXT'))
        if 'proof_path' not in attendance_columns:
            connection.execute(text('ALTER TABLE attendance ADD COLUMN proof_path TEXT'))

        # Notices table updates
        notices_columns = [row['name'] for row in connection.execute(text('PRAGMA table_info(notices)')).mappings()]
        if 'category' not in notices_columns:
            connection.execute(text('ALTER TABLE notices ADD COLUMN category TEXT DEFAULT "Info"'))
        if 'author_role' not in notices_columns:
            connection.execute(text('ALTER TABLE notices ADD COLUMN author_role TEXT DEFAULT "admin"'))
        if 'author_name' not in notices_columns:
            connection.execute(text('ALTER TABLE notices ADD COLUMN author_name TEXT'))

        connection.commit()
        connection.close()

def create_app():
    app_instance = Flask(__name__, template_folder='templates', static_folder='static')
    app_instance.config.from_object(Config)

    # Use a persistent proofs directory if provided (for Render), otherwise default to static/proofs
    proofs_dir = os.getenv('PROOFS_DIR', os.path.join(app_instance.root_path, 'static', 'proofs'))
    if not os.path.exists(proofs_dir):
        os.makedirs(proofs_dir)

    @app_instance.route('/static/proofs/<filename>')
    def serve_proof(filename):
        from flask import send_from_directory
        return send_from_directory(proofs_dir, filename)

    CORS(app_instance)
    db.init_app(app_instance)
    socketio.init_app(app_instance)
    
    # Mail Configuration
    app_instance.config['MAIL_SERVER'] = 'smtp.gmail.com'
    app_instance.config['MAIL_PORT'] = 587
    app_instance.config['MAIL_USE_TLS'] = True
    app_instance.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
    app_instance.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
    app_instance.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_USERNAME')
    mail.init_app(app_instance)

    # Initialize Firebase Admin
    try:
        # Check for Render Secret File path first, then local fallback
        secret_path = "/etc/secrets/firebase_adminsdk"
        if not os.path.exists(secret_path):
            secret_path = "firebase-adminsdk.json"
            
        if os.path.exists(secret_path):
            cred = credentials.Certificate(secret_path)
            firebase_admin.initialize_app(cred)
            print(f"Firebase Admin initialized successfully using {secret_path}.")
        else:
            print("Warning: Firebase Admin credentials not found. Notifications disabled.")
    except Exception as e:
        print(f"Warning: Firebase Admin could not be initialized. {e}")

    with app_instance.app_context():
        db.create_all()
        ensure_schema(app_instance)
        
        # Create default admin if none exists
        if User.query.filter_by(role='admin').count() == 0:
            default_admin = User(
                role='admin',
                fullname='System Administrator',
                userid='ADMIN001',
                username='admin',
                password=generate_password_hash('Admin@123')
            )
            db.session.add(default_admin)
            db.session.commit()
            print("Default admin account created: admin / Admin@123")

    app_instance.register_blueprint(auth_bp)
    app_instance.register_blueprint(admin_bp)
    app_instance.register_blueprint(teacher_bp)
    app_instance.register_blueprint(student_bp)
    app_instance.register_blueprint(face_bp)

    # --- PRO API ROUTES ---
    
    @app_instance.route('/api/user/fcm_token', methods=['POST'])
    def api_save_fcm_token():
        data = request.get_json() or {}
        username = data.get('username')
        token = data.get('token')
        
        user = User.query.filter_by(username=username).first()
        if user:
            user.fcm_token = token
            db.session.commit()
            return {"status": "success"}, 200
        return {"status": "error", "message": "User not found"}, 404

    @app_instance.route('/api/admin/test_notification', methods=['POST'])
    def api_test_notification():
        data = request.get_json() or {}
        token = data.get('token')
        if not token:
            return {"status": "error", "message": "No token provided"}, 400
        
        send_push_notification(
            token, 
            "Intelligence Engine Test 🟢", 
            "Your notification system is fully operational and synchronized with the MR.TECHLAB server."
        )
        return {"status": "success"}, 200

    @app_instance.route('/api/admin/test_email', methods=['POST'])
    def api_test_email():
        data = request.get_json() or {}
        email = data.get('email')
        if not email:
            return {"status": "error", "message": "No email provided"}, 400
        
        try:
            msg = MailMessage(
                "MR. TECHLAB System Test 📧",
                recipients=[email],
                body="This is a test email from your AI Attendance System. If you received this, your Gmail SMTP configuration is correct!"
            )
            mail.send(msg)
            return {"status": "success", "message": f"Test email sent to {email}"}, 200
        except Exception as e:
            return {"status": "error", "message": str(e)}, 500

    def send_push_notification(token, title, body):
        if not token:
            return
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            android=messaging.AndroidConfig(
                notification=messaging.AndroidNotification(
                    channel_id='high_importance_channel',
                    priority='high',
                ),
            ),
            token=token,
        )
        try:
            response = messaging.send(message)
            print('Successfully sent message:', response)
        except Exception as e:
            print('Error sending push notification:', e)

    @app_instance.route('/api/login', methods=['POST'])
    def api_login():
        data = request.get_json() or {}
        username = data.get('username')
        password = data.get('password')
        requested_role = data.get('role')

        user = User.query.filter_by(username=username).first()
        
        if user and check_password_hash(user.password, password):
            if not user.is_approved:
                return {"status": "error", "message": "Account pending approval"}, 403
            
            # Strict role verification: prevent student from logging in as admin/teacher and vice versa
            if requested_role and user.role != requested_role:
                return {
                    "status": "error", 
                    "message": f"Access Denied: This account is registered as {user.role}, not {requested_role}."
                }, 403
            
            return {
                "status": "success", 
                "role": user.role, 
                "fullname": user.fullname, 
                "username": user.username
            }, 200
            
        return {"status": "error", "message": "Invalid username or password"}, 401

    @app_instance.route('/api/dashboard/admin', methods=['GET'])
    def api_admin_dashboard():
        total_students = User.query.filter_by(role='student').count()
        total_teachers = User.query.filter_by(role='teacher').count()
        total_admins = User.query.filter_by(role='admin').count()
        
        today_str = date.today().strftime('%Y-%m-%d')
        present_today = Attendance.query.filter_by(date=today_str).count()

        recent = Attendance.query.order_by(Attendance.id.desc()).limit(20).all()
        logs = [{
            "username": l.username, "date": l.date, "time": l.time, "status": l.status,
            "match_score": l.match_score, "proof_url": f"/static/proofs/{l.proof_path}" if l.proof_path else None
        } for l in recent]
        return {
            "total_students": total_students,
            "total_teachers": total_teachers,
            "total_admins": total_admins,
            "present_today": present_today,
            "recent_logs": logs
        }, 200

    @app_instance.route('/api/dashboard/teacher', methods=['GET'])
    def api_teacher_dashboard():
        total_students = User.query.filter_by(role='student').count()
        
        today_str = date.today().strftime('%Y-%m-%d')
        todays_scans = Attendance.query.filter_by(date=today_str).count()

        recent = Attendance.query.order_by(Attendance.id.desc()).limit(20).all()
        logs = [{
            "username": l.username, "date": l.date, "time": l.time, "status": l.status,
            "match_score": l.match_score, "proof_url": f"/static/proofs/{l.proof_path}" if l.proof_path else None
        } for l in recent]

        # Aggregated data for graph: Attendance count per day for the last 7 days
        today = date.today()
        graph_data = []
        for i in range(6, -1, -1):
            d = (today - timedelta(days=i)).strftime('%Y-%m-%d')
            count = Attendance.query.filter_by(date=d).count()
            graph_data.append({"date": d, "count": count})

        return {
            "total_students": total_students,
            "todays_scans": todays_scans,
            "recent_logs": logs,
            "graph_data": graph_data
        }, 200

    @app_instance.route('/api/dashboard/student/<username>', methods=['GET'])
    def api_student_dashboard(username):
        user = User.query.filter_by(username=username).first()

        # Get all logs for counts and heatmap
        all_logs = Attendance.query.filter_by(username=username).all()
        # Get history sorted by ID descending to show newest first
        recent_logs = Attendance.query.filter_by(username=username).order_by(Attendance.id.desc()).limit(15).all()

        # Calculate total working days in current period
        today_date = date.today()
        semester_start = get_setting_value('semester_start_date')
        working_days = get_working_days()
        total_working_days = 0
        if semester_start:
            try:
                start_date = datetime.strptime(semester_start, '%Y-%m-%d').date()
                curr = start_date
                while curr <= today_date:
                    if curr.weekday() in working_days:
                        total_working_days += 1
                    curr += timedelta(days=1)
            except:
                pass

        return {
            "total_days_present": len(set([l.date for l in all_logs])),
            "total_working_days": total_working_days or 20,
            "attendance_percentage": calculate_attendance_percentage(user.id) if user else 0,
            "semester_start": semester_start or '2026-01-01',
            "semester_end": get_setting_value('semester_end_date') or '2026-06-30',
            "history": [{"date": l.date, "time": l.time, "status": l.status} for l in recent_logs],
            "heatmap": {l.date: 1 for l in all_logs}
        }, 200

    @app_instance.route('/api/scan', methods=['POST'])
    def api_process_scan():
        # 1. Handle Timezone (Render is UTC, we need IST)
        # IST is UTC + 5:30
        utc_now = datetime.utcnow()
        ist_now = utc_now + timedelta(hours=5, minutes=30)
        
        today_weekday = ist_now.weekday() # 0=Monday, 6=Sunday
        working_days = get_working_days()

        if today_weekday not in working_days:
            return {"status": "error", "message": f"Portal is closed today ({ist_now.strftime('%A')}). No check-ins allowed on non-working days."}, 403

        current_time_str = ist_now.strftime('%H:%M')
        start_time = get_setting_value('working_day_start_time', '09:00')
        end_time = get_setting_value('working_day_end_time', '17:00')

        if current_time_str < start_time or current_time_str > end_time:
            return {
                "status": "error", 
                "message": f"Outside working hours. Server Time (IST): {ist_now.strftime('%I:%M %p')}. Check-in allowed only between {start_time} and {end_time}."
            }, 403

        # 2. Process Face Recognition
        image_file = request.files['frame']
        subject = request.form.get('subject', 'General')
        img = cv2.imdecode(np.frombuffer(image_file.read(), np.uint8), cv2.IMREAD_COLOR)
        rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        encodings = face_recognition.face_encodings(rgb_img)
        if not encodings:
            return {"status": "error", "message": "No face detected"}, 400

        unknown_encoding = encodings[0]
        all_users = User.query.filter(User.face_encoding.isnot(None)).all()

        for user in all_users:
            known_encoding = np.array(json.loads(user.face_encoding))
            if face_recognition.compare_faces([known_encoding], unknown_encoding, tolerance=0.55)[0]:
                # 3. Prevent duplicate check-ins for today
                today_str = ist_now.strftime('%Y-%m-%d')
                existing = Attendance.query.filter_by(user_id=user.id, date=today_str).first()
                if existing:
                    return {"status": "error", "message": f"Attendance already marked for today at {existing.time}."}, 400

                filename = f"{uuid.uuid4().hex}.jpg"
                cv2.imwrite(os.path.join(proofs_dir, filename), img)
                new_log = Attendance(
                    user_id=user.id,
                    username=user.username,
                    subject=subject,
                    date=ist_now.strftime('%Y-%m-%d'),
                    time=ist_now.strftime('%I:%M %p'),
                    match_score='95%',
                    status='Verified',
                    proof_path=filename
                )
                db.session.add(new_log)
                db.session.commit()

                # --- REAL-TIME NOTIFICATIONS ---
                try:
                    # 1. Instant Check-in Notification
                    if user.fcm_token:
                        send_push_notification(
                            user.fcm_token,
                            "Attendance Recorded ✅",
                            f"Hi {user.fullname}, your attendance for {subject} has been verified at {new_log.time}."
                        )

                    # 2. Anomaly Detection (Low Attendance)
                    threshold = float(get_setting_value('low_attendance_threshold', '75.0'))
                    current_percentage = calculate_attendance_percentage(user.id)
                    if current_percentage < threshold:
                        send_push_notification(
                            user.fcm_token,
                            "Attendance Alert ⚠️",
                            f"Your attendance is currently {current_percentage:.1f}%, which is below the {threshold}% threshold."
                        )
                except Exception as e:
                    print(f"Notification Error: {e}")

                socketio.emit('new_checkin', {
                    "username": user.username,
                    "date": new_log.date,
                    "time": new_log.time,
                    "status": 'Verified',
                    "proof_url": f"/static/proofs/{filename}"
                })
                return {"status": "success", "message": f"Welcome, {user.username}!"}, 200
        return {"status": "error", "message": "Face not recognized"}, 401

    @app_instance.route('/api/notices', methods=['GET', 'POST'])
    def api_notices():
        if request.method == 'POST':
            data = request.get_json()
            notice = Notice(
                author_name=data['author_name'],
                author_role=data['author_role'],
                content=data['content'],
                category=data.get('category', 'Info'),
                created_at=datetime.now().strftime('%Y-%m-%d %I:%M %p')
            )
            db.session.add(notice)
            db.session.commit()

            # Broadcast logic
            if data.get('broadcast_email') or data.get('broadcast_sms') or data.get('broadcast_push', True):
                if notice.author_role == 'admin':
                    recipients = User.query.filter(User.role.in_(['student', 'teacher'])).all()
                else:
                    recipients = User.query.filter(User.role == 'student').all()

                for user in recipients:
                    # 1. Real Push Notification (Firebase)
                    if data.get('broadcast_push', True) and user.fcm_token:
                        send_push_notification(
                            user.fcm_token,
                            f"New Notice: {notice.category} 📢",
                            notice.content
                        )
                    
                    # 2. Real Email (via Gmail)
                    if data.get('broadcast_email') and user.email:
                        send_email_notification(
                            user.email,
                            f"New Notice: {notice.category} 📢",
                            f"Hello {user.fullname},\n\nA new notice has been posted: {notice.category}\n\nContent:\n{notice.content}\n\nRegards,\nMR. TECHLAB System"
                        )

                    # 3. Simulated SMS (Still simulation)
                    if data.get('broadcast_sms') and user.phone:
                        print(f"DEBUG: Sending SMS to {user.phone}: {notice.content}")

            return {"status": "success"}, 201
        notices = Notice.query.order_by(Notice.id.desc()).all()
        return jsonify([{
            "id": n.id, 
            "author_name": n.author_name, 
            "author_role": n.author_role,
            "content": n.content, 
            "category": n.category, 
            "created_at": n.created_at
        } for n in notices]), 200

    @app_instance.route('/api/admin/settings', methods=['GET'])
    def api_get_settings():
        settings_objs = Settings.query.all()
        data = {s.key: s.value for s in settings_objs}
        # Ensure default threshold exists
        if 'low_attendance_threshold' not in data:
            data['low_attendance_threshold'] = '75.0'
        return jsonify(data), 200

    @app_instance.route('/api/admin/settings', methods=['POST'])
    def api_update_settings():
        data = request.get_json() or {}
        for key, value in data.items():
            setting = Settings.query.filter_by(key=key).first()
            if setting:
                setting.value = str(value)
            else:
                db.session.add(Settings(key=key, value=str(value)))
        db.session.commit()
        return {"status": "success", "message": "Settings updated successfully"}, 200

    @app_instance.route('/api/user/change_password', methods=['POST'])
    def api_change_password():
        data = request.get_json() or {}
        username = data.get('username')
        old_password = data.get('old_password')
        new_password = data.get('new_password')

        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password, old_password):
            user.password = generate_password_hash(new_password)
            db.session.commit()
            return {"status": "success", "message": "Password changed successfully"}, 200
        return {"status": "error", "message": "Invalid current password"}, 401

    @app_instance.route('/api/admin/bulk_register', methods=['POST'])
    def api_bulk_register():
        df = pd.read_excel(request.files['file'])
        for _, row in df.iterrows():
            if not User.query.filter_by(username=str(row['username'])).first():
                db.session.add(User(
                    role=str(row.get('role', 'student')),
                    fullname=str(row['fullname']),
                    userid=str(row['userid']),
                    username=str(row['username']),
                    password=generate_password_hash('Student@123'),
                    email=str(row.get('email', '')),
                    phone=str(row.get('phone', ''))
                ))
        db.session.commit()
        return {"status": "success"}, 201

    @app_instance.route('/api/admin/users', methods=['GET'])
    def api_admin_users():
        users = User.query.all()
        return jsonify([{
            "id": u.id, "fullname": u.fullname, "username": u.username,
            "userid": u.userid, "role": u.role, "email": u.email, "phone": u.phone,
            "is_approved": u.is_approved,
            "attendance_percentage": calculate_attendance_percentage(u.id)
        } for u in users]), 200

    @app_instance.route('/api/admin/register', methods=['POST'])
    def api_admin_register():
        data = request.form
        role = data.get('role', 'student')
        fullname = data.get('fullname')
        userid = data.get('userid')
        username = data.get('username')
        password = data.get('password')
        email = data.get('email')
        phone = data.get('phone')

        if User.query.filter_by(username=username).first():
            return {"status": "error", "message": "Username already exists"}, 400

        face_encoding = None
        if 'face_image' in request.files:
            img_file = request.files['face_image']
            img = cv2.imdecode(np.frombuffer(img_file.read(), np.uint8), cv2.IMREAD_COLOR)
            rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            encodings = face_recognition.face_encodings(rgb_img)
            if encodings:
                face_encoding = json.dumps(encodings[0].tolist())

        user = User(
            role=role, fullname=fullname, userid=userid,
            username=username, password=generate_password_hash(password),
            email=email, phone=phone, face_encoding=face_encoding
        )
        db.session.add(user)
        db.session.commit()
        return {"status": "success"}, 201

    @app_instance.route('/api/admin/attendance/monthly', methods=['GET'])
    def api_admin_monthly_attendance():
        year = date.today().year
        monthly_data = []
        for month in range(1, 13):
            month_str = f"{year}-{month:02d}"
            count = Attendance.query.filter(Attendance.date.like(f"{month_str}-%")).count()
            monthly_data.append({"month": month_str, "count": count})
        return jsonify(monthly_data), 200

    @app_instance.route('/api/admin/attendance/daily', methods=['GET'])
    def api_admin_daily_attendance():
        month_prefix = request.args.get('month')
        if not month_prefix:
            return {"status": "error", "message": "Month is required"}, 400
        records = Attendance.query.filter(Attendance.date.like(f"{month_prefix}-%")).all()
        daily_counts = {}
        for r in records:
            daily_counts[r.date] = daily_counts.get(r.date, 0) + 1
        result = [{"date": d, "count": daily_counts[d]} for d in sorted(daily_counts.keys())]
        return jsonify(result), 200

    @app_instance.route('/api/admin/attendance/students', methods=['GET'])
    def api_admin_day_students_attendance():
        day_str = request.args.get('date')
        if not day_str:
            return {"status": "error", "message": "Date is required"}, 400
        records = Attendance.query.filter_by(date=day_str).all()
        result = [{"username": r.username, "time": r.time, "status": r.status, "subject": r.subject} for r in records]
        return jsonify(result), 200

    @app_instance.route('/api/calendar', methods=['GET', 'POST'])
    def api_calendar():
        if request.method == 'POST':
            data = request.get_json()
            # Upsert logic
            existing = CalendarEvent.query.filter_by(date=data['date']).first()
            if existing:
                existing.title = data['title']
                existing.type = data['type']
            else:
                db.session.add(CalendarEvent(date=data['date'], title=data['title'], type=data['type']))
            db.session.commit()
            return {"status": "success"}, 200

        events = CalendarEvent.query.all()
        return jsonify([{"id": e.id, "date": e.date, "title": e.title, "type": e.type} for e in events]), 200

    @app_instance.route('/api/calendar/<int:event_id>', methods=['DELETE'])
    def api_delete_calendar_event(event_id):
        event = CalendarEvent.query.get_or_404(event_id)
        db.session.delete(event)
        db.session.commit()
        return {"status": "success"}, 200

    def send_email_notification(recipient, subject, body):
        try:
            msg = MailMessage(subject, recipients=[recipient], body=body)
            mail.send(msg)
            return True
        except Exception as e:
            print(f"Mail Error: {e}")
            return False

    # --- FLUTTER WEB BUNDLE ROUTES ---
    @app_instance.route('/')
    def serve_dashboard():
        """Serves the Flutter Web Dashboard"""
        return render_template('index.html')

    @app_instance.route('/<path:path>')
    def serve_flutter_assets(path):
        """Handles Flutter JS, CSS, and Asset requests with deep path fallback"""
        # 1. Check templates first (index.html siblings)
        if os.path.exists(os.path.join(app_instance.root_path, 'templates', path)):
            return send_from_directory('templates', path)
        
        # 2. Check static folder directly
        static_path = os.path.join(app_instance.root_path, 'static', path)
        if os.path.exists(static_path):
            return send_from_directory('static', path)
            
        # 3. Handle Flutter's potential double-nesting or missing prefixes
        if 'assets/' in path:
            filename = path.split('/')[-1]
            if any(path.endswith(ext) for ext in ['.png', '.jpg', '.jpeg', '.gif', '.svg']):
                for search_dir in ['static/images', 'static/assets/images', 'static/assets/assets/images']:
                    potential_path = os.path.join(app_instance.root_path, search_dir, filename)
                    if os.path.exists(potential_path):
                        return send_from_directory(search_dir, filename)

        return send_from_directory('static', path)

    return app_instance

app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    print("\n" + "="*50)
    print("AI ATTENDANCE SYSTEM IS STARTING...")
    print(f"WEB DASHBOARD: http://0.0.0.0:{port}")
    print("="*50 + "\n")
    socketio.run(app, debug=False, host='0.0.0.0', port=port, allow_unsafe_werkzeug=True)
