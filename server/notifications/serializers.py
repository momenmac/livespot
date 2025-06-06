from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    NotificationSettings, FCMToken, NotificationHistory, 
    FriendRequest, EventConfirmation, NotificationQueue
)

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Basic user serializer for notifications"""
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name']
        read_only_fields = ['id', 'email']


class NotificationSettingsSerializer(serializers.ModelSerializer):
    """Serializer for notification settings"""
    class Meta:
        model = NotificationSettings
        fields = [
            'friend_requests', 'events', 'reminders', 
            'nearby_events', 'system_notifications', 'follow_notifications',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']


class FCMTokenSerializer(serializers.ModelSerializer):
    """Serializer for FCM tokens"""
    user = UserSerializer(read_only=True)

    class Meta:
        model = FCMToken
        fields = [
            'id', 'user', 'token', 'device_platform', 
            'is_active', 'created_at', 'last_used'
        ]
        read_only_fields = ['id', 'user', 'created_at', 'last_used']

    def validate_token(self, value):
        """Validate FCM token format"""
        if not value or len(value) < 50:
            raise serializers.ValidationError("Invalid FCM token format")
        return value


class NotificationHistorySerializer(serializers.ModelSerializer):
    """Serializer for notification history"""
    user = UserSerializer(read_only=True)

    class Meta:
        model = NotificationHistory
        fields = [
            'id', 'user', 'notification_type', 'title', 'body', 'data',
            'sent', 'delivered', 'read', 'processed',
            'sent_at', 'delivered_at', 'read_at', 'processed_at', 'created_at'
        ]
        read_only_fields = [
            'id', 'user', 'sent', 'delivered', 'sent_at', 
            'delivered_at', 'processed_at', 'created_at'
        ]


class FriendRequestSerializer(serializers.ModelSerializer):
    """Serializer for friend requests"""
    from_user = UserSerializer(read_only=True)
    to_user = UserSerializer(read_only=True)
    to_user_id = serializers.IntegerField(write_only=True, required=False)

    class Meta:
        model = FriendRequest
        fields = [
            'id', 'from_user', 'to_user', 'to_user_id', 'status', 'message',
            'notification_sent', 'created_at', 'responded_at'
        ]
        read_only_fields = [
            'id', 'from_user', 'to_user', 'notification_sent', 
            'created_at', 'responded_at'
        ]

    def validate_to_user_id(self, value):
        """Validate that the target user exists"""
        try:
            User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Target user does not exist")
        return value

    def validate(self, data):
        """Custom validation for friend requests"""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            to_user_id = data.get('to_user_id')
            if to_user_id == request.user.id:
                raise serializers.ValidationError(
                    "Cannot send friend request to yourself"
                )
        return data


class EventConfirmationSerializer(serializers.ModelSerializer):
    """Serializer for event confirmations"""
    user = UserSerializer(read_only=True)

    class Meta:
        model = EventConfirmation
        fields = [
            'id', 'event_id', 'user', 'is_still_there', 'response_message',
            'notification_id', 'confirmation_request_sent', 'response_received',
            'requested_at', 'responded_at'
        ]
        read_only_fields = [
            'id', 'user', 'notification_id', 'confirmation_request_sent',
            'requested_at', 'responded_at'
        ]


class NotificationQueueSerializer(serializers.ModelSerializer):
    """Serializer for notification queue"""
    user = UserSerializer(read_only=True)

    class Meta:
        model = NotificationQueue
        fields = [
            'id', 'user', 'notification_type', 'title', 'body', 'data',
            'priority', 'status', 'scheduled_for', 'max_retries', 'retry_count',
            'processing_started_at', 'processed_at', 'error_message',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'user', 'status', 'retry_count', 'processing_started_at',
            'processed_at', 'error_message', 'created_at', 'updated_at'
        ]


class SendNotificationSerializer(serializers.Serializer):
    """Serializer for sending notifications"""
    user_ids = serializers.ListField(
        child=serializers.IntegerField(),
        allow_empty=False,
        help_text="List of user IDs to send notification to"
    )
    notification_type = serializers.CharField(max_length=50)
    title = serializers.CharField(max_length=255)
    body = serializers.CharField()
    data = serializers.JSONField(default=dict, required=False)
    priority = serializers.ChoiceField(
        choices=['low', 'normal', 'high', 'urgent'],
        default='normal'
    )
    scheduled_for = serializers.DateTimeField(required=False)

    def validate_user_ids(self, value):
        """Validate that all user IDs exist"""
        existing_users = User.objects.filter(id__in=value).values_list('id', flat=True)
        missing_users = set(value) - set(existing_users)
        if missing_users:
            raise serializers.ValidationError(
                f"Users not found: {list(missing_users)}"
            )
        return value


class FriendRequestResponseSerializer(serializers.Serializer):
    """Serializer for friend request responses"""
    response = serializers.ChoiceField(choices=['accepted', 'rejected'])
    message = serializers.CharField(required=False, allow_blank=True)


class EventConfirmationResponseSerializer(serializers.Serializer):
    """Serializer for event confirmation responses"""
    confirmation_id = serializers.UUIDField()
    is_still_there = serializers.BooleanField()
    message = serializers.CharField(required=False, allow_blank=True)

    def validate_confirmation_id(self, value):
        """Validate that the confirmation exists and belongs to the user"""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            try:
                EventConfirmation.objects.get(id=value, user=request.user)
            except EventConfirmation.DoesNotExist:
                raise serializers.ValidationError(
                    "Confirmation not found or does not belong to you"
                )
        return value


class StillThereNotificationSerializer(serializers.Serializer):
    """Serializer for sending 'still there' notifications"""
    event_id = serializers.CharField(max_length=255)
    user_ids = serializers.ListField(
        child=serializers.IntegerField(),
        allow_empty=False
    )
    event_title = serializers.CharField(max_length=255)
    event_image_url = serializers.URLField(required=False, allow_blank=True)
    event_location = serializers.CharField(max_length=500, required=False)

    def validate_user_ids(self, value):
        """Validate that all user IDs exist"""
        existing_users = User.objects.filter(id__in=value).values_list('id', flat=True)
        missing_users = set(value) - set(existing_users)
        if missing_users:
            raise serializers.ValidationError(
                f"Users not found: {list(missing_users)}"
            )
        return value


class TestNotificationSerializer(serializers.Serializer):
    """Serializer for test notifications"""
    type = serializers.CharField(
        max_length=50, 
        default='system',
        help_text="Type of notification to test"
    )
    title = serializers.CharField(
        max_length=255, 
        default='Test Notification'
    )
    body = serializers.CharField(
        default='This is a test notification'
    )
    data = serializers.JSONField(default=dict, required=False)


class NotificationStatsSerializer(serializers.Serializer):
    """Serializer for notification statistics"""
    total_notifications = serializers.IntegerField(read_only=True)
    unread_notifications = serializers.IntegerField(read_only=True)
    notifications_by_type = serializers.DictField(read_only=True)
    recent_activity = serializers.ListField(read_only=True)
    delivery_stats = serializers.DictField(read_only=True)


class BulkNotificationSerializer(serializers.Serializer):
    """Serializer for bulk notification operations"""
    action = serializers.ChoiceField(choices=['mark_read', 'delete'])
    notification_ids = serializers.ListField(
        child=serializers.UUIDField(),
        allow_empty=False
    )

    def validate_notification_ids(self, value):
        """Validate that all notifications belong to the user"""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            user_notifications = NotificationHistory.objects.filter(
                id__in=value,
                user=request.user
            ).values_list('id', flat=True)
            
            missing_notifications = set(value) - set(user_notifications)
            if missing_notifications:
                raise serializers.ValidationError(
                    f"Notifications not found or do not belong to you: {list(missing_notifications)}"
                )
        return value
