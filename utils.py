from functools import wraps
from flask import redirect, url_for, session, request


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'username' not in session:
            # If accessing an admin route, send to admin login
            if request.path.startswith('/admin') or (request.blueprint and 'admin' in request.blueprint):
                return redirect(url_for('auth.admin_portal_login'))
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


def role_required(role):
    def wrapper(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if session.get('role') != role:
                # If an admin is required or we are on an admin path, send to admin login
                if role == 'admin' or request.path.startswith('/admin') or (request.blueprint and 'admin' in request.blueprint):
                    return redirect(url_for('auth.admin_portal_login'))
                return redirect(url_for('auth.login'))
            return f(*args, **kwargs)
        return decorated_function
    return wrapper
