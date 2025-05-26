"""
Django management command to automatically mark old events as ended.
This can be run as a daily cron job.
"""

from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from posts.models import Post, PostStatus

class Command(BaseCommand):
    help = 'Mark events as ended if they are older than 24 hours'

    def add_arguments(self, parser):
        parser.add_argument(
            '--hours',
            type=int,
            default=24,
            help='Number of hours after which to mark events as ended (default: 24)'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be updated without making changes'
        )

    def handle(self, *args, **options):
        hours = options['hours']
        dry_run = options['dry_run']
        
        # Calculate cutoff time
        cutoff_time = timezone.now() - timedelta(hours=hours)
        
        # Find events that are still happening but created before cutoff
        old_events = Post.objects.filter(
            status=PostStatus.HAPPENING,
            created_at__lt=cutoff_time
        )
        
        count = old_events.count()
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f'DRY RUN: Would mark {count} events as ended (older than {hours} hours)'
                )
            )
            for event in old_events[:10]:  # Show first 10
                self.stdout.write(f'  - {event.title} (created: {event.created_at})')
            if count > 10:
                self.stdout.write(f'  ... and {count - 10} more')
        else:
            # Update the events
            updated = old_events.update(status=PostStatus.ENDED)
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully marked {updated} events as ended (older than {hours} hours)'
                )
            )
