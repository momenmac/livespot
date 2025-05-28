from django.core.management.base import BaseCommand
from media_api.models import MediaFile
from media_api.file_processor import FileProcessor
import os


class Command(BaseCommand):
    help = 'Generate thumbnails for existing video files'

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=None,
            help='Limit the number of videos to process'
        )

    def handle(self, *args, **options):
        limit = options.get('limit')
        
        # Find video files without thumbnails
        video_files = MediaFile.objects.filter(
            content_type='video',
            thumbnail_url__isnull=True
        )
        
        if limit:
            video_files = video_files[:limit]
            
        total_videos = video_files.count()
        self.stdout.write(f'Found {total_videos} video files without thumbnails')
        
        processed = 0
        failed = 0
        
        for video_file in video_files:
            try:
                self.stdout.write(f'Processing video: {video_file.id}')
                
                if FileProcessor.process_video_with_thumbnail(video_file):
                    processed += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'✓ Generated thumbnail for {video_file.id}')
                    )
                else:
                    failed += 1
                    self.stdout.write(
                        self.style.ERROR(f'✗ Failed to generate thumbnail for {video_file.id}')
                    )
                    
            except Exception as e:
                failed += 1
                self.stdout.write(
                    self.style.ERROR(f'✗ Error processing {video_file.id}: {e}')
                )
                
        self.stdout.write(
            self.style.SUCCESS(
                f'\nCompleted! Processed: {processed}, Failed: {failed}'
            )
        )
