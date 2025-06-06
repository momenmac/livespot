#!/usr/bin/env python3
"""
Test script to verify that follow notifications are only sent once (no duplicates)
This test will:
1. Set up two test users
2. Make user1 follow user2
3. Check notification queue status
4. Run background processor
5. Verify only one notification was sent
"""

import os
import sys
import django
import requests
import json
import time
from datetime import datetime

# Add the server directory to Python path
sys.path.append('/Users/momen_mac/Desktop/flutter_application/server')

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from accounts.models import Account, UserProfile
from notifications.models import NotificationQueue, NotificationHistory, FCMToken, NotificationSettings
from notifications.services import notification_service

def cleanup_test_data():
    """Clean up any existing test data"""
    print("🧹 Cleaning up existing test data...")
    
    # Delete test users and related data
    test_users = Account.objects.filter(email__in=['testuser1@example.com', 'testuser2@example.com'])
    for user in test_users:
        # Clean up notifications
        NotificationQueue.objects.filter(user=user).delete()
        NotificationHistory.objects.filter(user=user).delete()
        FCMToken.objects.filter(user=user).delete()
        NotificationSettings.objects.filter(user=user).delete()
        
        # Clean up follow relationships
        if hasattr(user, 'profile'):
            user.profile.followers.clear()
            user.profile.following.clear()
    
    test_users.delete()
    print("✅ Cleanup completed")

def create_test_users():
    """Create two test users for follow testing"""
    print("👥 Creating test users...")
    
    # Create user1 (follower)
    user1 = Account.objects.create_user(
        email='testuser1@example.com',
        password='testpass123',
        first_name='Test',
        last_name='User1'
    )
    
    # Create user2 (to be followed)
    user2 = Account.objects.create_user(
        email='testuser2@example.com',
        password='testpass123',
        first_name='Test',
        last_name='User2'
    )
    
    # Create profiles (should be created automatically via signals, but let's ensure)
    profile1, _ = UserProfile.objects.get_or_create(
        user=user1,
        defaults={'username': 'testuser1', 'bio': 'Test user 1'}
    )
    
    profile2, _ = UserProfile.objects.get_or_create(
        user=user2,
        defaults={'username': 'testuser2', 'bio': 'Test user 2'}
    )
    
    # Create notification settings for user2 (to receive notifications)
    settings2, _ = NotificationSettings.objects.get_or_create(
        user=user2,
        defaults={
            'friend_requests': True,
            'follow_notifications': True,
            'events': True,
            'reminders': True,
            'nearby_events': True,
            'system_notifications': True,
        }
    )
    
    # Create a mock FCM token for user2 (to receive notifications)
    fcm_token2, _ = FCMToken.objects.get_or_create(
        user=user2,
        token='mock_fcm_token_user2_duplicate_test',
        defaults={
            'device_platform': 'ios',
            'is_active': True
        }
    )
    
    print(f"✅ Created users: {user1.email} and {user2.email}")
    return user1, user2

def authenticate_user(email, password):
    """Authenticate user and get access token"""
    login_url = 'http://127.0.0.1:8000/api/accounts/login/'
    
    response = requests.post(login_url, json={
        'email': email,
        'password': password
    })
    
    if response.status_code == 200:
        data = response.json()
        return data.get('access_token')
    else:
        print(f"❌ Failed to authenticate {email}: {response.status_code}")
        print(f"Response: {response.text}")
        return None

def follow_user_via_api(follower_token, target_user_id):
    """Follow a user via the API"""
    follow_url = f'http://127.0.0.1:8000/api/accounts/users/{target_user_id}/follow/'
    
    headers = {
        'Authorization': f'Bearer {follower_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.post(follow_url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Failed to follow user: {response.status_code}")
        print(f"Response: {response.text}")
        return None

def check_notification_queue():
    """Check the current state of notification queue"""
    print("📊 Checking notification queue...")
    
    all_notifications = NotificationQueue.objects.all()
    pending_notifications = NotificationQueue.objects.filter(status='pending')
    sent_notifications = NotificationQueue.objects.filter(status='sent')
    
    print(f"   Total notifications in queue: {all_notifications.count()}")
    print(f"   Pending notifications: {pending_notifications.count()}")
    print(f"   Sent notifications: {sent_notifications.count()}")
    
    for notification in all_notifications:
        print(f"   📋 Notification {notification.id}: {notification.notification_type} -> {notification.user.email} (Status: {notification.status})")
    
    return {
        'total': all_notifications.count(),
        'pending': pending_notifications.count(),
        'sent': sent_notifications.count(),
        'notifications': list(all_notifications)
    }

def check_notification_history():
    """Check notification history"""
    print("📚 Checking notification history...")
    
    history = NotificationHistory.objects.filter(notification_type='new_follower')
    print(f"   Follow notifications in history: {history.count()}")
    
    for record in history:
        print(f"   📝 History {record.id}: {record.notification_type} -> {record.user.email} (Sent: {record.sent})")
    
    return history.count()

def run_background_processor():
    """Simulate running the background notification processor"""
    print("🔄 Running background processor...")
    
    # Get pending notifications
    pending_notifications = NotificationQueue.objects.filter(status='pending')
    processed_count = 0
    
    for notification in pending_notifications:
        print(f"   Processing notification {notification.id}...")
        try:
            # Use the notification service to send
            success = notification_service.send_notification(notification)
            if success:
                notification.status = 'sent'
                notification.processed_at = django.utils.timezone.now()
                notification.save()
                processed_count += 1
                print(f"   ✅ Sent notification {notification.id}")
            else:
                print(f"   ❌ Failed to send notification {notification.id}")
        except Exception as e:
            print(f"   ❌ Error processing notification {notification.id}: {e}")
    
    print(f"   Processed {processed_count} notifications")
    return processed_count

def main():
    print("🚀 Testing duplicate notification fix...")
    print("=" * 60)
    
    try:
        # Step 1: Clean up
        cleanup_test_data()
        
        # Step 2: Create test users
        user1, user2 = create_test_users()
        
        # Step 3: Authenticate user1
        print("\n🔐 Authenticating user1...")
        token1 = authenticate_user('testuser1@example.com', 'testpass123')
        if not token1:
            print("❌ Failed to authenticate user1")
            return
        print("✅ User1 authenticated")
        
        # Step 4: Check initial state
        print("\n📊 Initial notification queue state:")
        initial_state = check_notification_queue()
        initial_history = check_notification_history()
        
        # Step 5: Follow user2
        print(f"\n👥 User1 following User2 (ID: {user2.id})...")
        follow_result = follow_user_via_api(token1, user2.id)
        
        if follow_result and follow_result.get('success'):
            print("✅ Follow action completed successfully")
        else:
            print("❌ Follow action failed")
            return
        
        # Step 6: Check state after follow
        print("\n📊 Notification queue state after follow:")
        after_follow_state = check_notification_queue()
        after_follow_history = check_notification_history()
        
        # Step 7: Wait a moment, then run background processor
        print("\n⏳ Waiting 2 seconds before running background processor...")
        time.sleep(2)
        
        print("\n🔄 Running background processor to check for duplicates...")
        processed_by_bg = run_background_processor()
        
        # Step 8: Check final state
        print("\n📊 Final notification queue state:")
        final_state = check_notification_queue()
        final_history = check_notification_history()
        
        # Step 9: Analyze results
        print("\n🔍 ANALYSIS:")
        print("=" * 40)
        
        total_notifications_created = after_follow_state['total'] - initial_state['total']
        total_notifications_in_history = final_history - initial_history
        background_processed = processed_by_bg
        
        print(f"📋 Notifications created by follow action: {total_notifications_created}")
        print(f"📝 Notifications added to history: {total_notifications_in_history}")
        print(f"🔄 Notifications processed by background: {background_processed}")
        
        # Check for duplicates
        if background_processed == 0:
            print("✅ SUCCESS: No duplicate notifications! Background processor found no pending notifications.")
        else:
            print(f"⚠️ WARNING: Background processor sent {background_processed} additional notifications.")
            print("   This indicates potential duplicate notifications.")
        
        if total_notifications_in_history <= 1:
            print("✅ SUCCESS: Only one follow notification was recorded in history.")
        else:
            print(f"❌ FAILURE: {total_notifications_in_history} follow notifications in history (expected 1).")
        
        # Final verdict
        print("\n🏆 FINAL VERDICT:")
        if background_processed == 0 and total_notifications_in_history <= 1:
            print("✅ DUPLICATE NOTIFICATION FIX IS WORKING!")
            print("   No duplicate notifications were sent.")
        else:
            print("❌ DUPLICATE NOTIFICATION ISSUE PERSISTS!")
            print("   Manual investigation required.")
        
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # Cleanup
        print("\n🧹 Cleaning up test data...")
        cleanup_test_data()

if __name__ == '__main__':
    main()
