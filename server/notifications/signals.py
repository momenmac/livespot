"""
Notification system signal handlers
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import NotificationSettings


@receiver(post_save, sender=User)
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
