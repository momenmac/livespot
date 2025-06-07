#!/usr/bin/env python3
"""
Debug script for message notifications system
Tests each component to identify where the notification delivery is failing
"""

import requests
import json
import time
import sys

# Base URL for the Django API
BASE_URL = "http://127.0.0.1:8000/api"

# User credentials - using existing users from your database
USER1_EMAIL = "ahmed.khatib@example.com"
USER1_PASSWORD = "1234"
USER2_EMAIL = "leila.awad@example.com"  # Different user for testing
USER2_PASSWORD = "1234"

def login(email, password):
    """Log in to the Django API and return the JWT token."""
    login_url = f"{BASE_URL}/accounts/login/"
    
    try:
        print(f"🔐 Attempting to log in with {email}...")
        response = requests.post(
            login_url,
            json={"email": email, "password": password}
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'tokens' in data and 'access' in data['tokens']:
                access_token = data['tokens']['access']
                user_id = data.get('user', {}).get('id')
                print(f"✅ Login successful - User ID: {user_id}")
                return access_token, user_id
            else:
                print("❌ Login successful but token structure not as expected")
                print(f"Response data: {data}")
                return None, None
        else:
            print(f"❌ Login failed with status code {response.status_code}")
            print(f"Response: {response.text}")
            return None, None
    except Exception as e:
        print(f"❌ Error during login: {str(e)}")
        return None, None

def get_fcm_tokens(token, user_id):
    """Get FCM tokens for a user"""
    url = f"{BASE_URL}/notifications/fcm-tokens/"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"🔍 Getting FCM tokens for user {user_id}...")
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            tokens = response.json()
            print(f"✅ Found {len(tokens)} FCM tokens for user {user_id}")
            for i, token_data in enumerate(tokens):
                print(f"  Token {i+1}: {token_data.get('token', 'N/A')[:20]}...")
            return tokens
        else:
            print(f"❌ Failed to get FCM tokens: {response.status_code}")
            print(f"Response: {response.text}")
            return []
    except Exception as e:
        print(f"❌ Error getting FCM tokens: {str(e)}")
        return []

def test_send_direct_notification(token, recipient_user_id):
    """Test sending a direct notification (what the Flutter app should be doing)"""
    url = f"{BASE_URL}/notifications/actions/send-direct/"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    notification_data = {
        "recipient_user_id": recipient_user_id,
        "notification_type": "message",
        "title": "Test Message Notification",
        "body": "📱 This is a test message from the debug script",
        "data": {
            "type": "message",
            "messageId": "test-message-123",
            "conversationId": "test-conversation-456",
            "fromUserId": "sender-123",
            "fromUserName": "Test Sender",
            "fromUserAvatar": "",
            "messageContent": "This is a test message",
            "messageType": "text",
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        },
        "priority": "high"
    }
    
    try:
        print(f"📤 Sending direct notification to user {recipient_user_id}...")
        response = requests.post(url, headers=headers, json=notification_data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Direct notification sent successfully!")
            print(f"   Response: {result}")
            return True
        else:
            print(f"❌ Failed to send direct notification: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error sending direct notification: {str(e)}")
        return False

def create_test_conversation(token, user1_id, user2_id):
    """Create a test conversation between two users"""
    # This would typically be done through Firestore, but for testing
    # we'll simulate what the Flutter app would send
    print(f"🗣️ Simulating conversation between users {user1_id} and {user2_id}")
    return f"conv_{user1_id}_{user2_id}_{int(time.time())}"

def test_message_notification_flow(sender_token, sender_id, recipient_id):
    """Test the complete message notification flow"""
    print("\n" + "="*60)
    print("🧪 TESTING COMPLETE MESSAGE NOTIFICATION FLOW")
    print("="*60)
    
    # Step 1: Create a test conversation
    conversation_id = create_test_conversation(sender_token, sender_id, recipient_id)
    print(f"📝 Test conversation ID: {conversation_id}")
    
    # Step 2: Send a message notification (simulating what Flutter app does)
    message_data = {
        "recipient_user_id": recipient_id,
        "notification_type": "message",
        "title": "John Doe",  # Sender's name
        "body": "Hey there! How are you doing?",
        "data": {
            "type": "message",
            "messageId": f"msg_{int(time.time())}",
            "conversationId": conversation_id,
            "fromUserId": str(sender_id),
            "fromUserName": "John Doe",
            "fromUserAvatar": "",
            "messageContent": "Hey there! How are you doing?",
            "messageType": "text",
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
            "conversation_id": conversation_id,  # Additional data for click handling
        },
        "priority": "high"
    }
    
    url = f"{BASE_URL}/notifications/actions/send-direct/"
    headers = {
        "Authorization": f"Bearer {sender_token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"📱 Sending message notification from user {sender_id} to user {recipient_id}...")
        response = requests.post(url, headers=headers, json=message_data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Message notification sent successfully!")
            print(f"   Tokens reached: {result.get('tokens_sent', 0)}")
            print(f"   Success count: {result.get('success_count', 0)}")
            print(f"   Failed count: {result.get('failed_count', 0)}")
            
            if result.get('failed_count', 0) > 0:
                print(f"⚠️ Some notifications failed:")
                for error in result.get('errors', []):
                    print(f"   - {error}")
            
            return True
        else:
            print(f"❌ Failed to send message notification: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error in message notification flow: {str(e)}")
        return False

def check_notification_settings(token, user_id):
    """Check notification settings for a user"""
    url = f"{BASE_URL}/notifications/settings/my-settings/"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"⚙️ Checking notification settings for user {user_id}...")
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            settings = response.json()
            print(f"✅ Notification settings:")
            print(f"   Messages enabled: {settings.get('message_notifications', True)}")
            print(f"   Push enabled: {settings.get('push_notifications', True)}")
            print(f"   Email enabled: {settings.get('email_notifications', True)}")
            return settings
        else:
            print(f"❌ Failed to get notification settings: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Error getting notification settings: {str(e)}")
        return None

def main():
    print("🔔 MESSAGE NOTIFICATION DEBUG SCRIPT")
    print("="*50)
    print("This script will test the complete message notification flow")
    print("Make sure your Django server is running on localhost:8000")
    print("="*50)
    
    # Step 1: Login both users
    print("\n📱 STEP 1: User Authentication")
    sender_token, sender_id = login(USER1_EMAIL, USER1_PASSWORD)
    if not sender_token:
        print("❌ Failed to login sender user")
        sys.exit(1)
    
    recipient_token, recipient_id = login(USER2_EMAIL, USER2_PASSWORD)
    if not recipient_token:
        print("❌ Failed to login recipient user")
        sys.exit(1)
    
    print(f"✅ Both users authenticated:")
    print(f"   Sender: User {sender_id}")
    print(f"   Recipient: User {recipient_id}")
    
    # Step 2: Check FCM tokens
    print("\n🔍 STEP 2: FCM Token Verification")
    sender_tokens = get_fcm_tokens(sender_token, sender_id)
    recipient_tokens = get_fcm_tokens(recipient_token, recipient_id)
    
    if not recipient_tokens:
        print("⚠️ WARNING: Recipient has no FCM tokens!")
        print("   This means the Flutter app hasn't registered for notifications yet.")
        print("   Make sure to:")
        print("   1. Run the Flutter app on the recipient's device")
        print("   2. Enable notifications when prompted")
        print("   3. The app should automatically register FCM tokens")
        print("\n   Continuing with test anyway...")
    
    # Step 3: Check notification settings
    print("\n⚙️ STEP 3: Notification Settings Check")
    recipient_settings = check_notification_settings(recipient_token, recipient_id)
    
    # Step 4: Test direct notification
    print("\n📤 STEP 4: Direct Notification Test")
    test_send_direct_notification(sender_token, recipient_id)
    
    # Step 5: Test complete message notification flow
    print("\n🔄 STEP 5: Complete Message Flow Test")
    success = test_message_notification_flow(sender_token, sender_id, recipient_id)
    
    # Summary
    print("\n" + "="*60)
    print("📋 TEST SUMMARY")
    print("="*60)
    print(f"✅ Sender authenticated: User {sender_id}")
    print(f"✅ Recipient authenticated: User {recipient_id}")
    print(f"📱 Sender FCM tokens: {len(sender_tokens)}")
    print(f"📱 Recipient FCM tokens: {len(recipient_tokens)}")
    print(f"⚙️ Notification settings checked: {'✅' if recipient_settings else '❌'}")
    print(f"📤 Message notification sent: {'✅' if success else '❌'}")
    
    if success and recipient_tokens:
        print("\n🎉 All tests passed! The recipient should have received a notification.")
    elif success and not recipient_tokens:
        print("\n⚠️ Notification sent but recipient has no FCM tokens.")
        print("   The notification won't be delivered until the Flutter app registers tokens.")
    else:
        print("\n❌ Some tests failed. Check the error messages above.")
    
    print("\n💡 Tips for debugging:")
    print("   1. Make sure the Flutter app is running on the recipient's device")
    print("   2. Check that Firebase Cloud Messaging is properly configured")
    print("   3. Verify the app requests and receives notification permissions")
    print("   4. Check the Django server logs for any FCM delivery errors")

if __name__ == "__main__":
    main()
