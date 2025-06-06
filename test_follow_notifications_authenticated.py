#!/usr/bin/env python3
"""
Comprehensive test script for follow/unfollow notifications with authentication
Tests the complete notification flow including Django backend integration
"""

import requests
import json
import time
import os
import sys

# Add Django project to path
sys.path.append('/Users/momen_mac/Desktop/flutter_application/server')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from django.test import Client
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from notifications.models import NotificationSettings, NotificationQueue, NotificationHistory

BASE_URL = 'http://127.0.0.1:8000'

def create_test_users():
    """Create test users for follow/unfollow testing"""
    print("🔧 Creating test users...")
    
    # Create follower user
    follower_user, created = User.objects.get_or_create(
        username='testfollower',
        defaults={
            'email': 'follower@test.com',
            'first_name': 'Test',
            'last_name': 'Follower'
        }
    )
    if created:
        follower_user.set_password('testpass123')
        follower_user.save()
        print(f"✅ Created follower user: {follower_user.username}")
    else:
        print(f"ℹ️  Follower user already exists: {follower_user.username}")
    
    # Create target user (the one being followed)
    target_user, created = User.objects.get_or_create(
        username='testtarget',
        defaults={
            'email': 'target@test.com',
            'first_name': 'Test',
            'last_name': 'Target'
        }
    )
    if created:
        target_user.set_password('testpass123')
        target_user.save()
        print(f"✅ Created target user: {target_user.username}")
    else:
        print(f"ℹ️  Target user already exists: {target_user.username}")
    
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

def test_notification_settings(users):
    """Test notification settings API"""
    print("\n📱 Testing notification settings...")
    
    for role, user_data in users.items():
        headers = {'Authorization': f'Token {user_data["token"]}'}
        
        # Test GET settings
        response = requests.get(f'{BASE_URL}/api/notifications/settings/', headers=headers)
        print(f"  {role} settings GET: {response.status_code}")
        
        if response.status_code == 200:
            settings = response.json()
            print(f"    Settings count: {len(settings)}")
            if settings:
                print(f"    Follow notifications enabled: {settings[0].get('follow_notifications', 'N/A')}")
        
        # Test my_settings endpoint
        response = requests.get(f'{BASE_URL}/api/notifications/settings/my_settings/', headers=headers)
        print(f"  {role} my_settings GET: {response.status_code}")
        
        if response.status_code == 200:
            settings = response.json()
            print(f"    Follow notifications: {settings.get('follow_notifications')}")

def test_follow_unfollow_flow(users):
    """Test the complete follow/unfollow notification flow"""
    print("\n👥 Testing follow/unfollow flow...")
    
    follower_headers = {'Authorization': f'Token {users["follower"]["token"]}'}
    target_headers = {'Authorization': f'Token {users["target"]["token"]}'}
    
    follower_id = users['follower']['user'].id
    target_id = users['target']['user'].id
    
    # Clear any existing notifications
    NotificationQueue.objects.filter(user=users['target']['user']).delete()
    NotificationHistory.objects.filter(user=users['target']['user']).delete()
    
    print(f"  Follower ID: {follower_id}, Target ID: {target_id}")
    
    # Test follow action
    print("\n  🔄 Testing FOLLOW action...")
    follow_url = f'{BASE_URL}/api/accounts/users/{target_id}/follow/'
    response = requests.post(follow_url, headers=follower_headers)
    print(f"    Follow request: {response.status_code}")
    
    if response.status_code == 200:
        print(f"    Response: {response.json()}")
        
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
    
    # Test unfollow action
    print("\n  🔄 Testing UNFOLLOW action...")
    unfollow_url = f'{BASE_URL}/api/accounts/users/{target_id}/unfollow/'
    response = requests.post(unfollow_url, headers=follower_headers)
    print(f"    Unfollow request: {response.status_code}")
    
    if response.status_code == 200:
        print(f"    Response: {response.json()}")
        
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

def test_notification_queue_api(users):
    """Test notification queue API endpoints"""
    print("\n📋 Testing notification queue API...")
    
    target_headers = {'Authorization': f'Token {users["target"]["token"]}'}
    
    # Test queue listing
    response = requests.get(f'{BASE_URL}/api/notifications/queue/', headers=target_headers)
    print(f"  Queue GET: {response.status_code}")
    
    if response.status_code == 200:
        queue = response.json()
        print(f"    Queue items: {len(queue)}")
        for item in queue:
            print(f"      - {item.get('notification_type')}: {item.get('status')}")

def test_with_disabled_notifications(users):
    """Test follow/unfollow when notifications are disabled"""
    print("\n🔕 Testing with disabled follow notifications...")
    
    target_headers = {'Authorization': f'Token {users["target"]["token"]}'}
    follower_headers = {'Authorization': f'Token {users["follower"]["token"]}'}
    
    # Disable follow notifications for target user
    settings_data = {'follow_notifications': False}
    response = requests.patch(
        f'{BASE_URL}/api/notifications/settings/my_settings/',
        headers=target_headers,
        json=settings_data
    )
    print(f"  Disable notifications: {response.status_code}")
    
    # Clear existing notifications
    NotificationQueue.objects.filter(user=users['target']['user']).delete()
    
    # Test follow with disabled notifications
    target_id = users['target']['user'].id
    follow_url = f'{BASE_URL}/api/accounts/users/{target_id}/follow/'
    response = requests.post(follow_url, headers=follower_headers)
    print(f"  Follow with disabled notifications: {response.status_code}")
    
    # Check that no notification was queued
    time.sleep(1)
    queued_notifications = NotificationQueue.objects.filter(
        user=users['target']['user'],
        notification_type='new_follower'
    )
    print(f"  Should be 0 notifications queued: {queued_notifications.count()}")
    
    # Re-enable notifications
    settings_data = {'follow_notifications': True}
    response = requests.patch(
        f'{BASE_URL}/api/notifications/settings/my_settings/',
        headers=target_headers,
        json=settings_data
    )
    print(f"  Re-enable notifications: {response.status_code}")

def run_comprehensive_test():
    """Run the complete test suite"""
    print("🚀 Starting comprehensive follow/unfollow notification test")
    print("=" * 60)
    
    try:
        # Create test users and get tokens
        users = create_test_users()
        
        # Test notification settings
        test_notification_settings(users)
        
        # Test follow/unfollow flow
        test_follow_unfollow_flow(users)
        
        # Test notification queue API
        test_notification_queue_api(users)
        
        # Test with disabled notifications
        test_with_disabled_notifications(users)
        
        print("\n" + "=" * 60)
        print("✅ Comprehensive test completed successfully!")
        
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
        
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run_comprehensive_test()
