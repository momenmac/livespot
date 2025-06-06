#!/usr/bin/env python3
"""
Test script to simulate the "Still happening" feature
This script creates a test event near the user's location and sends a confirmation request
"""

import os
import sys
import json
import time
import requests
from datetime import datetime, timedelta

# Add the server directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'server'))

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'server.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
from events.models import Event
from notifications.models import EventConfirmation
from django.utils import timezone

User = get_user_model()

# Configuration
TEST_USER_EMAIL = "testuser@example.com"  # Change this to your test user email
TEST_LOCATION = {
    "latitude": 37.7749,
    "longitude": -122.4194,  # San Francisco coordinates
}

def get_auth_token():
    """Get auth token for API requests"""
    # This is just a placeholder - you would implement your actual auth logic here
    return "your_auth_token"

def create_test_event():
    """Create a test event for the "Still happening" feature"""
    print("\n=== Creating Test Event ===")
    
    try:
        # Get the test user
        user = User.objects.get(email=TEST_USER_EMAIL)
        print(f"✅ Found test user: {user.email}")
    except User.DoesNotExist:
        print(f"❌ Test user {TEST_USER_EMAIL} not found.")
        print("💡 Please create a test user first or specify an existing user email.")
        return None
    
    # Create a test event near the specified location
    event = Event.objects.create(
        title="Test Still Happening Event",
        description="This is a test event for the 'Still happening' feature",
        latitude=TEST_LOCATION["latitude"],
        longitude=TEST_LOCATION["longitude"],
        start_time=timezone.now(),
        end_time=timezone.now() + timedelta(hours=3),
        created_by=user,
        is_public=True,
    )
    
    print(f"✅ Created test event: {event.title}")
    print(f"📍 Location: {event.latitude}, {event.longitude}")
    print(f"🕒 Start time: {event.start_time}")
    print(f"🕒 End time: {event.end_time}")
    print(f"🆔 Event ID: {event.id}")
    
    return event

def create_event_confirmation(event):
    """Create an event confirmation request"""
    if not event:
        return None
    
    print("\n=== Creating Event Confirmation ===")
    
    try:
        # Get the test user
        user = User.objects.get(email=TEST_USER_EMAIL)
    except User.DoesNotExist:
        print(f"❌ Test user {TEST_USER_EMAIL} not found.")
        return None
    
    # Create a pending confirmation
    confirmation = EventConfirmation.objects.create(
        event=event,
        user=user,
        status="pending",
        created_at=timezone.now(),
    )
    
    print(f"✅ Created event confirmation (ID: {confirmation.id})")
    return confirmation

def test_notification_sending(event, confirmation):
    """Test sending a "Still happening" notification"""
    if not event or not confirmation:
        return False
    
    print("\n=== Testing Notification Sending ===")
    print("To fully test this feature in your app:")
    print("1. Ensure the app is running with LocationEventMonitor active")
    print("2. Make sure 'Still happening' notifications are enabled in settings")
    print("3. The app should detect the nearby event and show a notification")
    
    # For manually testing the notification, provide details about the event
    print("\n=== Manual Testing Information ===")
    print(f"Event ID: {event.id}")
    print(f"Confirmation ID: {confirmation.id}")
    print(f"Event location: {event.latitude}, {event.longitude}")
    
    return True

def main():
    """Main function to run the test"""
    print("=== 'Still Happening' Feature Test ===")
    print("This script creates a test event and confirmation for testing")
    print("the 'Still happening' location-based notification feature.")
    
    # Create a test event
    event = create_test_event()
    
    # Create a confirmation request
    confirmation = create_event_confirmation(event)
    
    # Test notification sending
    test_notification_sending(event, confirmation)
    
    print("\n=== Test Setup Complete ===")
    print("Launch your app to test the feature!")

if __name__ == "__main__":
    main()
