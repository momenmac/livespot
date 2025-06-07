from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db import transaction
import firebase_admin
from firebase_admin import messaging
import json
import logging

# Get the custom Account model
Account = get_user_model()

from .models import (
    NotificationSettings, FCMToken, NotificationHistory, 
    FriendRequest, EventConfirmation, NotificationQueue
)
from .serializers import (
    NotificationSettingsSerializer, FCMTokenSerializer,
    NotificationHistorySerializer, FriendRequestSerializer,
    EventConfirmationSerializer, NotificationQueueSerializer
)

logger = logging.getLogger(__name__)


class NotificationSettingsViewSet(viewsets.ModelViewSet):
    """API for managing user notification settings"""
    serializer_class = NotificationSettingsSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationSettings.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get', 'patch'])
    def my_settings(self, request):
        """Get or update current user's notification settings"""
        settings, created = NotificationSettings.objects.get_or_create(
            user=request.user
        )
        
        if request.method == 'GET':
            serializer = self.get_serializer(settings)
            return Response(serializer.data)
        
        elif request.method == 'PATCH':
            serializer = self.get_serializer(settings, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class FCMTokenViewSet(viewsets.ModelViewSet):
    """API for managing FCM tokens"""
    serializer_class = FCMTokenSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return FCMToken.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['post'])
    def register_token(self, request):
        """Register or update FCM token for the current user"""
        token = request.data.get('token')
        platform = request.data.get('platform', 'unknown')

        if not token:
            return Response(
                {'error': 'Token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Deactivate old tokens for this user on the same platform
        FCMToken.objects.filter(
            user=request.user, 
            device_platform=platform
        ).update(is_active=False)

        # Create or update the token
        fcm_token, created = FCMToken.objects.update_or_create(
            user=request.user,
            token=token,
            defaults={
                'device_platform': platform,
                'is_active': True,
                'last_used': timezone.now()
            }
        )

        serializer = self.get_serializer(fcm_token)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def deactivate_token(self, request):
        """Deactivate FCM token"""
        token = request.data.get('token')
        
        if not token:
            return Response(
                {'error': 'Token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        updated = FCMToken.objects.filter(
            user=request.user, 
            token=token
        ).update(is_active=False)

        if updated:
            return Response({'message': 'Token deactivated successfully'})
        else:
            return Response(
                {'error': 'Token not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )


class NotificationHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    """API for viewing notification history"""
    serializer_class = NotificationHistorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationHistory.objects.filter(user=self.request.user)

    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        """Get count of unread notifications"""
        count = self.get_queryset().filter(read=False).count()
        return Response({'unread_count': count})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        """Mark all notifications as read"""
        updated = self.get_queryset().filter(read=False).update(
            read=True,
            read_at=timezone.now()
        )
        return Response({'marked_read': updated})

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """Mark specific notification as read"""
        notification = self.get_object()
        notification.read = True
        notification.read_at = timezone.now()
        notification.save()
        
        serializer = self.get_serializer(notification)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def mark_unread(self, request, pk=None):
        """Mark specific notification as unread"""
        notification = self.get_object()
        notification.read = False
        notification.read_at = None
        notification.save()
        
        serializer = self.get_serializer(notification)
        return Response(serializer.data)

    @action(detail=True, methods=['delete'])
    def delete_notification(self, request, pk=None):
        """Delete specific notification"""
        notification = self.get_object()
        notification.delete()
        return Response({'message': 'Notification deleted successfully'}, status=status.HTTP_204_NO_CONTENT)


class FriendRequestViewSet(viewsets.ModelViewSet):
    """API for managing friend requests"""
    serializer_class = FriendRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return FriendRequest.objects.filter(
            models.Q(from_user=self.request.user) | 
            models.Q(to_user=self.request.user)
        )

    @action(detail=False, methods=['post'])
    def send_request(self, request):
        """Send a friend request with notification"""
        to_user_id = request.data.get('to_user_id')
        message = request.data.get('message', '')

        try:
            to_user = Account.objects.get(id=to_user_id)
        except Account.DoesNotExist:
            return Response(
                {'error': 'User not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )

        if to_user == request.user:
            return Response(
                {'error': 'Cannot send friend request to yourself'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if request already exists
        existing_request = FriendRequest.objects.filter(
            from_user=request.user,
            to_user=to_user,
            status__in=['pending', 'accepted']
        ).first()

        if existing_request:
            return Response(
                {'error': 'Friend request already exists'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create friend request
        friend_request = FriendRequest.objects.create(
            from_user=request.user,
            to_user=to_user,
            message=message
        )

        # Send notification
        try:
            notification_sent = self._send_friend_request_notification(
                friend_request
            )
            friend_request.notification_sent = notification_sent
            friend_request.save()
        except Exception as e:
            logger.error(f"Failed to send friend request notification: {e}")

        serializer = self.get_serializer(friend_request)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        """Respond to a friend request (accept/reject)"""
        friend_request = self.get_object()
        response = request.data.get('response')  # 'accepted' or 'rejected'

        if friend_request.to_user != request.user:
            return Response(
                {'error': 'You can only respond to requests sent to you'}, 
                status=status.HTTP_403_FORBIDDEN
            )

        if friend_request.status != 'pending':
            return Response(
                {'error': 'This request has already been responded to'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        if response not in ['accepted', 'rejected']:
            return Response(
                {'error': 'Response must be "accepted" or "rejected"'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update request status
        friend_request.status = response
        friend_request.responded_at = timezone.now()
        friend_request.save()

        # Send notification to requester if accepted
        if response == 'accepted':
            try:
                self._send_friend_request_accepted_notification(friend_request)
            except Exception as e:
                logger.error(f"Failed to send acceptance notification: {e}")

        serializer = self.get_serializer(friend_request)
        return Response(serializer.data)

    def _send_friend_request_notification(self, friend_request):
        """Send friend request notification"""
        # Get FCM tokens for the target user
        tokens = FCMToken.objects.filter(
            user=friend_request.to_user,
            is_active=True
        ).values_list('token', flat=True)

        if not tokens:
            return False

        # Create notification data
        notification_data = {
            'type': 'friend_request',
            'fromUserId': str(friend_request.from_user.id),
            'fromUserName': friend_request.from_user.username,
            'fromUserAvatar': '',  # Add avatar URL if available
            'requestId': str(friend_request.id),
            'message': friend_request.message,
        }

        # Create Firebase message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title='Friend Request',
                body=f'{friend_request.from_user.username} wants to be your friend'
            ),
            data=notification_data,
            tokens=list(tokens)
        )

        # Send notification
        response = messaging.send_multicast(message)
        
        # Log notification
        NotificationHistory.objects.create(
            user=friend_request.to_user,
            notification_type='friend_request',
            title='Friend Request',
            body=f'{friend_request.from_user.username} wants to be your friend',
            data=notification_data,
            sent=response.success_count > 0,
            sent_at=timezone.now() if response.success_count > 0 else None
        )

        return response.success_count > 0

    def _send_friend_request_accepted_notification(self, friend_request):
        """Send friend request accepted notification"""
        # Get FCM tokens for the requester
        tokens = FCMToken.objects.filter(
            user=friend_request.from_user,
            is_active=True
        ).values_list('token', flat=True)

        if not tokens:
            return False

        # Create notification data
        notification_data = {
            'type': 'friend_request_accepted',
            'fromUserId': str(friend_request.to_user.id),
            'fromUserName': friend_request.to_user.username,
            'requestId': str(friend_request.id),
        }

        # Create Firebase message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title='Friend Request Accepted',
                body=f'{friend_request.to_user.username} accepted your friend request!'
            ),
            data=notification_data,
            tokens=list(tokens)
        )

        # Send notification
        response = messaging.send_multicast(message)
        
        # Log notification
        NotificationHistory.objects.create(
            user=friend_request.from_user,
            notification_type='friend_request_accepted',
            title='Friend Request Accepted',
            body=f'{friend_request.to_user.username} accepted your friend request!',
            data=notification_data,
            sent=response.success_count > 0,
            sent_at=timezone.now() if response.success_count > 0 else None
        )

        return response.success_count > 0


class EventConfirmationViewSet(viewsets.ModelViewSet):
    """API for managing event confirmations"""
    serializer_class = EventConfirmationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EventConfirmation.objects.filter(user=self.request.user)

    @action(detail=False, methods=['post'])
    def respond_to_confirmation(self, request):
        """Respond to an event confirmation request"""
        confirmation_id = request.data.get('confirmation_id')
        is_still_there = request.data.get('is_still_there')
        response_message = request.data.get('message', '')

        try:
            confirmation = EventConfirmation.objects.get(
                id=confirmation_id,
                user=request.user
            )
        except EventConfirmation.DoesNotExist:
            return Response(
                {'error': 'Confirmation request not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )

        if confirmation.response_received:
            return Response(
                {'error': 'You have already responded to this confirmation'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update confirmation
        confirmation.is_still_there = is_still_there
        confirmation.response_message = response_message
        confirmation.response_received = True
        confirmation.responded_at = timezone.now()
        confirmation.save()

        # Log the response
        NotificationHistory.objects.create(
            user=request.user,
            notification_type='still_there_response',
            title='Event Confirmation Response',
            body=f'Responded: {"Still there" if is_still_there else "Not there"}',
            data={
                'confirmation_id': str(confirmation_id),
                'is_still_there': is_still_there,
                'event_id': confirmation.event_id,
            },
            processed=True,
            processed_at=timezone.now()
        )

        serializer = self.get_serializer(confirmation)
        return Response(serializer.data)


class NotificationQueueViewSet(viewsets.ReadOnlyModelViewSet):
    """API for viewing notification queue (admin/debugging)"""
    serializer_class = NotificationQueueSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Only allow users to see their own queued notifications
        return NotificationQueue.objects.filter(user=self.request.user)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Get notification queue statistics"""
        queryset = self.get_queryset()
        stats = {
            'total': queryset.count(),
            'pending': queryset.filter(status='pending').count(),
            'processing': queryset.filter(status='processing').count(),
            'sent': queryset.filter(status='sent').count(),
            'failed': queryset.filter(status='failed').count(),
            'cancelled': queryset.filter(status='cancelled').count(),
        }
        return Response(stats)

class NotificationAPIView(viewsets.ViewSet):
    """General notification API endpoints"""
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['post'])
    def send_still_there_confirmation(self, request):
        """Send 'still there' confirmation request to event participants"""
        event_id = request.data.get('event_id')
        user_ids = request.data.get('user_ids', [])
        event_title = request.data.get('event_title', 'Event')
        event_image_url = request.data.get('event_image_url', '')

        if not event_id or not user_ids:
            return Response(
                {'error': 'event_id and user_ids are required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        confirmations_created = []
        notifications_sent = 0

        for user_id in user_ids:
            try:
                user = Account.objects.get(id=user_id)
                
                # Create confirmation request
                confirmation = EventConfirmation.objects.create(
                    event_id=event_id,
                    user=user,
                    is_still_there=False,  # Default value
                    confirmation_request_sent=True
                )

                # Send notification
                if self._send_still_there_notification(confirmation, event_title, event_image_url):
                    notifications_sent += 1

                confirmations_created.append(str(confirmation.id))

            except Account.DoesNotExist:
                logger.warning(f"User {user_id} not found for still there confirmation")
                continue
            except Exception as e:
                logger.error(f"Failed to create confirmation for user {user_id}: {e}")
                continue

        return Response({
            'confirmations_created': len(confirmations_created),
            'notifications_sent': notifications_sent,
            'confirmation_ids': confirmations_created
        })

    def _send_still_there_notification(self, confirmation, event_title, event_image_url):
        """Send still there confirmation notification"""
        # Get FCM tokens for the user
        tokens = FCMToken.objects.filter(
            user=confirmation.user,
            is_active=True
        ).values_list('token', flat=True)

        if not tokens:
            return False

        # Create notification data
        notification_data = {
            'type': 'still_there',
            'eventId': confirmation.event_id,
            'eventTitle': event_title,
            'eventImageUrl': event_image_url,
            'confirmationId': str(confirmation.id),
            'originalEventDate': confirmation.requested_at.isoformat(),
        }

        # Create Firebase message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title='Still There?',
                body=f'Is {event_title} still happening?'
            ),
            data=notification_data,
            tokens=list(tokens)
        )

        try:
            # Send notification
            response = messaging.send_multicast(message)
            
            # Log notification
            NotificationHistory.objects.create(
                user=confirmation.user,
                notification_type='still_there',
                title='Still There?',
                body=f'Is {event_title} still happening?',
                data=notification_data,
                sent=response.success_count > 0,
                sent_at=timezone.now() if response.success_count > 0 else None
            )

            return response.success_count > 0
        except Exception as e:
            logger.error(f"Failed to send still there notification: {e}")
            return False

    @action(detail=False, methods=['post'])
    def test_notification(self, request):
        """Send test notification to current user"""
        notification_type = request.data.get('type', 'system')
        title = request.data.get('title', 'Test Notification')
        body = request.data.get('body', 'This is a test notification')

        # Get FCM tokens for current user
        tokens = FCMToken.objects.filter(
            user=request.user,
            is_active=True
        ).values_list('token', flat=True)

        if not tokens:
            return Response(
                {'error': 'No active FCM tokens found for user'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create test notification data
        notification_data = {
            'type': notification_type,
            'test': 'true',
            'timestamp': timezone.now().isoformat(),
        }

        # Create Firebase message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=notification_data,
            tokens=list(tokens)
        )

        try:
            # Send notification
            response = messaging.send_multicast(message)
            
            # Log notification
            NotificationHistory.objects.create(
                user=request.user,
                notification_type=notification_type,
                title=title,
                body=body,
                data=notification_data,
                sent=response.success_count > 0,
                sent_at=timezone.now() if response.success_count > 0 else None
            )

            return Response({
                'success': True,
                'sent_count': response.success_count,
                'failure_count': response.failure_count
            })
        except Exception as e:
            logger.error(f"Failed to send test notification: {e}")
            return Response(
                {'error': f'Failed to send notification: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def send_direct(self, request):
        """
        Send a direct FCM notification without storing in notification queue
        Used for message notifications that should not be persisted
        """
        try:
            recipient_user_id = request.data.get('recipient_user_id')
            notification_type = request.data.get('notification_type', 'message')
            title = request.data.get('title', 'Notification')
            body = request.data.get('body', '')
            data = request.data.get('data', {})
            priority = request.data.get('priority', 'normal')
            android_config = request.data.get('android', {})
            apns_config = request.data.get('apns', {})

            if not recipient_user_id:
                return Response(
                    {'error': 'recipient_user_id is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get recipient user
            try:
                recipient_user = Account.objects.get(id=recipient_user_id)
            except Account.DoesNotExist:
                return Response(
                    {'error': 'Recipient user not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )

            # Get active FCM tokens for recipient
            active_tokens = FCMToken.objects.filter(
                user=recipient_user,
                is_active=True
            ).values_list('token', flat=True)

            if not active_tokens:
                return Response(
                    {'error': 'No active FCM tokens found for recipient'}, 
                    status=status.HTTP_404_NOT_FOUND
                )

            # Convert data to strings (FCM requirement)
            fcm_data = {str(k): str(v) for k, v in data.items()}
            
            # Add notification metadata
            fcm_data.update({
                'notification_type': notification_type,
                'sender_id': str(request.user.id),
                'sent_at': timezone.now().isoformat(),
            })

            # Set priority
            android_priority = 'high' if priority == 'high' else 'normal'
            
            # Build Android config
            android_notification_config = android_config.get('notification', {})
            android_notification = messaging.AndroidNotification(
                click_action='FLUTTER_NOTIFICATION_CLICK',
                priority=android_priority,
                channel_id=android_notification_config.get('channel_id', 'default'),
            )
            
            # Add grouping if specified
            if 'group_key' in android_notification_config:
                android_notification.tag = android_notification_config.get('group_key')
            
            android_cfg = messaging.AndroidConfig(
                priority=android_priority,
                notification=android_notification
            )
            
            # Build APNS config  
            apns_payload = apns_config.get('payload', {})
            apns_aps = apns_payload.get('aps', {})
            apns_cfg = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        content_available=True,
                        category=apns_aps.get('category', 'MESSAGE'),
                        thread_id=apns_aps.get('thread-id', None),
                    )
                )
            )
            
            # Create Firebase message
            if len(active_tokens) == 1:
                # Single token
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body
                    ),
                    data=fcm_data,
                    token=list(active_tokens)[0],
                    android=android_cfg,
                    apns=apns_cfg
                )
                
                response = messaging.send(message)
                success_count = 1
                failure_count = 0
                
            else:
                # Multiple tokens
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=title,
                        body=body
                    ),
                    data=fcm_data,
                    tokens=list(active_tokens),
                    android=android_cfg,
                    apns=apns_cfg
                )
                
                response = messaging.send_multicast(message)
                success_count = response.success_count
                failure_count = response.failure_count

            logger.info(f"Direct notification sent - Success: {success_count}, Failed: {failure_count}")

            return Response({
                'success': True,
                'sent_count': success_count,
                'failure_count': failure_count,
                'message': f'Notification sent to {success_count} devices'
            })

        except Exception as e:
            logger.error(f"Failed to send direct notification: {e}")
            return Response(
                {'error': f'Failed to send notification: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
