import os
import shutil
import logging
from django.conf import settings
from firebase_admin import storage
from .models import MediaFile
import subprocess
import tempfile
from PIL import Image

logger = logging.getLogger(__name__)

class FileProcessor:
    """
    Simple file processor that fixes file extensions and moves files to correct directories.
    No actual video conversion - just renaming and organizing files.
    """
    
    @staticmethod
    def process_temp_file(media_file):
        """
        Process a .temp file - detect if it's a video and fix extension/location
        """
        try:
            if not media_file.file or not media_file.file.path:
                logger.warning(f"MediaFile {media_file.id} has no file path")
                return False
                
            file_path = media_file.file.path
            file_name = os.path.basename(file_path)
            
            # Check if file has .temp extension
            if not file_name.endswith('.temp'):
                logger.info(f"File {file_name} is not a .temp file, skipping")
                return False
                
            # Try to detect if it's actually a video using python-magic
            try:
                import magic
                mime_type = magic.from_file(file_path, mime=True)
                is_video = mime_type.startswith('video/')
            except ImportError:
                # Fallback: assume .temp files are videos if they're large enough
                file_size = os.path.getsize(file_path)
                is_video = file_size > 1024 * 1024  # Assume files > 1MB are videos
                logger.warning("python-magic not available, using file size heuristic")
            except Exception as e:
                logger.error(f"Error detecting file type: {e}")
                return False
                
            if not is_video:
                logger.info(f"File {file_name} is not a video, skipping")
                return False
                
            # Generate new filename with .mp4 extension
            base_name = file_name.replace('.temp', '')
            new_filename = f"{base_name}.mp4"
            
            # Create new file path in video directory
            media_root = settings.MEDIA_ROOT
            new_dir = os.path.join(media_root, 'attachments', 'video')
            os.makedirs(new_dir, exist_ok=True)
            new_file_path = os.path.join(new_dir, new_filename)
            
            # Move the file
            shutil.move(file_path, new_file_path)
            logger.info(f"Moved {file_path} to {new_file_path}")
            
            # Update the MediaFile record
            media_file.content_type = 'video'
            
            # Update the file field path
            relative_path = os.path.relpath(new_file_path, media_root)
            media_file.file.name = relative_path
            
            # Update Firebase if needed
            FileProcessor._update_firebase_path(media_file, new_file_path)
            
            media_file.save()
            
            logger.info(f"Successfully processed temp file {file_name} -> {new_filename}")
            return True
            
        except Exception as e:
            logger.error(f"Error processing temp file {media_file.id}: {e}")
            return False
    
    @staticmethod
    def _update_firebase_path(media_file, new_file_path):
        """Update Firebase storage path for the renamed file"""
        try:
            # Get Firebase bucket
            bucket = storage.bucket()
            if not bucket:
                logger.warning("Firebase bucket not available")
                return
                
            # Delete old Firebase file if it exists
            if media_file.firebase_url:
                try:
                    # Extract old blob path from URL
                    old_url_parts = media_file.firebase_url.split('/')
                    if len(old_url_parts) > 3:
                        old_blob_path = '/'.join(old_url_parts[4:])  # Skip domain part
                        old_blob = bucket.blob(old_blob_path)
                        old_blob.delete()
                        logger.info(f"Deleted old Firebase file: {old_blob_path}")
                except Exception as e:
                    logger.warning(f"Could not delete old Firebase file: {e}")
            
            # Upload new file to Firebase with correct path
            new_firebase_path = f"attachments/video/{media_file.id}.mp4"
            blob = bucket.blob(new_firebase_path)
            blob.upload_from_filename(
                new_file_path,
                content_type='video/mp4'
            )
            blob.make_public()
            
            # Update MediaFile with new Firebase URL
            media_file.firebase_url = blob.public_url
            logger.info(f"Updated Firebase URL: {blob.public_url}")
            
        except Exception as e:
            logger.error(f"Error updating Firebase path: {e}")
    
    @staticmethod
    def process_wrong_extension_files():
        """
        Batch process all files with wrong extensions (.temp, .jpg videos, etc.)
        """
        try:
            # Find all MediaFiles with .temp extension or suspicious patterns
            media_files = MediaFile.objects.filter(
                file__isnull=False
            )
            
            processed_count = 0
            for media_file in media_files:
                try:
                    if media_file.file and media_file.file.path:
                        file_path = media_file.file.path
                        file_name = os.path.basename(file_path)
                        
                        # Check for .temp files or images that might be videos
                        should_process = (
                            file_name.endswith('.temp') or
                            (file_name.endswith('.jpg') and media_file.content_type == 'image' and 
                             os.path.getsize(file_path) > 5 * 1024 * 1024)  # Large "images" might be videos
                        )
                        
                        if should_process:
                            if FileProcessor.process_temp_file(media_file):
                                processed_count += 1
                                
                except Exception as e:
                    logger.error(f"Error processing MediaFile {media_file.id}: {e}")
                    continue
                    
            logger.info(f"Batch processing complete. Processed {processed_count} files.")
            return processed_count
            
        except Exception as e:
            logger.error(f"Error in batch processing: {e}")
            return 0
    
    @staticmethod
    def fix_file_extension_and_path(media_file, detected_mime_type):
        """
        Fix file extension based on detected MIME type and move to correct directory
        """
        try:
            if not media_file.file or not media_file.file.path:
                return False
                
            file_path = media_file.file.path
            current_filename = os.path.basename(file_path)
            
            # Determine correct extension and content type
            if detected_mime_type.startswith('video/'):
                new_extension = 'mp4'
                new_content_type = 'video'
                new_dir_name = 'video'
            elif detected_mime_type.startswith('image/'):
                if 'jpeg' in detected_mime_type or 'jpg' in detected_mime_type:
                    new_extension = 'jpg'
                elif 'png' in detected_mime_type:
                    new_extension = 'png'
                else:
                    new_extension = 'jpg'  # Default
                new_content_type = 'image'
                new_dir_name = 'image'
            else:
                logger.info(f"Unknown MIME type {detected_mime_type}, skipping")
                return False
                
            # Generate new filename
            base_name = current_filename.split('.')[0]  # Remove current extension
            new_filename = f"{base_name}.{new_extension}"
            
            # Create new directory path
            media_root = settings.MEDIA_ROOT
            new_dir = os.path.join(media_root, 'attachments', new_dir_name)
            os.makedirs(new_dir, exist_ok=True)
            new_file_path = os.path.join(new_dir, new_filename)
            
            # Move the file
            shutil.move(file_path, new_file_path)
            
            # Update MediaFile record
            media_file.content_type = new_content_type
            relative_path = os.path.relpath(new_file_path, media_root)
            media_file.file.name = relative_path
            
            # Update Firebase
            FileProcessor._update_firebase_with_new_type(media_file, new_file_path, new_content_type, new_extension)
            
            media_file.save()
            
            logger.info(f"Fixed file extension: {current_filename} -> {new_filename}")
            return True
            
        except Exception as e:
            logger.error(f"Error fixing file extension for {media_file.id}: {e}")
            return False
    
    @staticmethod
    def _update_firebase_with_new_type(media_file, new_file_path, content_type, extension):
        """Update Firebase with corrected file type"""
        try:
            bucket = storage.bucket()
            if not bucket:
                return
                
            # Delete old Firebase file
            if media_file.firebase_url:
                try:
                    old_url_parts = media_file.firebase_url.split('/')
                    if len(old_url_parts) > 3:
                        old_blob_path = '/'.join(old_url_parts[4:])
                        old_blob = bucket.blob(old_blob_path)
                        old_blob.delete()
                except Exception as e:
                    logger.warning(f"Could not delete old Firebase file: {e}")
            
            # Upload with correct path and MIME type
            new_firebase_path = f"attachments/{content_type}/{media_file.id}.{extension}"
            blob = bucket.blob(new_firebase_path)
            
            # Set correct content type
            if content_type == 'video':
                mime_type = 'video/mp4'
            elif extension == 'jpg' or extension == 'jpeg':
                mime_type = 'image/jpeg'
            elif extension == 'png':
                mime_type = 'image/png'
            else:
                mime_type = 'application/octet-stream'
                
            blob.upload_from_filename(new_file_path, content_type=mime_type)
            blob.make_public()
            
            media_file.firebase_url = blob.public_url
            
        except Exception as e:
            logger.error(f"Error updating Firebase with new type: {e}")
    
    @staticmethod
    def generate_video_thumbnail(video_path, output_path, time_offset="00:00:01"):
        """
        Generate a video thumbnail using ffmpeg
        """
        try:
            # Use ffmpeg to extract a frame from the video
            cmd = [
                'ffmpeg',
                '-i', video_path,
                '-ss', time_offset,  # Seek to specific time
                '-vframes', '1',     # Extract only 1 frame
                '-q:v', '2',         # High quality
                '-y',                # Overwrite output file
                output_path
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                logger.info(f"Successfully generated thumbnail: {output_path}")
                return True
            else:
                logger.error(f"ffmpeg error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logger.error(f"Timeout generating thumbnail for {video_path}")
            return False
        except Exception as e:
            logger.error(f"Error generating thumbnail: {e}")
            return False

    @staticmethod
    def process_video_with_thumbnail(media_file):
        """
        Process a video file and generate its thumbnail
        """
        try:
            if not media_file.file or not media_file.file.path:
                return False
                
            video_path = media_file.file.path
            
            # Check if it's actually a video
            if not FileProcessor._is_video_file(video_path):
                return False
                
            # Generate thumbnail
            thumbnail_filename = f"{media_file.id}_thumb.jpg"
            thumbnail_dir = os.path.join(settings.MEDIA_ROOT, 'attachments', 'thumbnails')
            os.makedirs(thumbnail_dir, exist_ok=True)
            thumbnail_path = os.path.join(thumbnail_dir, thumbnail_filename)
            
            if FileProcessor.generate_video_thumbnail(video_path, thumbnail_path):
                # Upload thumbnail to Firebase
                FileProcessor._upload_thumbnail_to_firebase(media_file, thumbnail_path)
                return True
                
            return False
            
        except Exception as e:
            logger.error(f"Error processing video with thumbnail: {e}")
            return False
    
    @staticmethod
    def _is_video_file(file_path):
        """Check if file is a video using file extension and optionally magic"""
        try:
            # First check by extension
            video_extensions = ['.mp4', '.avi', '.mov', '.mkv', '.webm', '.m4v', '.3gp']
            file_ext = os.path.splitext(file_path)[1].lower()
            
            if file_ext in video_extensions:
                return True
                
            # Try to use python-magic if available
            try:
                import magic
                mime_type = magic.from_file(file_path, mime=True)
                return mime_type.startswith('video/')
            except ImportError:
                # Fallback: check file size (videos are usually larger)
                file_size = os.path.getsize(file_path)
                return file_size > 1024 * 1024  # > 1MB
                
        except Exception as e:
            logger.error(f"Error checking if file is video: {e}")
            return False
    
    @staticmethod
    def _upload_thumbnail_to_firebase(media_file, thumbnail_path):
        """Upload video thumbnail to Firebase"""
        try:
            # Initialize Firebase if not already done
            try:
                from firebase_admin import credentials, initialize_app
                import firebase_admin
                
                # Check if Firebase is already initialized
                try:
                    firebase_admin.get_app()
                except ValueError:
                    # Firebase not initialized, initialize it
                    cred = credentials.Certificate('/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json')
                    initialize_app(cred, {
                        'storageBucket': 'livespot-b1eb4.appspot.com'
                    })
            except Exception as init_error:
                logger.error(f"Firebase initialization error: {init_error}")
                return
                
            bucket = storage.bucket()
            if not bucket:
                return
                
            # Upload thumbnail
            thumbnail_firebase_path = f"attachments/thumbnails/{media_file.id}_thumb.jpg"
            thumbnail_blob = bucket.blob(thumbnail_firebase_path)
            thumbnail_blob.upload_from_filename(
                thumbnail_path,
                content_type='image/jpeg'
            )
            thumbnail_blob.make_public()
            
            # Update MediaFile with thumbnail URL
            media_file.thumbnail_url = thumbnail_blob.public_url
            media_file.save()
            
            logger.info(f"Uploaded thumbnail to Firebase: {thumbnail_blob.public_url}")
            
        except Exception as e:
            logger.error(f"Error uploading thumbnail to Firebase: {e}")
