import base64
import json
import numpy as np
import cv2
import face_recognition
from datetime import datetime, timedelta
from flask import Blueprint, render_template, request, jsonify, send_file, session
from sqlalchemy import or_
from werkzeug.security import generate_password_hash
from models import Attendance, User, db, Settings, Notice
from utils import login_required, role_required
from notification_utils import send_push_notification
from export_utils import build_attendance_excel, build_attendance_pdf

admin_bp = Blueprint('admin', __name__)


def get_working_days():
    """Get the configured working days from settings"""
    setting = Settings.query.filter_by(key='working_days').first()
    if setting:
        try:
            return json.loads(setting.value.replace("'", '"'))
        except (json.JSONDecodeError, ValueError):
            try:
                return eval(setting.value)
            except Exception:
                return [0, 1, 2, 3, 4]
    return [0, 1, 2, 3, 4]  # Default: Monday to Friday


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
    """Calculate attendance percentage for the last N days using configured working days"""
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
    
    # Count total working days in the period
    total_days = 0
    current_date = start_date
    while current_date <= end_date:
        if current_date.weekday() in working_days:  # Use configured working days
            total_days += 1
        current_date += timedelta(days=1)
    
    if total_days == 0:
        return 0
    
    # Count unique days present in the period
    attendance_days = db.session.query(db.func.count(db.distinct(Attendance.date))).filter(
        Attendance.user_id == user_id,
        Attendance.date >= start_date.strftime('%Y-%m-%d'),
        Attendance.date <= end_date.strftime('%Y-%m-%d')
    ).scalar() or 0
    
    return round((attendance_days / total_days) * 100, 1)


def get_admin_attendance_query(filter_type, selected_date, search_name, student_id=None):
    records_query = Attendance.query.outerjoin(User, Attendance.user_id == User.id)

    if student_id:
        records_query = records_query.filter(Attendance.user_id == student_id)

    if filter_type == 'day' and selected_date:
        records_query = records_query.filter(Attendance.date == selected_date)
    elif filter_type != 'all':
        filter_type = 'all'

    if search_name:
        search_pattern = f'%{search_name}%'
        records_query = records_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                Attendance.username.ilike(search_pattern),
            )
        )

    return records_query, filter_type


def serialize_attendance_rows(records):
    rows = []
    for record in records:
        rows.append(
            {
                'fullname': record.user.fullname if record.user else record.username,
                'roll_number': record.user.userid if record.user else record.username,
                'subject': record.subject or 'General',
                'date': record.date,
                'time': record.time,
                'match_score': record.match_score,
                'status': record.status,
            }
        )
    return rows


@admin_bp.route('/')
@login_required
@role_required('admin')
def admin_dashboard():
    today = datetime.now().strftime('%Y-%m-%d')
    records = Attendance.query.filter_by(date=today).order_by(Attendance.username.asc(), Attendance.time.asc()).all()
    total_students = User.query.filter_by(role='student').count()
    total_teachers = User.query.filter_by(role='teacher').count()
    total_admins = User.query.filter_by(role='admin').count()
    working_days = get_working_days()
    day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    class_update_message = get_setting_value('class_update_message', '')

    # Monthly attendance for log
    year = datetime.now().year
    monthly_data = []
    for month in range(1, 13):
        month_str = f"{year}-{month:02d}"
        count = Attendance.query.filter(Attendance.date.like(f"{month_str}-%")).count()
        monthly_data.append({"month": month_str, "count": count})

    return render_template(
        'dashboard.html',
        records=records,
        total_students=total_students,
        total_teachers=total_teachers,
        total_admins=total_admins,
        present_today=len(records),
        working_days=working_days,
        day_names=day_names,
        class_update_message=class_update_message,
        monthly_data=monthly_data
    )


@admin_bp.route('/logs')
@login_required
@role_required('admin')
def logs():
    # Monthly attendance for log tab
    year = datetime.now().year
    monthly_data = []
    for month in range(1, 13):
        month_str = f"{year}-{month:02d}"
        count = Attendance.query.filter(Attendance.date.like(f"{month_str}-%")).count()
        monthly_data.append({"month": month_str, "count": count})

    return render_template(
        'logs.html',
        monthly_data=monthly_data
    )


@admin_bp.route('/logs/daily/<month>')
@login_required
@role_required('admin')
def daily_logs(month):
    records = Attendance.query.filter(Attendance.date.like(f"{month}-%")).all()
    daily_counts = {}
    for r in records:
        daily_counts[r.date] = daily_counts.get(r.date, 0) + 1
    
    # Sort dates descending
    sorted_days = sorted(daily_counts.keys(), reverse=True)
    data = [{"date": d, "count": daily_counts[d]} for d in sorted_days]
    
    return render_template('daily_logs.html', month=month, daily_data=data)


@admin_bp.route('/logs/day/<date_str>')
@login_required
@role_required('admin')
def day_students(date_str):
    records = Attendance.query.filter_by(date=date_str).all()
    return render_template('day_students.html', date=date_str, records=records)


@admin_bp.route('/calendar', methods=['GET', 'POST'])
@login_required
def academic_calendar():
    from models import CalendarEvent
    if request.method == 'POST':
        if session.get('role') != 'admin':
            return jsonify({'success': False, 'message': 'Permission denied.'}), 403
        
        date_str = request.form.get('date')
        title = request.form.get('title')
        type = request.form.get('type')
        action = request.form.get('action') # 'save' or 'delete'

        if action == 'delete':
            event = CalendarEvent.query.filter_by(date=date_str).first()
            if event:
                db.session.delete(event)
                db.session.commit()
            return jsonify({'success': True, 'message': 'Event removed'})

        event = CalendarEvent.query.filter_by(date=date_str).first()
        if event:
            event.title = title
            event.type = type
        else:
            db.session.add(CalendarEvent(date=date_str, title=title, type=type))
        
        db.session.commit()
        return jsonify({'success': True, 'message': 'Calendar updated'})

    events = CalendarEvent.query.all()
    events_json = json.dumps([{"date": e.date, "title": e.title, "type": e.type} for e in events])
    return render_template('calendar.html', events_json=events_json, is_admin=(session.get('role') == 'admin'))


@admin_bp.route('/attendance/export/<string:filetype>')
@login_required
@role_required('admin')
def export_attendance(filetype):
    filter_type = request.args.get('filter', 'all')
    selected_date = (request.args.get('date') or '').strip()
    search_name = (request.args.get('search') or '').strip()
    student_id = request.args.get('student_id', type=int)

    records_query, filter_type = get_admin_attendance_query(filter_type, selected_date, search_name, student_id)
    records = records_query.order_by(Attendance.id.desc()).all()
    rows = serialize_attendance_rows(records)

    title = 'Admin Attendance Report'
    filename = 'admin_attendance_report'

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

    return jsonify({'status': 'error', 'message': 'Unsupported export format selected.'}), 400


@admin_bp.route('/students')
@login_required
@role_required('admin')
def student_list():
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

    students = students_query.order_by(User.fullname).all()

    teachers_query = User.query.filter_by(role='teacher')
    admins_query = User.query.filter_by(role='admin')

    if search_name:
        search_pattern = f'%{search_name}%'
        teachers_query = teachers_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                User.userid.ilike(search_pattern),
            )
        )
        admins_query = admins_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                User.userid.ilike(search_pattern),
            )
        )

    teachers = teachers_query.order_by(User.fullname).all()
    admins = admins_query.order_by(User.fullname).all()
    
    # Add attendance percentage to each student
    for student in students:
        student.attendance_percentage = calculate_attendance_percentage(student.id)
    
    return render_template('student_list.html', students=students, teachers=teachers, admins=admins, search_name=search_name)


@admin_bp.route('/pending_approvals')
@login_required
@role_required('admin')
def pending_approvals():
    pending_students = User.query.filter_by(role='student', is_approved=False).all()
    return render_template('pending_approvals.html', students=pending_students, portal_role='admin')


@admin_bp.route('/approve_student/<int:user_id>', methods=['POST'])
@login_required
@role_required('admin')
def approve_student(user_id):
    user = User.query.get_or_404(user_id)
    user.is_approved = True
    db.session.commit()
    
    if user.fcm_token:
        send_push_notification(
            user.fcm_token,
            "Account Approved! 🎊",
            "Welcome to MR. Attendance. Your registration has been approved by the administrator. You can now access your dashboard."
        )

    return jsonify({'status': 'success', 'message': f'Student {user.fullname} approved successfully.'})


@admin_bp.route('/reject_student/<int:user_id>', methods=['POST'])
@login_required
@role_required('admin')
def reject_student(user_id):
    user = User.query.get_or_404(user_id)
    if not user.is_approved:
        db.session.delete(user)
        db.session.commit()
        return jsonify({'status': 'success', 'message': f'Student {user.fullname} registration rejected.'})
    return jsonify({'status': 'error', 'message': 'Cannot reject already approved student here.'}), 400


@admin_bp.route('/student_details/<int:student_id>')
@login_required
@role_required('admin')
def student_details(student_id):
    student = User.query.get_or_404(student_id)
    attendance_count = len(student.attendance_records)
    return jsonify({
        'fullname': student.fullname,
        'attendance_count': attendance_count
    })


@admin_bp.route('/settings')
@login_required
@role_required('admin')
def settings():
    working_days = get_working_days()
    day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    working_day_start_time = get_setting_value('working_day_start_time', '09:00')
    working_day_end_time = get_setting_value('working_day_end_time', '17:00')
    semester_start_date = get_setting_value('semester_start_date', '2026-01-15')
    semester_end_date = get_setting_value('semester_end_date', '2026-06-20')
    class_update_message = get_setting_value('class_update_message', '')
    return render_template(
        'settings.html',
        working_days=working_days,
        day_names=day_names,
        working_day_start_time=working_day_start_time,
        working_day_end_time=working_day_end_time,
        semester_start_date=semester_start_date,
        semester_end_date=semester_end_date,
        class_update_message=class_update_message,
    )


@admin_bp.route('/update_working_days', methods=['POST'])
@login_required
@role_required('admin')
def update_working_days():
    try:
        # Get selected working days from form
        working_days = []
        for i in range(7):  # 0=Monday, 6=Sunday
            if request.form.get(f'day_{i}'):
                working_days.append(i)
        class_update_message = (request.form.get('class_update_message') or '').strip()
        working_day_start_time = (request.form.get('working_day_start_time') or '').strip()
        working_day_end_time = (request.form.get('working_day_end_time') or '').strip()
        semester_start_date = (request.form.get('semester_start_date') or '').strip()
        semester_end_date = (request.form.get('semester_end_date') or '').strip()

        if not working_day_start_time or not working_day_end_time:
            return jsonify({'success': False, 'message': 'Please select both working day start and end times.'}), 400

        if working_day_start_time >= working_day_end_time:
            return jsonify({'success': False, 'message': 'Working day end time must be later than start time.'}), 400

        if not semester_start_date or not semester_end_date:
            return jsonify({'success': False, 'message': 'Please select both semester start and end dates.'}), 400

        if semester_start_date > semester_end_date:
            return jsonify({'success': False, 'message': 'Semester end date must be on or after the start date.'}), 400

        set_setting_value('class_update_message', class_update_message)
        set_setting_value('working_day_start_time', working_day_start_time)
        set_setting_value('working_day_end_time', working_day_end_time)
        set_setting_value('semester_start_date', semester_start_date)
        set_setting_value('semester_end_date', semester_end_date)
        set_setting_value('class_update_updated_at', datetime.now().strftime('%Y-%m-%d %I:%M %p'))

        # Broadcast logic
        broadcast_email = request.form.get('broadcast_email') == '1'
        broadcast_sms = request.form.get('broadcast_sms') == '1'
        broadcast_push = request.form.get('broadcast_push') == '1'
        if (broadcast_email or broadcast_sms or broadcast_push) and class_update_message:
            recipients = User.query.filter(User.role.in_(['student', 'teacher'])).all()
            for user in recipients:
                if broadcast_push and user.fcm_token:
                    send_push_notification(
                        user.fcm_token,
                        "Schedule Update 📅",
                        class_update_message
                    )
                if broadcast_email and user.email:
                    print(f"DEBUG: Sending Email to {user.email}: {class_update_message}")
                if broadcast_sms and user.phone:
                    print(f"DEBUG: Sending SMS to {user.phone}: {class_update_message}")

        db.session.commit()
        set_setting_value('semester_start_date', semester_start_date)
        set_setting_value('semester_end_date', semester_end_date)
        set_setting_value('class_update_updated_at', datetime.now().strftime('%Y-%m-%d %I:%M %p'))
        
        db.session.commit()
        return jsonify({'success': True, 'message': 'Working days, schedule, and class update saved successfully'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


@admin_bp.route('/test_push/<int:user_id>', methods=['POST'])
@login_required
@role_required('admin')
def test_push(user_id):
    user = User.query.get_or_404(user_id)
    if not user.fcm_token:
        return jsonify({'status': 'error', 'message': f'No notification token found for {user.fullname}. Make sure they have logged into the mobile app at least once.'}), 400
    
    send_push_notification(
        user.fcm_token,
        "System Test 🟢",
        f"Hello {user.fullname}, this is a high-priority test message to verify background notifications are working correctly."
    )
    return jsonify({'status': 'success', 'message': f'Test notification sent to {user.fullname}.'})

@admin_bp.route('/test_all_notifications', methods=['POST'])
@login_required
@role_required('admin')
def test_all_notifications():
    """Triggers both Socket.io (Dashboard) and Push Notification (Mobile)"""
    from app import socketio
    
    # 1. Update Dashboard
    socketio.emit('new_checkin', {
        "username": "System Test",
        "date": datetime.now().strftime('%Y-%m-%d'),
        "time": datetime.now().strftime('%I:%M %p'),
        "status": 'Verified',
        "proof_url": ""
    })
    
    # 2. Send Push Notification to self
    user = User.query.get(session.get('user_id'))
    debug_info = ""
    pushed = False
    
    if not user:
        debug_info = "User not found in session."
    elif not user.fcm_token:
        debug_info = f"No FCM token found for {user.username}. Please log in via the mobile app first."
    else:
        try:
            send_push_notification(
                user.fcm_token,
                "System Test 🧪",
                "Your mobile notification bridge is working perfectly!"
            )
            pushed = True
            debug_info = f"Sent to token: {user.fcm_token[:10]}..."
        except Exception as e:
            debug_info = f"FCM Error: {str(e)}"
            
    return jsonify({
        'status': 'success', 
        'message': 'Dashboard feed updated',
        'pushed': pushed,
        'debug': debug_info
    })


@admin_bp.route('/delete_student/<int:student_id>', methods=['POST'])
@login_required
@role_required('admin')
def delete_student(student_id):
    student = User.query.get_or_404(student_id)
    
    # Ensure only students can be deleted (not admins)
    if student.role != 'admin':
        attendance_count = len(student.attendance_records)
        student_fullname = student.fullname
        try:
            db.session.delete(student)
            db.session.commit()
            return jsonify({
                'status': 'success', 
                'message': f'Student {student_fullname} and {attendance_count} attendance record(s) deleted successfully.'
            })
        except Exception as e:
            db.session.rollback()
            return jsonify({'status': 'error', 'message': 'Failed to delete student.'}), 500
    else:
        return jsonify({'status': 'error', 'message': 'Cannot delete admin users.'}), 400


@admin_bp.route('/reset_password/<int:user_id>', methods=['POST'])
@login_required
@role_required('admin')
def reset_password(user_id):
    user = User.query.get_or_404(user_id)
    data = request.get_json(silent=True) or {}
    new_password = (data.get('password') or '').strip()

    if len(new_password) < 4:
        return jsonify({'status': 'error', 'message': 'Password must be at least 4 characters long.'}), 400

    try:
        user.password = generate_password_hash(new_password)
        db.session.commit()
        return jsonify({
            'status': 'success',
            'message': f'Password updated successfully for {user.fullname}.'
        })
    except Exception:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': 'Failed to reset password.'}), 500


@admin_bp.route('/register_student', methods=['GET', 'POST'])
@login_required
@role_required('admin')
def register_student():
    message = None
    error = None

    if request.method == 'POST':
        role = request.form.get('role', 'student')
        fullname = request.form.get('fullname')
        userid = request.form.get('userid')
        username = request.form.get('username')
        password = request.form.get('password')
        email = request.form.get('email')
        phone = request.form.get('phone')
        image_data = request.form.get('image')

        if role not in ('student', 'teacher', 'admin'):
            error = 'Please select a valid role.'
        elif not fullname or not userid or not username or not password or not email or not phone:
            error = 'All fields (Full Name, ID, Username, Password, Email, and Phone) are required.'
        elif role == 'student' and not image_data:
            error = 'A face image is required for student registration.'
        else:
            try:
                face_encoding = None

                if role == 'student':
                    encoded_data = image_data.split(',')[1]
                    nparr = None
                    try:
                        nparr = np.frombuffer(base64.b64decode(encoded_data), np.uint8)
                    except Exception:
                        raise ValueError('Invalid image data.')

                    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                    if img is None:
                        error = 'Failed to decode image.'
                    else:
                        rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                        face_locations = face_recognition.face_locations(rgb_img)
                        unknown_encodings = face_recognition.face_encodings(rgb_img, face_locations)

                        if len(unknown_encodings) != 1:
                            error = 'Please provide exactly one clear face image for registration.'
                        else:
                            candidate_encoding = unknown_encodings[0]

                            # Prevent the same face from being registered to a second account
                            # because the current system stores one role per user.
                            existing_users = User.query.filter(User.face_encoding.isnot(None)).all()
                            for existing_user in existing_users:
                                existing_encoding = np.array(json.loads(existing_user.face_encoding))
                                is_match = face_recognition.compare_faces(
                                    [existing_encoding],
                                    candidate_encoding,
                                    tolerance=0.45,
                                )[0]
                                if is_match:
                                    error = (
                                        f'This face is already registered for '
                                        f'{existing_user.fullname} ({existing_user.role}). '
                                        'The current system does not support assigning multiple roles to the same face.'
                                    )
                                    break

                            if not error:
                                face_encoding = json.dumps(candidate_encoding.tolist())

                if not error:
                    user = User(
                        role=role,
                        fullname=fullname,
                        userid=userid,
                        username=username,
                        password=generate_password_hash(password),
                        email=email,
                        phone=phone,
                        face_encoding=face_encoding,
                    )
                    db.session.add(user)
                    db.session.commit()
                    if role == 'student':
                        message = 'Student registered and face encoded successfully.'
                    elif role == 'teacher':
                        message = 'Teacher account created successfully.'
                    else:
                        message = 'Admin account created successfully.'
            except Exception as ex:
                db.session.rollback()
                error = str(ex) if isinstance(ex, ValueError) else f'Failed to register {role}. Username may already exist.'

    return render_template(
        'register_student.html',
        message=message,
        error=error,
        portal_role='admin'
    )


@admin_bp.route('/create_notice', methods=['POST'])
@login_required
@role_required('admin')
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

        # Send push notifications
        title = f"New Notice from Admin: {category}"
        
        target_roles = []
        if audience == 'all':
            target_roles = ['student', 'teacher']
        elif audience == 'students' or audience == 'student':
            target_roles = ['student']
        elif audience == 'teachers' or audience == 'teacher':
            target_roles = ['teacher']

        recipients = User.query.filter(User.role.in_(target_roles), User.fcm_token.isnot(None)).all()
        for recipient in recipients:
            send_push_notification(
                recipient.fcm_token,
                title,
                content
            )
        
        return jsonify({'status': 'success', 'message': 'Notice created successfully and notifications sent!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': f'Failed to create notice: {str(e)}'}), 500


@admin_bp.route('/all_results')
@login_required
@role_required('admin')
def all_results():
    search_name = (request.args.get('search') or '').strip()
    records_query = Attendance.query.outerjoin(User, Attendance.user_id == User.id)

    if search_name:
        search_pattern = f'%{search_name}%'
        records_query = records_query.filter(
            or_(
                User.fullname.ilike(search_pattern),
                User.username.ilike(search_pattern),
                Attendance.username.ilike(search_pattern),
            )
        )

    records = records_query.order_by(Attendance.date.desc(), Attendance.time.desc()).all()
    return render_template('all_results.html', records=records, search_name=search_name)


@admin_bp.route('/generate_dummy_data', methods=['POST'])
@login_required
@role_required('admin')
def generate_dummy_data():
    try:
        # 10 Dummy Students
        students_data = [
            ("Aarav Sharma", "STU101", "aarav101"),
            ("Vihaan Gupta", "STU102", "vihaan102"),
            ("Aditi Verma", "STU103", "aditi103"),
            ("Ananya Iyer", "STU104", "ananya104"),
            ("Ishaan Malhotra", "STU105", "ishaan105"),
            ("Saanvi Reddy", "STU106", "saanvi106"),
            ("Arjun Nair", "STU107", "arjun107"),
            ("Kyra Kapoor", "STU108", "kyra108"),
            ("Rohan Joshi", "STU109", "rohan109"),
            ("Myra Singh", "STU110", "myra110"),
        ]

        for fullname, userid, username in students_data:
            if not User.query.filter_by(username=username).first():
                user = User(
                    role='student',
                    fullname=fullname,
                    userid=userid,
                    username=username,
                    password=generate_password_hash('Student@123'),
                    email=f"{username}@example.com",
                    phone="9876543210",
                    is_approved=True
                )
                db.session.add(user)

        # 2 Dummy Teachers
        teachers_data = [
            ("Dr. Rajesh Kumar", "TEA201", "rajesh201"),
            ("Prof. Sneha Patil", "TEA202", "sneha202"),
        ]

        for fullname, userid, username in teachers_data:
            if not User.query.filter_by(username=username).first():
                user = User(
                    role='teacher',
                    fullname=fullname,
                    userid=userid,
                    username=username,
                    password=generate_password_hash('Teacher@123'),
                    email=f"{username}@example.com",
                    phone="9123456789",
                    is_approved=True
                )
                db.session.add(user)

        db.session.commit()
        return jsonify({'status': 'success', 'message': '10 Students and 2 Teachers added successfully!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500
