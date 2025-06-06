#!/usr/bin/env python3
"""
Test script to send a "still there" notification to test the action confirmation dialog.
"""

import json
import firebase_admin
from firebase_admin import credentials, messaging
import sys
import os

# Add the server directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'server'))

#!/usr/bin/env python3
"""
Test script to send a "still there" notification to test the action confirmation dialog.
"""

import json
import firebase_admin
from firebase_admin import credentials, messaging
import sys
import os

def send_still_there_notification(token=None, topic=None):
    """Send a test 'still there' notification"""
    
    try:
        # Initialize Firebase Admin SDK
        service_account_path = os.path.join(os.path.dirname(__file__), 'server', 'livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json')
        
        print(f"🔑 Looking for service account file at: {service_account_path}")
        print(f"🔍 File exists: {os.path.exists(service_account_path)}")
        
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized successfully")
        else:
            print("✅ Firebase Admin SDK already initialized")
        
        # Create the notification message
        notification_data = {
            'type': 'still_there',
            'action_type': 'still_there',
            'dialog_title': 'Action Confirmation',
            'dialog_description': 'We noticed you reported an action here. Is this action still ongoing?',
            'dialog_image_url': 'https://via.placeholder.com/300x200/FF6B6B/FFFFFF?text=Action+Still+There%3F',
            'action_id': '12345',
            'post_id': '67890'
        }
        
        print(f"📝 Notification data: {json.dumps(notification_data, indent=2)}")
        
        # Create the message
        if token:
            # Send to specific device token
            print(f"📱 Sending to device token: {token[:50]}...")
            message = messaging.Message(
                notification=messaging.Notification(
                    title='Still There?',
                    body='Is this action still happening?'
                ),
                data=notification_data,
                token=token,
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(
                        click_action='FLUTTER_NOTIFICATION_CLICK',
                        channel_id='high_importance_channel'
                    )
                )
            )
            
            response = messaging.send(message)
            print(f'✅ Successfully sent notification to token: {response}')
            
        elif topic:
            # Send to topic
            print(f"📢 Sending to topic: {topic}")
            message = messaging.Message(
                notification=messaging.Notification(
                    title='Still There?',
                    body='Is this action still happening?'
                ),
                data=notification_data,
                topic=topic,
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(
                        click_action='FLUTTER_NOTIFICATION_CLICK',
                        channel_id='high_importance_channel'
                    )
                )
            )
            
            response = messaging.send(message)
            print(f'✅ Successfully sent notification to topic "{topic}": {response}')
        
        else:
            print('❌ Please provide either --token or --topic')
            return False
            
        return True
        
    except Exception as e:
        print(f"❌ Error sending notification: {str(e)}")
        print(f"❌ Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Send test "still there" notification')
    parser.add_argument('--token', help='FCM device token')
    parser.add_argument('--topic', help='FCM topic name', default='test_notifications')
    
    args = parser.parse_args()
    
    if args.token:
        send_still_there_notification(token=args.token)
    else:
        send_still_there_notification(topic=args.topic)
