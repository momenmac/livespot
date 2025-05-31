from django.db import models
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
import uuid

User = get_user_model()


class NotificationSettings(models.Model):
    """User notification preferences"""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notification_settings')
    friend_requests = models.BooleanField(default=True)
    events = models.BooleanField(default=True)
    reminders = models.BooleanField(default=True)
    nearby_events = models.BooleanField(default=True)
    system_notifications = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'notification_settings'

    def __str__(self):
        return f"{self.user.username} notification settings"


class FCMToken(models.Model):
    """FCM tokens for push notifications"""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='fcm_tokens')
    token = models.TextField(unique=True)
    device_platform = models.CharField(max_length=20, default='unknown')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'fcm_tokens'
        unique_together = ['user', 'token']

    def __str__(self):
        return f"{self.user.username} - {self.device_platform}"


class NotificationHistory(models.Model):
    """Notification history for tracking sent notifications"""
    NOTIFICATION_TYPES = [
        ('friend_request', 'Friend Request'),
        ('friend_request_accepted', 'Friend Request Accepted'),
        ('new_event', 'New Event'),
        ('still_there', 'Still There Confirmation'),
        ('event_update', 'Event Update'),
        ('event_cancelled', 'Event Cancelled'),
        ('nearby_event', 'Nearby Event'),
        ('reminder', 'Reminder'),
        ('system', 'System Notification'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=50, choices=NOTIFICATION_TYPES)
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField(default=dict)
    
    # Status tracking
    sent = models.BooleanField(default=False)
    delivered = models.BooleanField(default=False)
    read = models.BooleanField(default=False)
    processed = models.BooleanField(default=False)
    
    # Timestamps
    sent_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notification_history'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.notification_type} for {self.user.username}"


class FriendRequest(models.Model):
    """Friend request model"""
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    from_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_friend_requests')
    to_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='received_friend_requests')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    message = models.TextField(blank=True, default='')
    
    # Notification tracking
    notification_sent = models.BooleanField(default=False)
    notification_id = models.UUIDField(null=True, blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'friend_requests'
        unique_together = ['from_user', 'to_user']

    def __str__(self):
        return f"{self.from_user.username} -> {self.to_user.username} ({self.status})"


class EventConfirmation(models.Model):
    """Event confirmation responses for 'still there' notifications"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event_id = models.CharField(max_length=255)  # Reference to your event model
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='event_confirmations')
    is_still_there = models.BooleanField()
    response_message = models.TextField(blank=True, default='')
    
    # Notification tracking
    notification_id = models.UUIDField(null=True, blank=True)
    confirmation_request_sent = models.BooleanField(default=False)
    response_received = models.BooleanField(default=False)
    
    # Timestamps
    requested_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'event_confirmations'
        unique_together = ['event_id', 'user', 'requested_at']

    def __str__(self):
        return f"Event {self.event_id} - {self.user.username} - {'Still there' if self.is_still_there else 'Not there'}"


class NotificationQueue(models.Model):
    """Queue for batch sending notifications"""
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),        ('sent', 'Sent'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='queued_notifications')
    notification_type = models.CharField(max_length=50)
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField(default=dict)
    
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='normal')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    # Scheduling
    scheduled_for = models.DateTimeField(default=timezone.now)
    max_retries = models.IntegerField(default=3)
    retry_count = models.IntegerField(default=0)
    
    # Processing tracking
    processing_started_at = models.DateTimeField(null=True, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    error_message = models.TextField(blank=True, default='')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'notification_queue'
        ordering = ['priority', 'scheduled_for']

    def __str__(self):
        return f"{self.notification_type} for {self.user.username} - {self.status}"

    def can_retry(self):
        return self.retry_count < self.max_retries and self.status == 'failed'


class NotificationTemplate(models.Model):
    """Reusable notification templates"""
    name = models.CharField(max_length=100, unique=True)
    notification_type = models.CharField(max_length=50)
    title_template = models.CharField(max_length=255)
    body_template = models.TextField()
    data_template = models.JSONField(default=dict)
    
    # Template variables documentation
    available_variables = models.JSONField(default=list, help_text="List of available template variables")
    description = models.TextField(blank=True)
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'notification_templates'

    def __str__(self):
        return f"{self.name} ({self.notification_type})"

    def render(self, context):
        """Render template with provided context"""
        from django.template import Template, Context
        
        title = Template(self.title_template).render(Context(context))
        body = Template(self.body_template).render(Context(context))
        
        return {
            'title': title,
            'body': body,
            'data': self.data_template
        }
