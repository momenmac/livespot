from django.core.management.base import BaseCommand
from media_api.models import MediaFile
from media_api.file_processor import FileProcessor
import logging

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Generate thumbnails for all video files'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Regenerate thumbnails even if they already exist',
        )
    
    def handle(self, *args, **options):
        force = options['force']
        
        # Find all video files
        video_files = MediaFile.objects.filter(content_type='video')
        
        self.stdout.write(f"Found {video_files.count()} video files")
        
        generated_count = 0
        skipped_count = 0
        error_count = 0
        
        for video_file in video_files:
            try:
                # Skip if thumbnail already exists and not forcing
                if video_file.thumbnail_url and not force:
                    skipped_count += 1
                    self.stdout.write(f"Skipping {video_file.id} - thumbnail exists")
                    continue
                
                # Generate thumbnail
                if FileProcessor.process_video_with_thumbnail(video_file):
                    generated_count += 1
                    video_file.refresh_from_db()
                    self.stdout.write(
                        self.style.SUCCESS(
                            f"Generated thumbnail for {video_file.id}: {video_file.thumbnail_url}"
                        )
                    )
                else:
                    error_count += 1
                    self.stdout.write(
                        self.style.ERROR(f"Failed to generate thumbnail for {video_file.id}")
                    )
                    
            except Exception as e:
                error_count += 1
                self.stdout.write(
                    self.style.ERROR(f"Error processing {video_file.id}: {e}")
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f"Thumbnail generation complete. "
                f"Generated: {generated_count}, Skipped: {skipped_count}, Errors: {error_count}"
            )
        )
