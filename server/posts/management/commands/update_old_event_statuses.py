from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from posts.models import Post, PostStatus


class Command(BaseCommand):
    help = 'One-time migration: Update all old posts from PUBLISHED to ENDED status'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Perform a dry run without making actual changes',
        )
        parser.add_argument(
            '--hours',
            type=int,
            default=24,
            help='Number of hours threshold (default: 24)',
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        hours = options.get('hours', 24)
        
        # Get threshold time (posts older than this will be marked as ended)
        time_threshold = timezone.now() - timedelta(hours=hours)
        
        # Find all posts that are still marked as published but are older than the threshold
        old_published_posts = Post.objects.filter(
            status='PUBLISHED',  # Using string value directly for legacy status
            created_at__lt=time_threshold
        )
        
        # Count posts that will be updated
        count = old_published_posts.count()
        
        self.stdout.write(f"Found {count} posts older than {hours} hours still marked as PUBLISHED")
        
        if dry_run:
            self.stdout.write(self.style.SUCCESS(
                f"DRY RUN: Would update {count} posts from PUBLISHED to ENDED"
            ))
        else:
            # Batch update all old posts to ended status
            updated_count = old_published_posts.update(status=PostStatus.ENDED)
            
            self.stdout.write(self.style.SUCCESS(
                f"Successfully updated {updated_count} posts from PUBLISHED to ENDED"
            ))
