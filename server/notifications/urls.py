from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationSettingsViewSet, FCMTokenViewSet, NotificationHistoryViewSet,
    FriendRequestViewSet, EventConfirmationViewSet, NotificationAPIView
)

# Create router for ViewSets
router = DefaultRouter()
router.register(r'settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'fcm-tokens', FCMTokenViewSet, basename='fcm-tokens')
router.register(r'history', NotificationHistoryViewSet, basename='notification-history')
router.register(r'friend-requests', FriendRequestViewSet, basename='friend-requests')
router.register(r'event-confirmations', EventConfirmationViewSet, basename='event-confirmations')
router.register(r'api', NotificationAPIView, basename='notification-api')

app_name = 'notifications'

urlpatterns = [
    path('', include(router.urls)),
]
