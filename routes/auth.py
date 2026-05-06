from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
from models import db, User
import base64
import json
import numpy as np
import cv2
import face_recognition

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        session.clear()

    if request.method == 'POST':
        role = request.form.get('role', '').strip()
        username = request.form.get('username', '').strip()
        password = request.form.get('password')

        if not role:
            return render_template('login.html', error='Please select a role.', selected_role='', entered_username=username)

        user = User.query.filter_by(role=role, username=username).first()

        if user and check_password_hash(user.password, password):
            if not user.is_approved:
                return render_template('login.html', error='Your account is pending approval by an administrator.', selected_role=role, entered_username=username)
            
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = user.role
            session['fullname'] = user.fullname

            return redirect(url_for('auth.welcome'))

        return render_template('login.html', error='Invalid credentials.', selected_role=role, entered_username=username)

    return render_template('login.html', error=None, selected_role='', entered_username='')


@auth_bp.route('/admin-portal', methods=['GET', 'POST'])
def admin_portal_login():
    """Hidden login for administrators only."""
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password')

        user = User.query.filter_by(role='admin', username=username).first()

        if user and check_password_hash(user.password, password):
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = 'admin'
            session['fullname'] = user.fullname
            return redirect(url_for('auth.welcome'))

        return render_template('login.html', error='Invalid admin credentials.', is_admin_portal=True)

    return render_template('login.html', error=None, is_admin_portal=True)


@auth_bp.route('/welcome')
def welcome():
    if 'user_id' not in session:
        return redirect(url_for('auth.login'))

    role = session.get('role')
    dashboard_url = url_for('admin.admin_dashboard')
    if role == 'student':
        dashboard_url = url_for('student.student_dashboard')
    elif role == 'teacher':
        dashboard_url = url_for('teacher.dashboard')

    return render_template('welcome.html', dashboard_url=dashboard_url)


@auth_bp.route('/signup', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        fullname = request.form.get('fullname')
        userid = request.form.get('userid')
        username = request.form.get('username')
        password = request.form.get('password')
        email = request.form.get('email')
        phone = request.form.get('phone')
        image_data = request.form.get('image')

        error = None
        if not fullname or not userid or not username or not password or not email or not phone or not image_data:
            error = 'All fields including a face image are required.'
        
        if not error:
            existing_user = User.query.filter_by(username=username).first()
            if existing_user:
                error = 'Username already exists.'
        
        if not error:
            try:
                # Process Face Image
                encoded_data = image_data.split(',')[1]
                nparr = np.frombuffer(base64.b64decode(encoded_data), np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if img is None:
                    error = 'Failed to decode image.'
                else:
                    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                    face_locations = face_recognition.face_locations(rgb_img)
                    unknown_encodings = face_recognition.face_encodings(rgb_img, face_locations)

                    if len(unknown_encodings) != 1:
                        error = 'Please provide exactly one clear face image.'
                    else:
                        candidate_encoding = unknown_encodings[0]
                        
                        # Check if face already registered
                        existing_users = User.query.filter(User.face_encoding.isnot(None)).all()
                        for existing_user in existing_users:
                            existing_encoding = np.array(json.loads(existing_user.face_encoding))
                            if face_recognition.compare_faces([existing_encoding], candidate_encoding, tolerance=0.45)[0]:
                                error = 'This face is already registered.'
                                break
                        
                        if not error:
                            face_encoding_json = json.dumps(candidate_encoding.tolist())
                            new_user = User(
                                role='student',
                                fullname=fullname,
                                userid=userid,
                                username=username,
                                password=generate_password_hash(password),
                                email=email,
                                phone=phone,
                                face_encoding=face_encoding_json,
                                is_approved=False # Pending approval
                            )
                            db.session.add(new_user)
                            db.session.commit()
                            return render_template('signup.html', success="Signup successful! Please wait for admin approval.")
            except Exception as e:
                db.session.rollback()
                error = f"Error during signup: {str(e)}"
        
        return render_template('signup.html', error=error)

    return render_template('signup.html')


@auth_bp.route('/logout_page')
def logout_page():
    return render_template('logout.html')


@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('auth.login'))
