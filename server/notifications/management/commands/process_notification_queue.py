from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db import transaction
import firebase_admin
from firebase_admin import messaging
import logging
import time

from notifications.models import NotificationQueue, FCMToken, NotificationHistory

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Process notification queue and send pending notifications'

    def add_arguments(self, parser):
        parser.add_argument(
            '--batch-size',
            type=int,
            default=100,
            help='Number of notifications to process in each batch'
        )
        parser.add_argument(
            '--max-retries',
            type=int,
            default=3,
            help='Maximum number of retries for failed notifications'
        )
        parser.add_argument(
            '--daemon',
            action='store_true',
            help='Run as daemon (continuous processing)'
        )
        parser.add_argument(
            '--sleep-interval',
            type=int,
            default=30,
            help='Sleep interval between batches when running as daemon (seconds)'
        )

    def handle(self, *args, **options):
        batch_size = options['batch_size']
        max_retries = options['max_retries']
        daemon_mode = options['daemon']
        sleep_interval = options['sleep_interval']

        self.stdout.write(
            self.style.SUCCESS(
                f'Starting notification queue processor (batch_size={batch_size}, '
                f'max_retries={max_retries}, daemon={daemon_mode})'
            )
        )

        if daemon_mode:
            self.run_daemon(batch_size, max_retries, sleep_interval)
        else:
            self.process_batch(batch_size, max_retries)

    def run_daemon(self, batch_size, max_retries, sleep_interval):
        """Run as daemon with continuous processing"""
        self.stdout.write("Running in daemon mode. Press Ctrl+C to stop.")
        
        try:
            while True:
                processed = self.process_batch(batch_size, max_retries)
                if processed == 0:
                    time.sleep(sleep_interval)
                else:
                    # Short pause between batches when actively processing
                    time.sleep(1)
        except KeyboardInterrupt:
            self.stdout.write(self.style.SUCCESS("Daemon stopped by user."))

    def process_batch(self, batch_size, max_retries):
        """Process a batch of pending notifications"""
        # Get pending notifications
        pending_notifications = NotificationQueue.objects.filter(
            status='pending',
            scheduled_for__lte=timezone.now()
        ).order_by('priority', 'scheduled_for')[:batch_size]

        if not pending_notifications:
            return 0

        processed_count = 0
        
        for notification in pending_notifications:
            try:
                with transaction.atomic():
                    # Mark as processing
                    notification.status = 'processing'
                    notification.processing_started_at = timezone.now()
                    notification.save()

                    # Send notification
                    success = self.send_notification(notification)
                    
                    if success:
                        notification.status = 'sent'
                        notification.processed_at = timezone.now()
                        processed_count += 1
                        self.stdout.write(
                            f"✅ Sent notification {notification.id} to {notification.user.username}"
                        )
                    else:
                        self.handle_failed_notification(notification, max_retries)
                    
                    notification.save()

            except Exception as e:
                logger.error(f"Error processing notification {notification.id}: {e}")
                self.handle_failed_notification(notification, max_retries, str(e))
                notification.save()

        if processed_count > 0:
            self.stdout.write(
                self.style.SUCCESS(f"Processed {processed_count} notifications")
            )

        return processed_count

    def send_notification(self, notification):
        """Send a single notification using Firebase"""
        try:
            # Get active FCM tokens for the user
            fcm_tokens = FCMToken.objects.filter(
                user=notification.user,
                is_active=True
            ).values_list('token', flat=True)

            if not fcm_tokens:
                logger.warning(f"No active FCM tokens for user {notification.user.username}")
                return False

            # Create Firebase message
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=notification.title,
                    body=notification.body
                ),
                data=notification.data,
                tokens=list(fcm_tokens)
            )

            # Send message
            response = messaging.send_multicast(message)

            # Log to notification history
            NotificationHistory.objects.create(
                user=notification.user,
                notification_type=notification.notification_type,
                title=notification.title,
                body=notification.body,
                data=notification.data,
                sent=response.success_count > 0,
                sent_at=timezone.now() if response.success_count > 0 else None
            )

            # Update FCM token status for failed tokens
            if response.failure_count > 0:
                self.handle_failed_tokens(response.responses, list(fcm_tokens))

            return response.success_count > 0

        except Exception as e:
            logger.error(f"Firebase send error: {e}")
            return False

    def handle_failed_notification(self, notification, max_retries, error_message=""):
        """Handle failed notification with retry logic"""
        notification.retry_count += 1
        notification.error_message = error_message

        if notification.retry_count >= max_retries:
            notification.status = 'failed'
            self.stdout.write(
                self.style.ERROR(
                    f"❌ Notification {notification.id} failed permanently after {max_retries} retries"
                )
            )
        else:
            notification.status = 'pending'
            # Exponential backoff: retry after 2^retry_count minutes
            retry_delay = 2 ** notification.retry_count
            notification.scheduled_for = timezone.now() + timezone.timedelta(minutes=retry_delay)
            self.stdout.write(
                self.style.WARNING(
                    f"⚠️ Notification {notification.id} failed, retrying in {retry_delay} minutes "
                    f"(attempt {notification.retry_count}/{max_retries})"
                )
            )

    def handle_failed_tokens(self, responses, tokens):
        """Deactivate FCM tokens that failed with invalid token errors"""
        for i, response in enumerate(responses):
            if not response.success and i < len(tokens):
                # Check if the error indicates an invalid token
                if (hasattr(response, 'exception') and 
                    response.exception and 
                    'not-registered' in str(response.exception).lower()):
                    
                    # Deactivate the invalid token
                    FCMToken.objects.filter(token=tokens[i]).update(is_active=False)
                    logger.info(f"Deactivated invalid FCM token: {tokens[i][:20]}...")

    def cleanup_old_notifications(self, days=30):
        """Clean up old processed notifications"""
        cutoff_date = timezone.now() - timezone.timedelta(days=days)
        deleted_count = NotificationQueue.objects.filter(
            status__in=['sent', 'failed'],
            processed_at__lt=cutoff_date
        ).delete()[0]
        
        if deleted_count > 0:
            self.stdout.write(
                self.style.SUCCESS(f"Cleaned up {deleted_count} old notifications")
            )
