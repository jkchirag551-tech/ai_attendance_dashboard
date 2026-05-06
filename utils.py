from functools import wraps
from flask import redirect, url_for, session, request


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'username' not in session:
            if request.path.startswith('/admin'):
                return redirect(url_for('auth.admin_portal_login'))
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


def role_required(role):
    def wrapper(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if session.get('role') != role:
                if request.path.startswith('/admin') or role == 'admin':
                    return redirect(url_for('auth.admin_portal_login'))
                return redirect(url_for('auth.login'))
            return f(*args, **kwargs)
        return decorated_function
    return wrapper
