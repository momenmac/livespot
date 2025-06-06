#!/usr/bin/env python3
"""
Comprehensive Firebase Notification Test Script
Sends different types of notifications to test the complete notification system
"""

import firebase_admin
from firebase_admin import credentials, messaging
import json
import time
from datetime import datetime, timedelta
import argparse

# Initialize Firebase Admin SDK
SERVICE_ACCOUNT_PATH = "server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json"

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Check if Firebase is already initialized
        firebase_admin.get_app()
        print("✅ Firebase already initialized")
    except ValueError:
        # Initialize Firebase
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin SDK initialized")

def send_notification(token, notification_type, **kwargs):
    """Send a notification based on type"""
    
    notifications = {
        'friend_request': {
            'title': 'Friend Request',
            'body': f'{kwargs.get("from_name", "John Doe")} wants to be your friend',
            'data': {
                'type': 'friend_request',
                'fromUserId': kwargs.get('from_user_id', 'user_123'),
                'fromUserName': kwargs.get('from_name', 'John Doe'),
                'fromUserAvatar': kwargs.get('from_avatar', 'https://via.placeholder.com/100'),
                'requestId': kwargs.get('request_id', f'req_{int(time.time())}'),
            }
        },
        
        'friend_request_accepted': {
            'title': 'Friend Request Accepted',
            'body': f'{kwargs.get("from_name", "Jane Smith")} accepted your friend request! 🎉',
            'data': {
                'type': 'friend_request_accepted',
                'fromUserId': kwargs.get('from_user_id', 'user_456'),
                'fromUserName': kwargs.get('from_name', 'Jane Smith'),
                'fromUserAvatar': kwargs.get('from_avatar', 'https://via.placeholder.com/100'),
            }
        },
        
        'new_event': {
            'title': 'New Event Nearby',
            'body': f'{kwargs.get("event_title", "Coffee Meetup")} is happening near you',
            'data': {
                'type': 'new_event',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Coffee Meetup'),
                'eventDescription': kwargs.get('event_description', 'Join us for coffee and networking'),
                'eventLocation': kwargs.get('event_location', 'Central Park Cafe'),
                'eventImageUrl': kwargs.get('event_image', 'https://via.placeholder.com/300x200'),
                'eventDate': kwargs.get('event_date', (datetime.now() + timedelta(hours=2)).isoformat()),
                'creatorUserId': kwargs.get('creator_id', 'creator_123'),
                'creatorUserName': kwargs.get('creator_name', 'Event Organizer'),
            }
        },
        
        'still_there': {
            'title': 'Still There?',
            'body': f'Is {kwargs.get("event_title", "the event")} still happening?',
            'data': {
                'type': 'still_there',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Coffee Meetup'),
                'eventImageUrl': kwargs.get('event_image', 'https://via.placeholder.com/300x200'),
                'confirmationId': kwargs.get('confirmation_id', f'conf_{int(time.time())}'),
                'originalEventDate': kwargs.get('original_date', (datetime.now() - timedelta(hours=1)).isoformat()),
            }
        },
        
        'event_update': {
            'title': 'Event Updated',
            'body': f'{kwargs.get("event_title", "Your event")} has been updated',
            'data': {
                'type': 'event_update',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Updated Coffee Meetup'),
                'updateType': kwargs.get('update_type', 'location_changed'),
                'updateMessage': kwargs.get('update_message', 'Event location has been changed'),
            }
        },
        
        'event_cancelled': {
            'title': 'Event Cancelled',
            'body': f'{kwargs.get("event_title", "Your event")} has been cancelled',
            'data': {
                'type': 'event_cancelled',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Coffee Meetup'),
                'cancellationReason': kwargs.get('reason', 'Weather conditions'),
                'refundInfo': kwargs.get('refund_info', 'Refunds will be processed within 3-5 business days'),
            }
        },
        
        'nearby_event': {
            'title': 'Event Nearby',
            'body': f'{kwargs.get("event_title", "Interesting event")} is happening near you',
            'data': {
                'type': 'nearby_event',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Local Art Exhibition'),
                'eventLocation': kwargs.get('event_location', 'Downtown Gallery'),
                'distance': kwargs.get('distance', '0.5 km'),
                'eventImageUrl': kwargs.get('event_image', 'https://via.placeholder.com/300x200'),
            }
        },
        
        'reminder': {
            'title': 'Event Reminder',
            'body': f'{kwargs.get("event_title", "Your event")} starts in {kwargs.get("time_until", "30 minutes")}',
            'data': {
                'type': 'reminder',
                'eventId': kwargs.get('event_id', f'event_{int(time.time())}'),
                'eventTitle': kwargs.get('event_title', 'Coffee Meetup'),
                'reminderType': kwargs.get('reminder_type', 'event_starting'),
                'timeUntil': kwargs.get('time_until', '30 minutes'),
                'eventLocation': kwargs.get('event_location', 'Central Park Cafe'),
            }
        },
        
        'system': {
            'title': kwargs.get('title', 'System Notification'),
            'body': kwargs.get('message', 'Important system update available'),
            'data': {
                'type': 'system',
                'notificationType': kwargs.get('notification_type', 'app_update'),
                'message': kwargs.get('message', 'Important system update available'),
                'actionUrl': kwargs.get('action_url', 'https://app.livespot.com/update'),
                'priority': kwargs.get('priority', 'high'),
            }
        }
    }
    
    if notification_type not in notifications:
        print(f"❌ Unknown notification type: {notification_type}")
        return False
    
    notification_config = notifications[notification_type]
    
    # Create the message
    message = messaging.Message(
        notification=messaging.Notification(
            title=notification_config['title'],
            body=notification_config['body']
        ),
        data=notification_config['data'],        token=token,
        android=messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                channel_id='high_importance_channel',
                priority='high',
                default_vibrate_timings=True,
                default_sound=True,
            )
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=notification_config['title'],
                        body=notification_config['body']
                    ),
                    badge=1,
                    sound='default'
                )
            )
        )
    )
    
    try:
        response = messaging.send(message)
        print(f"✅ {notification_type.replace('_', ' ').title()} notification sent successfully!")
        print(f"📱 Message ID: {response}")
        print(f"📄 Title: {notification_config['title']}")
        print(f"📝 Body: {notification_config['body']}")
        print(f"🔧 Data: {json.dumps(notification_config['data'], indent=2)}")
        return True
    except Exception as e:
        print(f"❌ Failed to send {notification_type} notification: {str(e)}")
        return False

def test_all_notifications(token):
    """Send all types of notifications for comprehensive testing"""
    print("🚀 Starting comprehensive notification testing...")
    print("=" * 60)
    
    # Test scenarios with custom data
    test_scenarios = [
        ('friend_request', {
            'from_name': 'Alex Johnson',
            'from_user_id': 'user_alex_123',
            'from_avatar': 'https://randomuser.me/api/portraits/men/32.jpg'
        }),
        
        ('friend_request_accepted', {
            'from_name': 'Sarah Wilson',
            'from_user_id': 'user_sarah_456'
        }),
        
        ('new_event', {
            'event_title': 'Tech Meetup 2025',
            'event_description': 'Join us for the latest in tech innovation',
            'event_location': 'Innovation Hub, Downtown',
            'creator_name': 'TechCorp Events'
        }),
        
        ('still_there', {
            'event_title': 'Morning Yoga Class',
            'event_id': 'yoga_event_123'
        }),
        
        ('event_update', {
            'event_title': 'Beach Volleyball Tournament',
            'update_type': 'time_changed',
            'update_message': 'Start time moved to 3:00 PM due to weather'
        }),
        
        ('event_cancelled', {
            'event_title': 'Outdoor Concert',
            'reason': 'Severe weather warning',
            'refund_info': 'Full refunds available until next Friday'
        }),
        
        ('nearby_event', {
            'event_title': 'Food Truck Festival',
            'event_location': 'City Square',
            'distance': '0.3 km'
        }),
        
        ('reminder', {
            'event_title': 'Business Networking Lunch',
            'time_until': '15 minutes',
            'event_location': 'Grand Hotel Conference Room'
        }),
        
        ('system', {
            'title': 'App Update Available',
            'message': 'New features and bug fixes are ready to install',
            'notification_type': 'app_update'
        })    ]
    
    successful = 0
    total = len(test_scenarios)
    
    for i, (notification_type, kwargs) in enumerate(test_scenarios, 1):
        print(f"\n📱 Test {i}/{total}: {notification_type.replace('_', ' ').title()}")
        print("-" * 40)
        
        # Remove notification_type from kwargs to avoid duplicate parameter
        clean_kwargs = {k: v for k, v in kwargs.items() if k != 'notification_type'}
        if send_notification(token, notification_type, **clean_kwargs):
            successful += 1
        
        # Wait between notifications to avoid rate limiting
        if i < total:
            print("⏱️ Waiting 3 seconds before next notification...")
            time.sleep(3)
    
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {successful}/{total} notifications sent successfully")
    
    if successful == total:
        print("🎉 All notifications sent successfully!")
        print("📱 Check your device to see each notification type in action")
    else:
        print(f"⚠️ {total - successful} notifications failed to send")
    
    return successful == total

def main():
    parser = argparse.ArgumentParser(description='Test Firebase Notifications')
    parser.add_argument('--token', required=True, help='FCM device token')
    parser.add_argument('--type', help='Specific notification type to test')
    parser.add_argument('--all', action='store_true', help='Test all notification types')
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    
    if args.all or not args.type:
        # Test all notification types
        test_all_notifications(args.token)
    else:
        # Test specific notification type
        print(f"🧪 Testing {args.type} notification...")
        success = send_notification(args.token, args.type)
        if success:
            print("✅ Test completed successfully!")
        else:
            print("❌ Test failed!")

if __name__ == "__main__":
    main()
