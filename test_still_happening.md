# Test the "Still happening" feature

1. Start by enabling the "Still happening" feature in your app's notification settings
2. Use this test script to simulate a location-based "Still happening" notification

```python
#!/usr/bin/env python3
"""
Test script to simulate the location event monitor and trigger a 'still happening' notification.
"""

import os
import sys
import json
import time
import requests

# Add the server directory to Python path
server_dir = os.path.join(os.path.dirname(__file__), 'server')
sys.path.append(server_dir)

# Import Django models (this will work when executed from the root directory)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'server.settings')
import django
django.setup()

from events.models import Event
from notifications.models import EventConfirmation
from django.contrib.auth import get_user_model
from django.utils import timezone

# Get the User model
User = get_user_model()

# Configuration
TEST_USER_EMAIL = "testuser@example.com"  # Replace with a test user email
TEST_LOCATION = {
    "latitude": 37.7749,
    "longitude": -122.4194,  # San Francisco coordinates
}
RADIUS_METERS = 200

def create_test_event_near_location():
    """Create a test event near the specified location"""

    print("🏙️ Creating a test event near the specified location...")

    # Get the test user
    try:
        user = User.objects.get(email=TEST_USER_EMAIL)
    except User.DoesNotExist:
        print(f"❌ Test user with email {TEST_USER_EMAIL} does not exist")
        print("💡 Create a test user first or specify an existing user's email")
        return None

    # Create a test event
    event = Event.objects.create(
        title="Test Still Happening Event",
        description="This is a test event for the 'Still happening' feature",
        latitude=TEST_LOCATION["latitude"],
        longitude=TEST_LOCATION["longitude"],
        start_time=timezone.now(),
        end_time=timezone.now() + timezone.timedelta(hours=2),
        created_by=user,
    )

    print(f"✅ Created test event: {event.title} (ID: {event.id})")
    return event

def create_event_confirmation(event):
    """Create an event confirmation for testing"""

    if not event:
        return None

    # Get the test user
    try:
        user = User.objects.get(email=TEST_USER_EMAIL)
    except User.DoesNotExist:
        print(f"❌ Test user with email {TEST_USER_EMAIL} does not exist")
        return None

    # Create a confirmation
    confirmation = EventConfirmation.objects.create(
        event=event,
        user=user,
        status="pending",
    )

    print(f"✅ Created event confirmation (ID: {confirmation.id})")
    return confirmation

def send_test_notification(event, confirmation):
    """Send a test notification using Firebase Cloud Messaging"""

    if not event or not confirmation:
        return False

    # This is a simplified version. In a real app, this would be handled by your
    # NotificationApiService and the Django backend would send the actual FCM message.

    # Instead, we'll print instructions for testing manually
    print("\n📱 To test this feature in your app:")
    print("1. Make sure the LocationEventMonitor is initialized and running")
    print("2. Ensure 'Still happening' notifications are enabled in settings")
    print("3. Use the following curl command to simulate a notification:")

    fcm_server_key = "YOUR_FCM_SERVER_KEY"  # Replace with your actual FCM server key
    device_token = "YOUR_DEVICE_TOKEN"      # Replace with an actual device token

    notification_data = {
        "type": "still_there",
        "action_type": "still_there",
        "dialog_title": "Still Happening?",
        "dialog_description": f"We noticed you're near '{event.title}'. Is this event still happening?",
        "dialog_image_url": "https://via.placeholder.com/300x200/4CAF50/FFFFFF?text=Event+Still+Happening%3F",
        "event_id": str(event.id),
        "confirmation_id": str(confirmation.id),
        "latitude": str(event.latitude),
        "longitude": str(event.longitude),
    }

    curl_cmd = f"""
    curl -X POST -H "Authorization: key={fcm_server_key}" \\
      -H "Content-Type: application/json" \\
      -d '{{
        "to": "{device_token}",
        "notification": {{
          "title": "Still Happening?",
          "body": "Is {event.title} still happening?"
        }},
        "data": {json.dumps(notification_data)}
      }}' \\
      https://fcm.googleapis.com/fcm/send
    """

    print("\nCURL command:")
    print(curl_cmd)

    print("\n💡 Alternative testing method:")
    print("1. Run your app in debug mode")
    print("2. Use the following Python command to create a confirmation directly in the database:")

    python_cmd = f"""
    # In your Django shell:
    from events.models import Event
    from notifications.models import EventConfirmation
    from django.contrib.auth import get_user_model

    User = get_user_model()
    user = User.objects.get(email="{TEST_USER_EMAIL}")
    event = Event.objects.get(id={event.id})

    # Create a confirmation
    confirmation = EventConfirmation.objects.create(
        event=event,
        user=user,
        status="pending",
    )
    print(f"Created confirmation with ID: {{confirmation.id}}")
    """

    print(python_cmd)

    return True

def main():
    """Main function to run the test"""

    print("🧪 Testing 'Still happening' notification feature")
    print("=" * 60)
    print(f"Test user email: {TEST_USER_EMAIL}")
    print(f"Test location: {TEST_LOCATION}")
    print(f"Radius: {RADIUS_METERS} meters")
    print("=" * 60)

    # Create a test event
    event = create_test_event_near_location()

    # Create a confirmation
    confirmation = create_event_confirmation(event)

    # Send a test notification
    send_test_notification(event, confirmation)

    print("\n✅ Test setup complete!")
    print("Now run your app and test the 'Still happening' feature")

if __name__ == "__main__":
    main()
```

## Manual Testing Steps

1. Make sure your Django server is running.
2. Run this test script to create a test event and confirmation in the database.
3. Launch your app on a device or emulator.
4. Go to Notification Settings and ensure "Still Happening Notifications" is enabled.
5. Navigate to a screen where the LocationEventMonitor is active.
6. The app should detect you're near the test event and show a "Still happening" notification.
7. Tap on the notification to see the ActionConfirmationDialog.
8. Test both "Yes" and "No" responses to ensure they're handled correctly.

## Troubleshooting

- If you don't receive notifications, check your device's location permissions.
- Verify that the LocationEventMonitor is running by looking for the "Checking for nearby events" log message.
- Check the Firebase console to ensure your FCM tokens are registered correctly.
- On iOS, make sure background location permissions are enabled.
