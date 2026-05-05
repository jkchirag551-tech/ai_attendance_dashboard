from firebase_admin import messaging

def send_push_notification(token, title, body):
    if not token:
        return
    
    # Define the notification message
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        android=messaging.AndroidConfig(
            priority='high',  # High delivery priority (wakes up device)
            notification=messaging.AndroidNotification(
                channel_id='high_importance_channel',
                priority='high', # High priority for heads-up popup
                icon='ic_launcher',
                default_sound=True,
                default_vibrate_timings=True,
                visibility='public',
                click_action='FLUTTER_NOTIFICATION_CLICK'
            ),
        ),
        data={
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'notice',
            'title': title,
            'body': body
        },
        token=token,
    )

    try:
        response = messaging.send(message)
        print('Successfully sent message:', response)
        return response
    except Exception as e:
        print('Error sending message:', e)
        return None
