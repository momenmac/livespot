#!/usr/bin/env python3
# filepath: /Users/momen_mac/Desktop/flutter_application/test_follow_user23_realtime.py

import requests
import json
import time
import sys

# Base URL for the Django API
BASE_URL = "http://127.0.0.1:8000/api"

# User credentials for user 1
USER_EMAIL = "ahmed.khatib@example.com"
USER_PASSWORD = "1234"

# Target user ID to follow (user 23)
TARGET_USER_ID = 23

def login(email, password):
    """Log in to the Django API and return the JWT token."""
    login_url = f"{BASE_URL}/accounts/login/"
    
    try:
        print(f"Attempting to log in with {email}...")
        response = requests.post(
            login_url,
            json={"email": email, "password": password}
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'tokens' in data and 'access' in data['tokens']:
                access_token = data['tokens']['access']
                print("✅ Login successful")
                return access_token
            else:
                print("❌ Login successful but token structure not as expected")
                print(f"Response data: {data}")
                return None
        else:
            print(f"❌ Login failed with status code {response.status_code}")
            print(f"Response: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error during login: {str(e)}")
        return None

def unfollow_user(token, target_user_id):
    """Make the authenticated user unfollow another user."""
    unfollow_url = f"{BASE_URL}/accounts/users/{target_user_id}/unfollow/"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"Attempting to unfollow user {target_user_id}...")
        response = requests.post(unfollow_url, headers=headers)
        
        if response.status_code in [200, 201, 204]:
            print(f"✅ Successfully unfollowed user {target_user_id}")
            return True
        else:
            print(f"❌ Failed to unfollow user with status code {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error while unfollowing user: {str(e)}")
        return False

def follow_user(token, target_user_id):
    """Make the authenticated user follow another user."""
    follow_url = f"{BASE_URL}/accounts/users/{target_user_id}/follow/"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"Attempting to follow user {target_user_id}...")
        response = requests.post(follow_url, headers=headers)
        
        if response.status_code in [200, 201]:
            print(f"✅ Successfully followed user {target_user_id}")
            return True
        else:
            print(f"❌ Failed to follow user with status code {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error while following user: {str(e)}")
        return False

def main():
    print("=" * 50)
    print("🔔 FOLLOW NOTIFICATION TEST SCRIPT")
    print("=" * 50)
    print(f"This script will make user 1 ({USER_EMAIL}) follow user {TARGET_USER_ID}")
    print(f"You should see a notification appear on user {TARGET_USER_ID}'s device")
    print("=" * 50)
    
    # Step 1: Login
    token = login(USER_EMAIL, USER_PASSWORD)
    if not token:
        print("❌ Login failed. Cannot proceed.")
        sys.exit(1)
    
    # Print token for debugging
    print(f"Token received: {token[:10]}...{token[-10:]}")
    
    # Step 2: Unfollow user first (to ensure we can generate a new follow notification)
    unfollow_result = unfollow_user(token, TARGET_USER_ID)
    if unfollow_result:
        print("✅ Successfully unfollowed the user. Waiting 3 seconds before following again...")
        time.sleep(3)  # Wait a bit to let the server process the unfollow
    
    # Step 3: Follow user
    success = follow_user(token, TARGET_USER_ID)
    if success:
        print("=" * 50)
        print(f"✅ Follow request sent to user {TARGET_USER_ID}")
        print("👀 Check your app now - you should see a follow notification!")
        print("=" * 50)
    else:
        print("❌ Failed to follow user. Check the error messages above.")

if __name__ == "__main__":
    main()