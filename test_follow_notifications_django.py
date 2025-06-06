#!/usr/bin/env python3
"""
Django management command to test follow/unfollow notifications
Run with: python manage.py shell < test_follow_notifications_django.py
"""

import requests
import json
import time
from accounts.models import Account
from rest_framework.authtoken.models import Token
from notifications.models import NotificationSettings, NotificationQueue, NotificationHistory

BASE_URL = 'http://127.0.0.1:8000'

def create_test_users():
    """Create test users for follow/unfollow testing"""
    print("🔧 Creating test users...")
    
    # Create follower user
    follower_user, created = Account.objects.get_or_create(
        email='follower@test.com',
        defaults={
            'first_name': 'Test',
            'last_name': 'Follower'
        }
    )
    if created:
        follower_user.set_password('testpass123')
        follower_user.save()
        print(f"✅ Created follower user: {follower_user.email}")
    else:
        print(f"ℹ️  Follower user already exists: {follower_user.email}")
    
    # Create target user (the one being followed)
    target_user, created = Account.objects.get_or_create(
        email='target@test.com',
        defaults={
            'first_name': 'Test',
            'last_name': 'Target'
        }
    )
    if created:
        target_user.set_password('testpass123')
        target_user.save()
        print(f"✅ Created target user: {target_user.email}")
    else:
        print(f"ℹ️  Target user already exists: {target_user.email}")
    
    # Create or get auth tokens
    follower_token, created = Token.objects.get_or_create(user=follower_user)
    target_token, created = Token.objects.get_or_create(user=target_user)
    
    # Ensure notification settings exist
    NotificationSettings.objects.get_or_create(
        user=follower_user,
        defaults={'follow_notifications': True}
    )
    NotificationSettings.objects.get_or_create(
        user=target_user,
        defaults={'follow_notifications': True}
    )
    
    return {
        'follower': {'user': follower_user, 'token': follower_token.key},
        'target': {'user': target_user, 'token': target_token.key}
    }

def test_follow_unfollow_flow(users):
    """Test the complete follow/unfollow notification flow"""
    print("\n👥 Testing follow/unfollow flow...")
    
    follower_headers = {'Authorization': f'Token {users["follower"]["token"]}'}
    
    follower_id = users['follower']['user'].id
    target_id = users['target']['user'].id
    
    # Clear any existing notifications
    NotificationQueue.objects.filter(user=users['target']['user']).delete()
    NotificationHistory.objects.filter(user=users['target']['user']).delete()
    
    print(f"  Follower ID: {follower_id}, Target ID: {target_id}")
    
    # Test follow action
    print("\n  🔄 Testing FOLLOW action...")
    follow_url = f'{BASE_URL}/api/accounts/users/{target_id}/follow/'
    try:
        response = requests.post(follow_url, headers=follower_headers, timeout=10)
        print(f"    Follow request: {response.status_code}")
        
        if response.status_code == 200:
            print(f"    Response: {response.json()}")
        else:
            print(f"    Error response: {response.text}")
        
        # Check if notification was queued
        time.sleep(1)  # Allow for notification processing
        queued_notifications = NotificationQueue.objects.filter(
            user=users['target']['user'],
            notification_type='new_follower'
        )
        print(f"    Queued notifications: {queued_notifications.count()}")
        
        for notification in queued_notifications:
            print(f"      - Type: {notification.notification_type}")
            print(f"      - Status: {notification.status}")
            print(f"      - Data: {notification.data}")
            
    except requests.exceptions.RequestException as e:
        print(f"    Request failed: {e}")
    
    # Test unfollow action
    print("\n  🔄 Testing UNFOLLOW action...")
    unfollow_url = f'{BASE_URL}/api/accounts/users/{target_id}/unfollow/'
    try:
        response = requests.post(unfollow_url, headers=follower_headers, timeout=10)
        print(f"    Unfollow request: {response.status_code}")
        
        if response.status_code == 200:
            print(f"    Response: {response.json()}")
        else:
            print(f"    Error response: {response.text}")
        
        # Check if notification was queued
        time.sleep(1)
        queued_notifications = NotificationQueue.objects.filter(
            user=users['target']['user'],
            notification_type='unfollowed'
        )
        print(f"    Unfollowed notifications: {queued_notifications.count()}")
        
        for notification in queued_notifications:
            print(f"      - Type: {notification.notification_type}")
            print(f"      - Status: {notification.status}")
            print(f"      - Data: {notification.data}")
            
    except requests.exceptions.RequestException as e:
        print(f"    Request failed: {e}")

def test_notification_settings(users):
    """Test notification settings API"""
    print("\n📱 Testing notification settings...")
    
    for role, user_data in users.items():
        headers = {'Authorization': f'Token {user_data["token"]}'}
        
        try:
            # Test my_settings endpoint
            response = requests.get(f'{BASE_URL}/api/notifications/settings/my_settings/', headers=headers, timeout=10)
            print(f"  {role} my_settings GET: {response.status_code}")
            
            if response.status_code == 200:
                settings = response.json()
                print(f"    Follow notifications: {settings.get('follow_notifications')}")
            else:
                print(f"    Error: {response.text}")
                
        except requests.exceptions.RequestException as e:
            print(f"    Request failed: {e}")

def run_test():
    """Run the test suite"""
    print("🚀 Starting Django-integrated follow/unfollow notification test")
    print("=" * 60)
    
    try:
        # Create test users and get tokens
        users = create_test_users()
        
        # Test notification settings
        test_notification_settings(users)
        
        # Test follow/unfollow flow
        test_follow_unfollow_flow(users)
        
        print("\n" + "=" * 60)
        print("✅ Test completed!")
        
        # Final summary
        print("\n📊 Final Summary:")
        total_notifications = NotificationQueue.objects.filter(
            user__in=[users['target']['user'], users['follower']['user']]
        ).count()
        print(f"  Total notifications in queue: {total_notifications}")
        
        follow_notifications = NotificationQueue.objects.filter(
            notification_type='new_follower'
        ).count()
        unfollow_notifications = NotificationQueue.objects.filter(
            notification_type='unfollowed'
        ).count()
        
        print(f"  Follow notifications: {follow_notifications}")
        print(f"  Unfollow notifications: {unfollow_notifications}")
        
        # Show actual notification data
        print("\n📋 Notification Details:")
        for notification in NotificationQueue.objects.filter(
            user__in=[users['target']['user'], users['follower']['user']]
        ).order_by('-created_at')[:5]:
            print(f"  - {notification.notification_type} for {notification.user.username}")
            print(f"    Status: {notification.status}")
            print(f"    Data: {json.loads(notification.data) if notification.data else 'None'}")
        
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()

# Run the test
run_test()
