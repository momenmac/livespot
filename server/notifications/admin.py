from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.utils.safestring import mark_safe
from .models import (
    NotificationSettings, FCMToken, NotificationHistory, 
    FriendRequest, EventConfirmation, NotificationQueue, NotificationTemplate
)


@admin.register(NotificationSettings)
class NotificationSettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'friend_requests', 'events', 'reminders', 'nearby_events', 'system_notifications', 'updated_at']
    list_filter = ['friend_requests', 'events', 'reminders', 'nearby_events', 'system_notifications', 'created_at']
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(FCMToken)
class FCMTokenAdmin(admin.ModelAdmin):
    list_display = ['user', 'device_platform', 'is_active', 'token_preview', 'last_used']
    list_filter = ['device_platform', 'is_active', 'created_at']
    search_fields = ['user__username', 'user__email', 'token']
    readonly_fields = ['created_at', 'last_used']
    
    def token_preview(self, obj):
        return f"{obj.token[:20]}..." if len(obj.token) > 20 else obj.token
    token_preview.short_description = 'Token Preview'


@admin.register(NotificationHistory)
class NotificationHistoryAdmin(admin.ModelAdmin):
    list_display = ['user', 'notification_type', 'title', 'sent', 'delivered', 'read', 'processed', 'created_at']
    list_filter = ['notification_type', 'sent', 'delivered', 'read', 'processed', 'created_at']
    search_fields = ['user__username', 'user__email', 'title', 'body']
    readonly_fields = ['id', 'created_at', 'sent_at', 'delivered_at', 'read_at', 'processed_at']
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('id', 'user', 'notification_type', 'title', 'body')
        }),
        ('Status', {
            'fields': ('sent', 'delivered', 'read', 'processed')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'sent_at', 'delivered_at', 'read_at', 'processed_at')
        }),
        ('Data', {
            'fields': ('data',),
            'classes': ('collapse',)
        }),
    )
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


@admin.register(FriendRequest)
class FriendRequestAdmin(admin.ModelAdmin):
    list_display = ['from_user', 'to_user', 'status', 'notification_sent', 'created_at', 'responded_at']
    list_filter = ['status', 'notification_sent', 'created_at']
    search_fields = ['from_user__username', 'to_user__username', 'from_user__email', 'to_user__email']
    readonly_fields = ['id', 'created_at', 'responded_at']
    
    fieldsets = (
        ('Request Information', {
            'fields': ('id', 'from_user', 'to_user', 'message')
        }),
        ('Status', {
            'fields': ('status', 'notification_sent', 'notification_id')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'responded_at')
        }),
    )


@admin.register(EventConfirmation)
class EventConfirmationAdmin(admin.ModelAdmin):
    list_display = ['event_id', 'user', 'is_still_there', 'response_received', 'requested_at', 'responded_at']
    list_filter = ['is_still_there', 'response_received', 'confirmation_request_sent', 'requested_at']
    search_fields = ['event_id', 'user__username', 'user__email', 'response_message']
    readonly_fields = ['id', 'requested_at', 'responded_at']
    date_hierarchy = 'requested_at'
    
    fieldsets = (
        ('Confirmation Information', {
            'fields': ('id', 'event_id', 'user', 'is_still_there', 'response_message')
        }),
        ('Status', {
            'fields': ('confirmation_request_sent', 'response_received', 'notification_id')
        }),
        ('Timestamps', {
            'fields': ('requested_at', 'responded_at')
        }),
    )


@admin.register(NotificationQueue)
class NotificationQueueAdmin(admin.ModelAdmin):
    list_display = ['user', 'notification_type', 'title', 'priority', 'status', 'scheduled_for', 'retry_count']
    list_filter = ['notification_type', 'priority', 'status', 'scheduled_for']
    search_fields = ['user__username', 'user__email', 'title', 'body']
    readonly_fields = ['id', 'created_at', 'updated_at', 'processing_started_at', 'processed_at']
    date_hierarchy = 'scheduled_for'
    
    fieldsets = (
        ('Queue Information', {
            'fields': ('id', 'user', 'notification_type', 'title', 'body')
        }),
        ('Priority & Scheduling', {
            'fields': ('priority', 'status', 'scheduled_for')
        }),
        ('Retry Information', {
            'fields': ('max_retries', 'retry_count', 'error_message')
        }),
        ('Processing Timestamps', {
            'fields': ('created_at', 'updated_at', 'processing_started_at', 'processed_at')
        }),
        ('Data', {
            'fields': ('data',),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['retry_failed_notifications', 'cancel_notifications']
    
    def retry_failed_notifications(self, request, queryset):
        updated = queryset.filter(status='failed').update(
            status='pending',
            retry_count=0,
            error_message='',
            processing_started_at=None
        )
        self.message_user(request, f'{updated} notifications marked for retry.')
    retry_failed_notifications.short_description = "Retry failed notifications"
    
    def cancel_notifications(self, request, queryset):
        updated = queryset.filter(status__in=['pending', 'processing']).update(
            status='cancelled'
        )
        self.message_user(request, f'{updated} notifications cancelled.')
    cancel_notifications.short_description = "Cancel selected notifications"


@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    list_display = ['name', 'notification_type', 'is_active', 'created_at', 'updated_at']
    list_filter = ['notification_type', 'is_active', 'created_at']
    search_fields = ['name', 'notification_type', 'description']
    readonly_fields = ['created_at', 'updated_at']
    
    fieldsets = (
        ('Template Information', {
            'fields': ('name', 'notification_type', 'description', 'is_active')
        }),
        ('Template Content', {
            'fields': ('title_template', 'body_template')
        }),
        ('Data & Variables', {
            'fields': ('data_template', 'available_variables'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )


# Custom admin site configuration
admin.site.site_header = 'Notification System Administration'
admin.site.site_title = 'Notification Admin'
admin.site.index_title = 'Notification Management'
