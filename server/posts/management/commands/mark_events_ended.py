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
        
        # Find events that should be ended based on votes
        vote_based_events = []
        for post in Post.objects.filter(status=PostStatus.HAPPENING):
            if post.should_mark_as_ended():
                vote_based_events.append(post)
        
        vote_count = len(vote_based_events)
        
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
                
            self.stdout.write(
                self.style.WARNING(
                    f'DRY RUN: Would mark {vote_count} events as ended (based on votes)'
                )
            )
            for event in vote_based_events[:10]:  # Show first 10
                self.stdout.write(f'  - {event.title} (ended votes: {event.get_ended_votes_count()}, happening votes: {event.get_happening_votes_count()})')
            if vote_count > 10:
                self.stdout.write(f'  ... and {vote_count - 10} more')
        else:
            # Update time-based events
            updated = old_events.update(status=PostStatus.ENDED, event_status=PostStatus.ENDED)
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully marked {updated} events as ended (older than {hours} hours)'
                )
            )
            
            # Update vote-based events
            vote_updated = 0
            for post in vote_based_events:
                post.status = PostStatus.ENDED
                post.event_status = PostStatus.ENDED
                post.save(update_fields=['status', 'event_status'])
                vote_updated += 1
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully marked {vote_updated} events as ended (based on votes)'
                )
            )
