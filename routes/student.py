import json
from datetime import datetime, timedelta
from flask import Blueprint, render_template, session, send_file, flash, redirect
from sqlalchemy import or_
from models import Attendance, User, Settings
from utils import login_required, role_required
from export_utils import build_attendance_excel, build_attendance_pdf

student_bp = Blueprint('student', __name__)


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
    
    # Count attendance records in the period
    user = User.query.get(user_id)
    if not user:
        return 0

    attendance_count = Attendance.query.filter(
        or_(
            Attendance.user_id == user_id,
            Attendance.username == user.username,
        ),
        Attendance.date >= start_date.strftime('%Y-%m-%d'),
        Attendance.date <= end_date.strftime('%Y-%m-%d')
    ).count()
    
    return round((attendance_count / total_days) * 100, 1)


def serialize_student_attendance(records, fullname, roll_number):
    return [
        {
            'fullname': fullname,
            'roll_number': roll_number,
            'date': record.date,
            'time': record.time,
            'match_score': record.match_score,
            'status': record.status,
        }
        for record in records
    ]


@student_bp.route('/student')
@login_required
@role_required('student')
def student_dashboard():
    today = datetime.now().strftime('%Y-%m-%d')
    user = User.query.get(session['user_id'])
    enrolled = bool(user and user.face_encoding)
    attendance_records = Attendance.query.filter_by(username=session['username']).order_by(Attendance.id.desc()).limit(10).all()
    today_count = Attendance.query.filter_by(username=session['username'], date=today).count()

    attendance_status = 'Present Today' if today_count else 'Absent Today'
    attendance_percentage = calculate_attendance_percentage(user.id) if user else 0
    
    # Calculate total working days and present days
    today_date = datetime.now().date()
    semester_start = get_setting_value('semester_start_date')
    working_days_indices = get_working_days()
    total_working_days = 0
    if semester_start:
        try:
            start_date = datetime.strptime(semester_start, '%Y-%m-%d').date()
            curr = start_date
            while curr <= today_date:
                if curr.weekday() in working_days_indices:
                    total_working_days += 1
                curr += timedelta(days=1)
        except:
            total_working_days = 20
    else:
        total_working_days = 20
        
    total_days_present = len(set([l.date for l in Attendance.query.filter_by(username=session['username']).all()]))

    day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    working_days = [day_names[i] for i in get_working_days()]
    class_update_message = get_setting_value('class_update_message', '')
    class_update_updated_at = get_setting_value('class_update_updated_at', '')
    
    return render_template(
        'student_dashboard.html',
        fullname=session.get('fullname'),
        attendance_records=attendance_records,
        attendance_status=attendance_status,
        enrolled=enrolled,
        attendance_percentage=attendance_percentage,
        total_days_present=total_days_present,
        total_working_days=total_working_days,
        working_days=working_days,
        class_update_message=class_update_message,
        class_update_updated_at=class_update_updated_at
    )


@student_bp.route('/student/attendance/export/<string:filetype>')
@login_required
@role_required('student')
def export_student_attendance(filetype):
    user = User.query.get(session['user_id'])
    if not user:
        flash('Student record not found.', 'danger')
        return redirect('/student')

    attendance_records = Attendance.query.filter(
        or_(
            Attendance.user_id == user.id,
            Attendance.username == user.username,
        )
    ).order_by(Attendance.id.desc()).all()
    rows = serialize_student_attendance(attendance_records, user.fullname, user.userid)
    title = f'{user.fullname} Attendance Report'
    filename = f'attendance_{user.fullname.replace(" ", "_")}'

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
    return redirect('/student')


@student_bp.route('/capture')
@login_required
@role_required('student')
def capture():
    user = User.query.get(session['user_id'])
    enrolled = bool(user and user.face_encoding)
    
    # Check if student has already checked in today
    today = datetime.now().strftime('%Y-%m-%d')
    today_attendance = Attendance.query.filter_by(
        user_id=user.id,
        date=today
    ).first() if user else None
    
    already_checked_in = today_attendance is not None
    checkin_time = today_attendance.time if today_attendance else None
    
    return render_template(
        'capture.html', 
        enrolled=enrolled,
        already_checked_in=already_checked_in,
        checkin_time=checkin_time
    )
