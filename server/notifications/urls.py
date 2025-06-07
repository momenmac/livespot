from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationSettingsViewSet, FCMTokenViewSet, NotificationHistoryViewSet,
    FriendRequestViewSet, EventConfirmationViewSet, NotificationQueueViewSet, NotificationAPIView
)

# Create router for ViewSets
router = DefaultRouter()
router.register(r'settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'fcm-tokens', FCMTokenViewSet, basename='fcm-tokens')
router.register(r'history', NotificationHistoryViewSet, basename='notification-history')
router.register(r'friend-requests', FriendRequestViewSet, basename='friend-requests')
router.register(r'event-confirmations', EventConfirmationViewSet, basename='event-confirmations')
router.register(r'queue', NotificationQueueViewSet, basename='notification-queue')

# Create NotificationAPIView instance for action-based routing
api_view = NotificationAPIView.as_view({
    'post': 'send_still_there_confirmation',
})

test_notification_view = NotificationAPIView.as_view({
    'post': 'test_notification',
})

send_direct_view = NotificationAPIView.as_view({
    'post': 'send_direct',
})

app_name = 'notifications'

urlpatterns = [
    path('', include(router.urls)),
    path('actions/send-still-there-confirmation/', api_view, name='send-still-there-confirmation'),
    path('actions/test-notification/', test_notification_view, name='test-notification'),
    path('actions/send-direct/', send_direct_view, name='send-direct'),
]
