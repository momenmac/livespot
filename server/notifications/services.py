"""
Notification services for processing and sending notifications
"""
import logging
from django.utils import timezone
from django.conf import settings
from firebase_admin import messaging
import firebase_admin

from .models import NotificationQueue, FCMToken, NotificationHistory, NotificationSettings

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for processing and sending notifications"""
    
    def __init__(self):
        self.ensure_firebase_initialized()
    
    def ensure_firebase_initialized(self):
        """Ensure Firebase Admin SDK is initialized"""
        try:
            # Try to get existing app
            firebase_admin.get_app()
            logger.info("✅ Firebase Admin SDK already initialized")
        except ValueError:
            # Initialize Firebase if not already done
            try:
                from firebase_admin import credentials
                cred = credentials.Certificate('/Users/momen_mac/Desktop/flutter_application/server/firebase_service_account.json')
                firebase_admin.initialize_app(cred)
                logger.info("✅ Firebase Admin SDK initialized successfully")
            except Exception as e:
                logger.error(f"❌ Failed to initialize Firebase Admin SDK: {e}")
                raise
    
    def process_pending_notifications(self):
        """Process all pending notifications in the queue"""
        print("🔄 DEBUG: Starting notification processing...")
        
        # Get pending notifications ordered by priority and creation time
        pending_notifications = NotificationQueue.objects.filter(
            status='pending',
            scheduled_for__lte=timezone.now()
        ).order_by('priority', 'created_at')
        
        processed_count = 0
        success_count = 0
        
        print(f"📊 DEBUG: Found {pending_notifications.count()} pending notifications")
        
        for notification in pending_notifications:
            print(f"🔄 DEBUG: Processing notification {notification.id} for user {notification.user.email}")
            
            try:
                # Mark as processing
                notification.status = 'processing'
                notification.processing_started_at = timezone.now()
                notification.save()
                
                # Send the notification
                success = self.send_notification(notification)
                
                if success:
                    notification.status = 'sent'
                    notification.processed_at = timezone.now()
                    success_count += 1
                    print(f"✅ DEBUG: Successfully sent notification {notification.id}")
                else:
                    notification.status = 'failed'
                    notification.retry_count += 1
                    print(f"❌ DEBUG: Failed to send notification {notification.id}")
                
                notification.save()
                processed_count += 1
                
            except Exception as e:
                logger.error(f"Error processing notification {notification.id}: {e}")
                notification.status = 'failed'
                notification.error_message = str(e)
                notification.retry_count += 1
                notification.save()
                processed_count += 1
                print(f"❌ DEBUG: Exception processing notification {notification.id}: {e}")
        
        result = {
            'processed': processed_count,
            'successful': success_count,
            'failed': processed_count - success_count
        }
        
        print(f"📊 DEBUG: Processing complete - {result}")
        return result
    
    def send_notification(self, notification):
        """Send a single notification via FCM"""
        print(f"📤 DEBUG: Sending notification to {notification.user.email}")
        
        # Check if user has notification settings and notifications enabled
        try:
            settings = notification.user.notification_settings
            
            # Check specific notification type
            if notification.notification_type == 'new_follower' and not settings.follow_notifications:
                print(f"⚠️ DEBUG: Follow notifications disabled for {notification.user.email}")
                return False
                
        except Exception as e:
            print(f"⚠️ DEBUG: Could not check notification settings: {e}")
            # Continue anyway - default to sending
        
        # Get active FCM tokens for the user
        fcm_tokens = FCMToken.objects.filter(
            user=notification.user,
            is_active=True
        )
        
        if not fcm_tokens.exists():
            print(f"❌ DEBUG: No active FCM tokens for {notification.user.email}")
            notification.error_message = "No active FCM tokens"
            return False
        
        tokens = [token.token for token in fcm_tokens]
        print(f"📱 DEBUG: Found {len(tokens)} FCM tokens for {notification.user.email}")
        
        try:
            # Create Firebase message
            if len(tokens) == 1:
                # Single token
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=notification.title,
                        body=notification.body
                    ),
                    data={k: str(v) for k, v in notification.data.items()},  # FCM requires string values
                    token=tokens[0]
                )
                
                response = messaging.send(message)
                print(f"✅ DEBUG: FCM single message sent: {response}")
                
                # Log to notification history
                self.log_notification_history(notification, True)
                return True
                
            else:
                # Multiple tokens - use multicast
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=notification.title,
                        body=notification.body
                    ),
                    data={k: str(v) for k, v in notification.data.items()},
                    tokens=tokens
                )
                
                response = messaging.send_multicast(message)
                print(f"✅ DEBUG: FCM multicast sent - Success: {response.success_count}, Failed: {response.failure_count}")
                
                # Log to notification history
                self.log_notification_history(notification, response.success_count > 0)
                
                # Mark failed tokens as inactive if needed
                if response.failure_count > 0:
                    self.handle_failed_tokens(response, tokens)
                
                return response.success_count > 0
                
        except Exception as e:
            print(f"❌ DEBUG: FCM sending error: {e}")
            logger.error(f"FCM sending error for notification {notification.id}: {e}")
            notification.error_message = str(e)
            
            # Log failed notification
            self.log_notification_history(notification, False, str(e))
            return False
    
    def log_notification_history(self, notification, success, error_message=None):
        """Log notification to history"""
        try:
            NotificationHistory.objects.create(
                user=notification.user,
                notification_type=notification.notification_type,
                title=notification.title,
                body=notification.body,
                data=notification.data,
                sent=success,
                sent_at=timezone.now() if success else None,
                processed=True,
                processed_at=timezone.now()
            )
            print(f"📝 DEBUG: Logged notification history for {notification.user.email}")
        except Exception as e:
            print(f"⚠️ DEBUG: Failed to log notification history: {e}")
            logger.warning(f"Failed to log notification history: {e}")
    
    def handle_failed_tokens(self, response, tokens):
        """Handle failed FCM tokens by marking them as inactive"""
        if not hasattr(response, 'responses'):
            return
            
        for i, resp in enumerate(response.responses):
            if not resp.success and i < len(tokens):
                token = tokens[i]
                error_code = resp.exception.code if resp.exception else 'unknown'
                
                # Mark token as inactive for certain error codes
                if error_code in ['NOT_FOUND', 'UNREGISTERED', 'INVALID_ARGUMENT']:
                    try:
                        FCMToken.objects.filter(token=token).update(is_active=False)
                        print(f"🔧 DEBUG: Marked FCM token as inactive due to error: {error_code}")
                    except Exception as e:
                        print(f"⚠️ DEBUG: Failed to mark token as inactive: {e}")
    
    def send_test_notification(self, user, title="Test Notification", body="This is a test notification"):
        """Send a test notification to a specific user"""
        print(f"🧪 DEBUG: Sending test notification to {user.email}")
        
        # Create test notification in queue
        notification = NotificationQueue.objects.create(
            user=user,
            notification_type='test',
            title=title,
            body=body,
            data={
                'type': 'test',
                'timestamp': timezone.now().isoformat()
            },
            priority='high'
        )
        
        # Send immediately
        return self.send_notification(notification)


# Singleton instance
notification_service = NotificationService()


def process_notifications():
    """Convenience function to process pending notifications"""
    return notification_service.process_pending_notifications()


def send_test_notification(user, title="Test", body="Test notification"):
    """Convenience function to send test notification"""
    return notification_service.send_test_notification(user, title, body)
