from flask import Blueprint, render_template, request, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash
from models import db, User

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
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = user.role
            session['fullname'] = user.fullname

            return redirect(url_for('auth.welcome'))

        return render_template('login.html', error='Invalid credentials.', selected_role=role, entered_username=username)

    return render_template('login.html', error=None, selected_role='', entered_username='')


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


@auth_bp.route('/signup')
def signup():
    return redirect(url_for('auth.login'))


@auth_bp.route('/logout_page')
def logout_page():
    return render_template('logout.html')


@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('auth.login'))
