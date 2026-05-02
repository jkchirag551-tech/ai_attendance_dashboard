import base64
import json
import numpy as np
import cv2
import face_recognition
from datetime import datetime
from flask import Blueprint, request, jsonify, session
from models import db, Attendance, User
from utils import login_required, role_required

face_bp = Blueprint('face', __name__)

# Global cache for face encodings to avoid DB queries
face_encoding_cache = {}


def decode_image(image_data):
    encoded_data = image_data.split(',')[1]
    nparr = np.frombuffer(base64.b64decode(encoded_data), np.uint8)
    return cv2.imdecode(nparr, cv2.IMREAD_COLOR)


@face_bp.route('/process_frame', methods=['POST'])
@login_required
@role_required('student')
def process_frame():
    data = request.get_json() or {}
    image_data = data.get('image')
    if not image_data:
        return jsonify({'status': 'error', 'message': 'No image data provided.'})

    try:
        img = decode_image(image_data)
        if img is None:
            return jsonify({'status': 'error', 'message': 'Failed to decode image.'})

        # Downscale image for faster processing (reduce to 50% size)
        height, width = img.shape[:2]
        new_width = width // 2
        new_height = height // 2
        img_resized = cv2.resize(img, (new_width, new_height))
        
        rgb_img = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)

        # Use HOG model for faster detection (default is HOG, but specify for clarity)
        face_locations = face_recognition.face_locations(rgb_img, model='hog')
        unknown_encodings = face_recognition.face_encodings(rgb_img, face_locations)

        if len(unknown_encodings) == 0:
            return jsonify({'status': 'error', 'message': 'No face detected in frame.'})

        user_id = session['user_id']
        
        # Check cache first, otherwise load from DB
        if user_id not in face_encoding_cache:
            user = User.query.get(user_id)
            if not user or not user.face_encoding:
                return jsonify({'status': 'error', 'message': 'Please enroll your face before verifying attendance.'})
            face_encoding_cache[user_id] = np.array(json.loads(user.face_encoding))
        
        user_encoding = face_encoding_cache[user_id]
        matches = face_recognition.compare_faces([user_encoding], unknown_encodings[0])
        face_distances = face_recognition.face_distance([user_encoding], unknown_encodings[0])
        match_score = round((1 - face_distances[0]) * 100, 2)

        if matches[0]:
            now = datetime.now()
            date_str = now.strftime('%Y-%m-%d')
            time_str = now.strftime('%I:%M %p')

            # Check if student has already checked in today
            existing_attendance = Attendance.query.filter_by(
                user_id=user_id,
                date=date_str
            ).first()

            if existing_attendance:
                return jsonify({
                    'status': 'error',
                    'message': f'You have already checked in today at {existing_attendance.time}.'
                })

            user = User.query.get(user_id)  # Get user for username
            import os
            import uuid
            filename = f"{uuid.uuid4().hex}.jpg"
            cv2.imwrite(os.path.join('static', 'proofs', filename), img)

            attendance = Attendance(
                user_id=user_id,
                username=user.username,
                subject='General (Web)',
                date=date_str,
                time=time_str,
                match_score=f'{match_score}%',
                status='Verified',
                proof_path=filename
            )
            db.session.add(attendance)
            db.session.commit()

            # Real-time update for web dashboard
            from app import socketio
            socketio.emit('new_checkin', {
                "username": user.username,
                "date": date_str,
                "time": time_str,
                "status": 'Verified',
                "match_score": f'{match_score}%',
                "proof_url": f"/static/proofs/{filename}"
            })

            return jsonify({
                'status': 'success',
                'message': 'Identity Verified!',
                'match_score': f'{match_score}%'
            })

        return jsonify({'status': 'error', 'message': 'Face does not match the enrolled record.'})

    except Exception as e:
        print(f'❌ Error: {e}')
        return jsonify({'status': 'error', 'message': 'Server failed to process image'})


