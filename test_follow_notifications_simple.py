#!/usr/bin/env python3
"""
Simple HTTP client test for follow/unfollow notifications
This test makes actual API calls to the running Django server
"""

import requests
import json
import time

# Configuration
BASE_URL = "http://localhost:8000"
API_BASE = f"{BASE_URL}/api"

def test_follow_notifications():
    """Test the complete follow/unfollow notification system"""
    print("🧪 Testing Follow/Unfollow Notifications System")
    print("=" * 50)
    
    # Step 1: Get or create authentication token
    print("\n1. Getting authentication token...")
    
    # Try to login with test credentials
    login_data = {
        "username": "testuser",
        "password": "testpass123"
    }
    
    # If testuser doesn't exist, create it
    register_data = {
        "username": "testuser",
        "email": "test@example.com",
        "password": "testpass123"
    }
    
    try:
        # Try to register first (in case user doesn't exist)
        register_response = requests.post(f"{API_BASE}/accounts/register/", json=register_data)
        print(f"Register attempt: {register_response.status_code}")
    except Exception as e:
        print(f"Register failed (user might already exist): {e}")
    
    # Now try to login
    try:
        login_response = requests.post(f"{API_BASE}/accounts/login/", json=login_data)
        print(f"Login response: {login_response.status_code}")
        
        if login_response.status_code == 200:
            token_data = login_response.json()
            token = token_data.get('access') or token_data.get('token')
            print(f"✅ Got authentication token: {token[:20]}...")
        else:
            print(f"❌ Login failed: {login_response.text}")
            return
            
    except Exception as e:
        print(f"❌ Login error: {e}")
        return
    
    # Set up headers for authenticated requests
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Step 2: Check notification settings
    print("\n2. Checking notification settings...")
    try:
        settings_response = requests.get(f"{API_BASE}/notifications/settings/", headers=headers)
        print(f"Settings response: {settings_response.status_code}")
        
        if settings_response.status_code == 200:
            settings = settings_response.json()
            print(f"✅ Notification settings: {json.dumps(settings, indent=2)}")
        else:
            print(f"❌ Settings check failed: {settings_response.text}")
            
    except Exception as e:
        print(f"❌ Settings error: {e}")
    
    # Step 3: Check notification queue
    print("\n3. Checking notification queue...")
    try:
        queue_response = requests.get(f"{API_BASE}/notifications/queue/", headers=headers)
        print(f"Queue response: {queue_response.status_code}")
        
        if queue_response.status_code == 200:
            queue = queue_response.json()
            print(f"✅ Notification queue: {len(queue)} items")
            for item in queue[:3]:  # Show first 3 items
                print(f"   - {item.get('notification_type', 'unknown')}: {item.get('title', 'No title')}")
        else:
            print(f"❌ Queue check failed: {queue_response.text}")
            
    except Exception as e:
        print(f"❌ Queue error: {e}")
    
    # Step 4: Test follow/unfollow (we need another user to follow)
    print("\n4. Testing follow/unfollow actions...")
    
    # Create a second test user to follow
    user2_data = {
        "username": "testuser2",
        "email": "test2@example.com", 
        "password": "testpass123"
    }
    
    try:
        # Try to create user2
        register2_response = requests.post(f"{API_BASE}/accounts/register/", json=user2_data)
        print(f"User2 register: {register2_response.status_code}")
        
        # Get user2's ID (we need to find it somehow)
        # Let's check if there's a users endpoint
        users_response = requests.get(f"{API_BASE}/accounts/users/", headers=headers)
        print(f"Users list response: {users_response.status_code}")
        
        if users_response.status_code == 200:
            users = users_response.json()
            print(f"✅ Found {len(users)} users")
            
            # Find user2
            user2_id = None
            for user in users:
                if user.get('username') == 'testuser2':
                    user2_id = user.get('id')
                    break
            
            if user2_id:
                print(f"✅ Found user2 with ID: {user2_id}")
                
                # Test follow
                print("\n5. Testing follow action...")
                follow_response = requests.post(f"{API_BASE}/accounts/users/{user2_id}/follow/", headers=headers)
                print(f"Follow response: {follow_response.status_code}")
                
                if follow_response.status_code in [200, 201]:
                    print("✅ Follow action successful!")
                    
                    # Check queue again for new notifications
                    time.sleep(1)  # Give it a moment
                    queue_response = requests.get(f"{API_BASE}/notifications/queue/", headers=headers)
                    if queue_response.status_code == 200:
                        queue = queue_response.json()
                        print(f"✅ Queue now has {len(queue)} items")
                        
                        # Look for follow notification
                        for item in queue:
                            if item.get('notification_type') == 'new_follower':
                                print(f"✅ Found follow notification: {item.get('title')}")
                                break
                else:
                    print(f"❌ Follow failed: {follow_response.text}")
                
                # Test unfollow
                print("\n6. Testing unfollow action...")
                unfollow_response = requests.post(f"{API_BASE}/accounts/users/{user2_id}/unfollow/", headers=headers)
                print(f"Unfollow response: {unfollow_response.status_code}")
                
                if unfollow_response.status_code in [200, 201]:
                    print("✅ Unfollow action successful!")
                    
                    # Check queue again for new notifications
                    time.sleep(1)  # Give it a moment
                    queue_response = requests.get(f"{API_BASE}/notifications/queue/", headers=headers)
                    if queue_response.status_code == 200:
                        queue = queue_response.json()
                        print(f"✅ Queue now has {len(queue)} items")
                        
                        # Look for unfollow notification
                        for item in queue:
                            if item.get('notification_type') == 'unfollowed':
                                print(f"✅ Found unfollow notification: {item.get('title')}")
                                break
                else:
                    print(f"❌ Unfollow failed: {unfollow_response.text}")
            else:
                print("❌ Could not find user2 ID")
        else:
            print(f"❌ Could not get users list: {users_response.text}")
            
    except Exception as e:
        print(f"❌ Follow/unfollow test error: {e}")
    
    print("\n" + "=" * 50)
    print("🎉 Follow/Unfollow Notification Test Complete!")

if __name__ == "__main__":
    test_follow_notifications()
