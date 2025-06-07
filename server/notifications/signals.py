"""
Notification system signal handlers
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from .models import NotificationSettings

# Get the custom Account model
Account = get_user_model()


@receiver(post_save, sender=Account)
def create_notification_settings(sender, instance, created, **kwargs):
    """Create default notification settings when a new user is created"""
    if created:
        NotificationSettings.objects.get_or_create(
            user=instance,
            defaults={
                'friend_requests': True,
                'events': True,
                'reminders': True,
                'nearby_events': True,
                'system_notifications': True,
            }
        )
