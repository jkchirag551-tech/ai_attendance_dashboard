import json
from datetime import datetime, timedelta
from flask import Blueprint, render_template, request, redirect, session, flash, jsonify, send_file, url_for
from werkzeug.security import generate_password_hash
from models import db, User, Settings, Attendance, Notice
from sqlalchemy import desc, or_
from utils import login_required, role_required
from export_utils import build_attendance_excel, build_attendance_pdf

# 1. Create the Blueprint
# This tells Flask: "Group all routes starting with '/teacher' together"
teacher_bp = Blueprint('teacher', __name__, url_prefix='/teacher')


def get_working_days():
    setting = Settings.query.filter_by(key='working_days').first()
    if setting:
        try:
            return json.loads(setting.value.replace("'", '"'))
        except (json.JSONDecodeError, ValueError):
            # Fallback to eval if it's not valid JSON (for backward compatibility with single-quoted strings)
            try:
                return eval(setting.value)
            except Exception:
                return [0, 1, 2, 3, 4]
    return [0, 1, 2, 3, 4]


def get_setting_value(key, default=None):
    setting = Settings.query.filter_by(key=key).first()
    return setting.value if setting else default


def set_setting_value(key, value):
    setting = Settings.query.filter_by(key=key).first()
    if setting:
        setting.value = value
    else:
        setting = Settings(key=key, value=value)
        db.session.add(setting)


def calculate_attendance_percentage(user_id, days=30):
    today = datetime.now().date()
    semester_start = get_setting_value('semester_start_date')
    semester_end = get_setting_value('semester_end_date')

    if semester_start and semester_end:
        start_date = datetime.strptime(semester_start, '%Y-%m-%d').date()
        end_date = min(today, datetime.strptime(semester_end, '%Y-%m-%d').date())
    else:
        end_date = today
        start_date = end_date - timedelta(days=days)

    if end_date < start_date:
        return 0

    working_days = get_working_days()

    total_days = 0
    current_date = start_date
    while current_date <= end_date:
        if current_date.weekday() in working_days:
            total_days += 1
        current_date += timedelta(days=1)

    if total_days == 0:
        return 0

    attendance_count = Attendance.query.filter(
        Attendance.user_id == user_id,
        Attendance.date >= start_date.strftime('%Y-%m-%d'),
        Attendance.date <= end_date.strftime('%Y-%m-%d')
    ).count()

    return round((attendance_count / total_days) * 100, 1)


def get_teacher_attendance_query(filter_type, selected_date, search_name, student_id=None):
    attendance_query = Attendance.query.outerjoin(User, Attendance.user_id == User.id)

    if student_id:
        attendance_query = attendance_query.filter(Attendance.user_id == student_id)

    if filter_type == 'day' and selected_date:
        attendance_query = attendance_query.filter(Attendance.date == selected_date)
    elif filter_type != 'all':
        filter_type = 'all'

    if search_name:
        search_pattern = f'%{search_name}%'
        attendance_query = attendance_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                Attendance.username.ilike(search_pattern),
            )
        )

    return attendance_query, filter_type


def serialize_attendance_rows(records):
    rows = []
    for record in records:
        rows.append(
            {
                'fullname': record.user.fullname if record.user else record.username,
                'roll_number': record.user.userid if record.user else record.username,
                'date': record.date,
                'time': record.time,
                'match_score': record.match_score,
                'status': record.status,
            }
        )
    return rows

# 2. The Dashboard Route
@teacher_bp.route('/dashboard')
@login_required
@role_required('teacher')
def dashboard():
    # Get the teacher's info to say "Welcome back, [Name]"
    teacher_info = User.query.get(session['user_id'])
    
    # Get ALL students so the teacher can view their attendance
    search_name = (request.args.get('search') or '').strip()
    students_query = User.query.filter_by(role='student', is_approved=True)
    if search_name:
        search_pattern = f'%{search_name}%'
        students_query = students_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                User.userid.ilike(search_pattern),
            )
        )
    students = students_query.order_by(User.fullname.asc()).all()
    day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    working_days = [day_names[i] for i in get_working_days()]
    class_update_message = get_setting_value('class_update_message', '')
    class_update_updated_at = get_setting_value('class_update_updated_at', '')
    
    # Recent logs for the teacher dashboard
    recent_logs = Attendance.query.order_by(Attendance.id.desc()).limit(20).all()

    # Graph data: Last 7 days
    today_dt = datetime.now().date()
    graph_data = []
    for i in range(6, -1, -1):
        d = (today_dt - timedelta(days=i)).strftime('%Y-%m-%d')
        count = Attendance.query.filter_by(date=d).count()
        graph_data.append({"date": d, "count": count})

    # Send this data to your teacher HTML page
    return render_template(
        'teacher_dashboard.html',
        fullname=teacher_info.fullname,
        students=students,
        search_name=search_name,
        working_days=working_days,
        class_update_message=class_update_message,
        class_update_updated_at=class_update_updated_at,
        graph_data=graph_data,
        recent_logs=recent_logs
    )


@teacher_bp.route('/logs')
@login_required
@role_required('teacher')
def logs():
    teacher_info = User.query.get(session['user_id'])
    filter_type = request.args.get('filter', 'all')
    selected_date = (request.args.get('date') or '').strip()
    search_name = (request.args.get('search') or '').strip()

    attendance_query, filter_type = get_teacher_attendance_query(filter_type, selected_date, search_name)
    attendance_records = attendance_query.order_by(desc(Attendance.id)).limit(100).all()
    students_query = User.query.filter_by(role='student', is_approved=True)
    if search_name:
        search_pattern = f'%{search_name}%'
        students_query = students_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                User.userid.ilike(search_pattern),
            )
        )

    students = students_query.order_by(User.fullname.asc()).all()
    for student in students:
        student.attendance_percentage = calculate_attendance_percentage(student.id)

    day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    working_days = [day_names[i] for i in get_working_days()]
    class_update_message = get_setting_value('class_update_message', '')
    class_update_updated_at = get_setting_value('class_update_updated_at', '')

    return render_template(
        'teacher_logs.html',
        fullname=teacher_info.fullname,
        attendance_records=attendance_records,
        students=students,
        filter_type=filter_type,
        selected_date=selected_date,
        search_name=search_name,
        working_days=working_days,
        class_update_message=class_update_message,
        class_update_updated_at=class_update_updated_at
    )


@teacher_bp.route('/attendance/export/<string:filetype>')
@login_required
@role_required('teacher')
def export_attendance(filetype):
    filter_type = request.args.get('filter', 'all')
    selected_date = (request.args.get('date') or '').strip()
    search_name = (request.args.get('search') or '').strip()
    student_id = request.args.get('student_id', type=int)

    attendance_query, filter_type = get_teacher_attendance_query(filter_type, selected_date, search_name, student_id)
    attendance_records = attendance_query.order_by(desc(Attendance.id)).all()
    rows = serialize_attendance_rows(attendance_records)

    title = 'Teacher Attendance Report'
    filename = 'teacher_attendance_report'

    if student_id:
        user = User.query.get(student_id)
        if user:
            title = f'Attendance Report - {user.fullname}'
            filename = f'attendance_{user.fullname.replace(" ", "_")}'
    elif filter_type == 'day' and selected_date:
        title = f'{title} - {selected_date}'
        filename = f'attendance_{selected_date}'
    elif search_name:
        title = f'{title} - {search_name}'
        filename = f'attendance_{search_name.replace(" ", "_")}'

    if filetype == 'excel':
        return send_file(
            build_attendance_excel(rows, title),
            as_attachment=True,
            download_name=f'{filename}.xls',
            mimetype='application/vnd.ms-excel',
        )

    if filetype == 'pdf':
        return send_file(
            build_attendance_pdf(rows, title),
            as_attachment=True,
            download_name=f'{filename}.pdf',
            mimetype='application/pdf',
        )

    flash('Unsupported export format selected.', 'danger')
    return redirect('/teacher/logs')


@teacher_bp.route('/reset_student_password/<int:user_id>', methods=['POST'])
@login_required
@role_required('teacher')
def reset_student_password(user_id):
    student = User.query.get_or_404(user_id)
    if student.role != 'student':
        return {'status': 'error', 'message': 'Teachers can only reset student passwords.'}, 400

    new_password = (request.get_json(silent=True) or {}).get('password', '').strip()
    if len(new_password) < 4:
        return {'status': 'error', 'message': 'Password must be at least 4 characters long.'}, 400

    try:
        student.password = generate_password_hash(new_password)
        db.session.commit()
        return {'status': 'success', 'message': f'Password updated successfully for {student.fullname}.'}
    except Exception:
        db.session.rollback()
        return {'status': 'error', 'message': 'Failed to reset password.'}, 500


@teacher_bp.route('/update_class_message', methods=['POST'])
@login_required
@role_required('teacher')
def update_class_message():
    data = request.get_json(silent=True) or {}
    class_update_message = data.get('message', '').strip()
    broadcast_email = data.get('broadcast_email', False)
    broadcast_sms = data.get('broadcast_sms', False)

    try:
        set_setting_value('class_update_message', class_update_message)
        set_setting_value('class_update_updated_at', datetime.now().strftime('%Y-%m-%d %I:%M %p'))

        # Broadcast logic
        if (broadcast_email or broadcast_sms) and class_update_message:
            recipients = User.query.filter(User.role == 'student').all()
            for user in recipients:
                if broadcast_email and user.email:
                    print(f"DEBUG: Sending Email to {user.email}: {class_update_message}")
                if broadcast_sms and user.phone:
                    print(f"DEBUG: Sending SMS to {user.phone}: {class_update_message}")

        db.session.commit()
        return jsonify({'status': 'success', 'message': 'Class update message saved successfully.'})
    except Exception:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': 'Failed to save class update message.'}), 500


# 3. The Register Student Route
@teacher_bp.route('/register_student', methods=['GET', 'POST'])
@login_required
@role_required('teacher')
def register_student():
    # If the teacher clicked "Submit" on the registration form
    if request.method == 'POST':
        # Grab the data from the HTML form
        fullname = request.form.get('fullname')
        userid = request.form.get('userid')
        username = request.form.get('username')
        raw_password = request.form.get('password')

        # Check if username or ID already exists to prevent crashes
        existing_user = User.query.filter((User.username == username) | (User.userid == userid)).first()
        if existing_user:
            flash('Username or ID already exists!', 'danger')
            return redirect(url_for('teacher.register_student'))

        # Create the new student safely
        new_student = User(
            role='student', # Force the role to be student so teachers can't create admins
            fullname=fullname,
            userid=userid,
            username=username,
            password=generate_password_hash(raw_password) # Encrypt the password!
        )
        
        # Save to database
        db.session.add(new_student)
        db.session.commit()
        
        flash('Student registered successfully!', 'success')
        return redirect(url_for('teacher.dashboard'))
        
    # If it's a GET request (just visiting the page), show the empty form
    return render_template('register_student.html', portal_role='teacher')


@teacher_bp.route('/settings')
@login_required
@role_required('teacher')
def settings():
    return render_template('teacher_settings.html')


@teacher_bp.route('/create_notice', methods=['POST'])
@login_required
@role_required('teacher')
def create_notice():
    try:
        data = request.get_json()
        content = (data.get('content') or '').strip()
        category = data.get('category', 'Info')
        audience = data.get('audience', 'all')

        if not content:
            return jsonify({'status': 'error', 'message': 'Notice content is required.'}), 400

        user = User.query.get(session.get('user_id'))
        
        # Create notice
        notice = Notice(
            author_name=user.fullname,
            author_role=user.role,
            content=content,
            category=category,
            created_at=datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        )
        
        db.session.add(notice)
        db.session.commit()
        
        return jsonify({'status': 'success', 'message': 'Notice sent successfully!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': f'Failed to send notice: {str(e)}'}), 500


@teacher_bp.route('/pending_approvals')
@login_required
@role_required('teacher')
def pending_approvals():
    pending_students = User.query.filter_by(role='student', is_approved=False).all()
    return render_template('pending_approvals.html', students=pending_students, portal_role='teacher')


@teacher_bp.route('/approve_student/<int:user_id>', methods=['POST'])
@login_required
@role_required('teacher')
def approve_student(user_id):
    user = User.query.get_or_404(user_id)
    user.is_approved = True
    db.session.commit()
    return jsonify({'status': 'success', 'message': f'Student {user.fullname} approved successfully.'})


@teacher_bp.route('/reject_student/<int:user_id>', methods=['POST'])
@login_required
@role_required('teacher')
def reject_student(user_id):
    user = User.query.get_or_404(user_id)
    if not user.is_approved:
        db.session.delete(user)
        db.session.commit()
        return jsonify({'status': 'success', 'message': f'Student {user.fullname} registration rejected.'})
    return jsonify({'status': 'error', 'message': 'Cannot reject already approved student.'}), 400
