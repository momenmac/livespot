#!/usr/bin/env python3
"""
Final End-to-End Test for Message Notifications

This script tests the complete message notification flow:
1. Authentication with Django backend
2. FCM token registration 
3. Sending a message notification via Django backend
4. Verifying the notification was sent

Run this script after starting the Django server to verify everything works.
"""

import requests
import json
import time
from typing import Dict, Any, Optional

# Configuration
BASE_URL = "http://localhost:8000"
TEST_USERS = [
    {
        "email": "ahmed.khatib@example.com",
        "password": "password123"
    },
    {
        "email": "leila.awad@example.com", 
        "password": "password123"
    }
]

class MessageNotificationTester:
    def __init__(self):
        self.base_url = BASE_URL
        self.session = requests.Session()
        self.auth_tokens = {}
        self.user_data = {}
        
    def authenticate_user(self, email: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user and return token data"""
        try:
            response = self.session.post(
                f"{self.base_url}/api/accounts/auth/login/",
                json={
                    "email": email,
                    "password": password
                },
                headers={'Content-Type': 'application/json'}
            )
            
            print(f"Login response for {email}: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"Login successful for {email}")
                return data
            else:
                print(f"Login failed for {email}: {response.text}")
                return None
                
        except Exception as e:
            print(f"Error authenticating {email}: {e}")
            return None
    
    def register_fcm_token(self, email: str, token: str, fcm_token: str) -> bool:
        """Register FCM token for user"""
        try:
            response = self.session.post(
                f"{self.base_url}/api/accounts/fcm-token/",
                json={"token": fcm_token},
                headers={
                    'Authorization': f'Bearer {token}',
                    'Content-Type': 'application/json'
                }
            )
            
            print(f"FCM token registration for {email}: {response.status_code}")
            
            if response.status_code in [200, 201]:
                print(f"✅ FCM token registered for {email}")
                return True
            else:
                print(f"❌ FCM token registration failed for {email}: {response.text}")
                return False
                
        except Exception as e:
            print(f"Error registering FCM token for {email}: {e}")
            return False
    
    def send_direct_notification(self, sender_token: str, recipient_fcm_token: str, 
                                sender_name: str, message_content: str) -> bool:
        """Send direct notification via Django backend"""
        try:
            notification_data = {
                "fcm_tokens": [recipient_fcm_token],
                "title": f"New message from {sender_name}",
                "body": message_content,
                "data": {
                    "type": "message",
                    "messageId": "test_msg_123",
                    "conversationId": "test_conv_456", 
                    "fromUserId": "1",
                    "fromUserName": sender_name,
                    "fromUserAvatar": "",
                    "messageContent": message_content,
                    "messageType": "text"
                }
            }
            
            response = self.session.post(
                f"{self.base_url}/api/notifications/send_direct/",
                json=notification_data,
                headers={
                    'Authorization': f'Bearer {sender_token}',
                    'Content-Type': 'application/json'
                }
            )
            
            print(f"Direct notification send response: {response.status_code}")
            print(f"Response body: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    print("✅ Direct notification sent successfully!")
                    print(f"Success details: {result}")
                    return True
                else:
                    print(f"❌ Direct notification failed: {result}")
                    return False
            else:
                print(f"❌ Direct notification failed with status {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            print(f"Error sending direct notification: {e}")
            return False
    
    def run_complete_test(self) -> bool:
        """Run the complete end-to-end test"""
        print("🚀 Starting complete message notification test...")
        print("=" * 60)
        
        # Step 1: Authenticate both users
        print("\n📝 Step 1: Authenticating users...")
        for user in TEST_USERS:
            email = user["email"]
            password = user["password"]
            
            auth_data = self.authenticate_user(email, password)
            if not auth_data:
                print(f"❌ Failed to authenticate {email}")
                return False
                
            self.auth_tokens[email] = auth_data["tokens"]["access"]
            self.user_data[email] = auth_data["user"]
            print(f"✅ Authenticated {email}")
        
        # Step 2: Register FCM tokens
        print("\n📱 Step 2: Registering FCM tokens...")
        
        # Generate mock FCM tokens for testing
        fcm_tokens = {}
        for i, user in enumerate(TEST_USERS):
            email = user["email"]
            # Generate a mock FCM token (in real app, this comes from Firebase)
            mock_fcm_token = f"mock_fcm_token_{''.join(email.split('@')[0].split('.'))}_{''.join(str(time.time()).split('.'))}"
            fcm_tokens[email] = mock_fcm_token
            
            success = self.register_fcm_token(
                email, 
                self.auth_tokens[email], 
                mock_fcm_token
            )
            
            if not success:
                print(f"❌ Failed to register FCM token for {email}")
                return False
        
        # Step 3: Send message notification 
        print("\n💬 Step 3: Sending message notification...")
        
        sender_email = TEST_USERS[0]["email"]
        recipient_email = TEST_USERS[1]["email"]
        
        sender_name = self.user_data[sender_email]["first_name"] + " " + self.user_data[sender_email]["last_name"]
        message_content = "Hello! This is a test message notification."
        
        success = self.send_direct_notification(
            sender_token=self.auth_tokens[sender_email],
            recipient_fcm_token=fcm_tokens[recipient_email],
            sender_name=sender_name,
            message_content=message_content
        )
        
        if not success:
            print("❌ Failed to send message notification")
            return False
            
        # Step 4: Verify results
        print("\n✅ Step 4: Test completed successfully!")
        print("=" * 60)
        print("📊 Test Summary:")
        print(f"  • Sender: {sender_name} ({sender_email})")
        print(f"  • Recipient: {self.user_data[recipient_email]['first_name']} {self.user_data[recipient_email]['last_name']} ({recipient_email})")
        print(f"  • Message: {message_content}")
        print(f"  • FCM Token (recipient): {fcm_tokens[recipient_email][:32]}...")
        print("  • Notification sent successfully ✅")
        
        return True

def main():
    print("🔔 Message Notification End-to-End Test")
    print("=" * 60)
    print("This test verifies the complete message notification flow:")
    print("1. User authentication with Django backend")
    print("2. FCM token registration")
    print("3. Direct message notification sending")
    print("4. Verification of successful delivery")
    print("")
    
    # Check if Django server is running
    try:
        response = requests.get(f"{BASE_URL}/api/health/", timeout=5)
        if response.status_code != 200:
            print("❌ Django server is not responding properly")
            print("Please ensure the Django server is running on http://localhost:8000")
            return
    except requests.exceptions.RequestException:
        print("❌ Cannot connect to Django server")
        print("Please ensure the Django server is running on http://localhost:8000")
        return
    
    # Run the test
    tester = MessageNotificationTester()
    
    try:
        success = tester.run_complete_test()
        
        if success:
            print("\n🎉 ALL TESTS PASSED! Message notification system is working correctly.")
        else:
            print("\n❌ TEST FAILED! Please check the error messages above.")
            
    except KeyboardInterrupt:
        print("\n⏹️ Test interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error during test: {e}")

if __name__ == "__main__":
    main()
