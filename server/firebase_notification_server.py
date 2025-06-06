#!/usr/bin/env python3
"""
Firebase Push Notification Server Script
This script demonstrates how to send push notifications using Firebase Admin SDK.

Requirements:
- pip install firebase-admin requests
- Firebase service account key file
"""

import json
import sys
import argparse
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, messaging

class FirebaseNotificationServer:
    def __init__(self, service_account_path):
        """Initialize Firebase Admin SDK"""
        try:
            # Initialize Firebase Admin SDK
            cred = credentials.Certificate(service_account_path)
            self.app = firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized successfully")
        except Exception as e:
            print(f"❌ Error initializing Firebase Admin SDK: {e}")
            sys.exit(1)

    def send_notification_to_token(self, token, title, body, data=None):
        """Send notification to a specific FCM token"""
        try:
            # Create the message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='high_importance_channel',
                        sound='default',
                        default_sound=True,
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound='default',
                            badge=1,
                        ),
                    ),
                ),
            )

            # Send the message
            response = messaging.send(message)
            print(f"✅ Notification sent successfully. Message ID: {response}")
            return response
        except Exception as e:
            print(f"❌ Error sending notification: {e}")
            return None

    def send_notification_to_topic(self, topic, title, body, data=None):
        """Send notification to a topic"""
        try:
            # Create the message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                topic=topic,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='high_importance_channel',
                        sound='default',
                        default_sound=True,
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound='default',
                            badge=1,
                        ),
                    ),
                ),
            )

            # Send the message
            response = messaging.send(message)
            print(f"✅ Topic notification sent successfully. Message ID: {response}")
            return response
        except Exception as e:
            print(f"❌ Error sending topic notification: {e}")
            return None

    def send_multicast_notification(self, tokens, title, body, data=None):
        """Send notification to multiple tokens"""
        try:
            # Create the message
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                tokens=tokens,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='high_importance_channel',
                        sound='default',
                        default_sound=True,
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound='default',
                            badge=1,
                        ),
                    ),
                ),
            )

            # Send the message
            response = messaging.send_multicast(message)
            print(f"✅ Multicast notification sent. Success: {response.success_count}, Failure: {response.failure_count}")
            
            # Print any failures
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    print(f"❌ Failed to send to token {idx}: {resp.exception}")
            
            return response
        except Exception as e:
            print(f"❌ Error sending multicast notification: {e}")
            return None

def main():
    parser = argparse.ArgumentParser(description='Firebase Push Notification Server')
    parser.add_argument('--service-account', required=True, help='Path to Firebase service account JSON file')
    parser.add_argument('--token', help='FCM token to send notification to')
    parser.add_argument('--topic', help='Topic to send notification to')
    parser.add_argument('--tokens-file', help='JSON file containing array of FCM tokens')
    parser.add_argument('--title', default='Test Notification', help='Notification title')
    parser.add_argument('--body', default='This is a test notification from Firebase!', help='Notification body')
    parser.add_argument('--data', help='JSON string of additional data to send with notification')

    args = parser.parse_args()

    # Initialize Firebase server
    server = FirebaseNotificationServer(args.service_account)

    # Parse additional data if provided
    data = None
    if args.data:
        try:
            data = json.loads(args.data)
        except json.JSONDecodeError:
            print("❌ Invalid JSON format for --data argument")
            sys.exit(1)

    # Add timestamp to data
    if data is None:
        data = {}
    data['timestamp'] = datetime.now().isoformat()
    data['route'] = '/notifications'  # Example route for navigation

    if args.token:
        # Send to specific token
        print(f"📱 Sending notification to token: {args.token[:20]}...")
        server.send_notification_to_token(args.token, args.title, args.body, data)
    
    elif args.topic:
        # Send to topic
        print(f"📢 Sending notification to topic: {args.topic}")
        server.send_notification_to_topic(args.topic, args.title, args.body, data)
    
    elif args.tokens_file:
        # Send to multiple tokens
        try:
            with open(args.tokens_file, 'r') as f:
                tokens = json.load(f)
            print(f"📱 Sending notification to {len(tokens)} tokens")
            server.send_multicast_notification(tokens, args.title, args.body, data)
        except Exception as e:
            print(f"❌ Error reading tokens file: {e}")
            sys.exit(1)
    
    else:
        print("❌ Please provide either --token, --topic, or --tokens-file")
        sys.exit(1)

if __name__ == "__main__":
    main()
