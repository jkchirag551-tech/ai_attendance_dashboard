from firebase_admin import messaging

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
                icon='ic_launcher'
            ),
        ),
        token=token,
    )
    try:
        response = messaging.send(message)
        print('Successfully sent message:', response)
    except Exception as e:
        print('Error sending message:', e)
