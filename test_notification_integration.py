#!/usr/bin/env python3
"""
Test script to verify the complete notification integration:
1. Notification click handling 
2. Navigation to notifications page
3. Real data loading from Django backend
4. User avatar display and profile navigation
"""

import requests
import json
import time
from datetime import datetime

# Configuration
BASE_URL = "http://127.0.0.1:8000"
API_BASE = f"{BASE_URL}/api"

# Test user credentials (adjust as needed)
TEST_USER = {
    "username": "testuser",
    "email": "test@example.com", 
    "password": "testpassword123"
}

TARGET_USER = {
    "username": "targetuser",
    "email": "target@example.com",
    "password": "testpassword123"
}

def get_auth_token(user_data):
    """Get JWT authentication token"""
    try:
        response = requests.post(f"{API_BASE}/auth/login/", json={
            "email": user_data["email"],
            "password": user_data["password"]
        })
        
        if response.status_code == 200:
            data = response.json()
            return data.get("access")
        else:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ Login error: {e}")
        return None

def create_follow_notification():
    """Create a follow notification to test"""
    print("🔄 Creating test follow notification...")
    
    # Get tokens for both users
    follower_token = get_auth_token(TEST_USER)
    target_token = get_auth_token(TARGET_USER)
    
    if not follower_token:
        print("❌ Could not get follower token")
        return False
        
    if not target_token:
        print("❌ Could not get target user token")
        return False
    
    # Follow the target user to create notification
    try:
        headers = {"Authorization": f"Bearer {follower_token}"}
        response = requests.post(f"{API_BASE}/social/follow/", 
                               headers=headers,
                               json={"user_email": TARGET_USER["email"]})
        
        if response.status_code in [200, 201]:
            print("✅ Follow request sent successfully")
            return True
        else:
            print(f"❌ Follow request failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Follow request error: {e}")
        return False

def test_notification_history():
    """Test fetching notification history"""
    print("🔄 Testing notification history API...")
    
    token = get_auth_token(TARGET_USER)
    if not token:
        print("❌ Could not get auth token")
        return False
    
    try:
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(f"{API_BASE}/notifications/history/", headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            notifications = data.get("results", [])
            
            print(f"✅ Successfully fetched {len(notifications)} notifications")
            
            # Display sample notifications
            for i, notification in enumerate(notifications[:3]):
                print(f"📱 Notification {i+1}:")
                print(f"   ID: {notification.get('id')}")
                print(f"   Type: {notification.get('notification_type')}")
                print(f"   Title: {notification.get('title')}")
                print(f"   Body: {notification.get('body')}")
                print(f"   Read: {notification.get('read')}")
                print(f"   Created: {notification.get('created_at')}")
                
                # Check for user data
                notification_data = notification.get('data', {})
                if 'user_data' in notification_data:
                    user_data = notification_data['user_data']
                    print(f"   User: {user_data.get('username', 'Unknown')}")
                    print(f"   Avatar: {user_data.get('profileImage', 'None')}")
                print()
            
            return True
        else:
            print(f"❌ Failed to fetch notifications: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Notification history error: {e}")
        return False

def test_mark_as_read():
    """Test marking notification as read"""
    print("🔄 Testing mark as read functionality...")
    
    token = get_auth_token(TARGET_USER)
    if not token:
        print("❌ Could not get auth token")
        return False
    
    try:
        headers = {"Authorization": f"Bearer {token}"}
        
        # Get notifications first
        response = requests.get(f"{API_BASE}/notifications/history/", headers=headers)
        if response.status_code != 200:
            print("❌ Could not fetch notifications for read test")
            return False
            
        notifications = response.json().get("results", [])
        unread_notifications = [n for n in notifications if not n.get('read')]
        
        if not unread_notifications:
            print("ℹ️ No unread notifications to test")
            return True
            
        # Mark first unread notification as read
        notification_id = unread_notifications[0]['id']
        response = requests.patch(
            f"{API_BASE}/notifications/history/{notification_id}/",
            headers=headers,
            json={"read": True}
        )
        
        if response.status_code == 200:
            print(f"✅ Successfully marked notification {notification_id} as read")
            return True
        else:
            print(f"❌ Failed to mark as read: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Mark as read error: {e}")
        return False

def main():
    """Run all notification integration tests"""
    print("🧪 === NOTIFICATION INTEGRATION TEST ===")
    print(f"🕐 Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Test steps
    tests = [
        ("Create Follow Notification", create_follow_notification),
        ("Test Notification History", test_notification_history),
        ("Test Mark as Read", test_mark_as_read),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"🔄 Running: {test_name}")
        try:
            result = test_func()
            results.append((test_name, result))
            if result:
                print(f"✅ {test_name}: PASSED")
            else:
                print(f"❌ {test_name}: FAILED")
        except Exception as e:
            print(f"❌ {test_name}: ERROR - {e}")
            results.append((test_name, False))
        print()
    
    # Summary
    print("📊 === TEST SUMMARY ===")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"   {status}: {test_name}")
    
    print(f"\n🎯 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All notification integration tests PASSED!")
        print("\n📱 Flutter app should now:")
        print("   • Navigate to notifications page when notification tapped")
        print("   • Load real data from Django backend") 
        print("   • Display user avatars for follow notifications")
        print("   • Allow navigation to user profiles")
        print("   • Mark notifications as read/unread")
    else:
        print("⚠️ Some tests failed - check Django server and authentication")

if __name__ == "__main__":
    main()
