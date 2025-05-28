import os
import logging
import uuid
import mimetypes
from django.conf import settings
from django.http import HttpResponse, JsonResponse
from django.core.exceptions import PermissionDenied
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from firebase_admin import credentials, initialize_app, storage, firestore
from django.views.decorators.csrf import csrf_exempt

from .models import MediaFile
from .serializers import MediaFileSerializer, MediaFileUploadSerializer, MediaFileResponseSerializer
from .file_processor import FileProcessor

logger = logging.getLogger(__name__)

# Try to import magic for better file type detection
try:
    import magic
    HAS_MAGIC = True
except ImportError:
    HAS_MAGIC = False
    logger.warning("python-magic not available, falling back to mimetypes")


def get_proper_file_extension(mime_type, content_type, original_filename=None):
    """
    Get the proper file extension based on MIME type and content type.
    This ensures uploaded files have correct extensions regardless of their original filename.
    """
    # Try to get extension from original filename if it's valid
    if original_filename and '.' in original_filename:
        original_ext = original_filename.split('.')[-1].lower()
        # Validate the extension matches the content type
        if content_type == 'image' and original_ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']:
            return original_ext
        elif content_type == 'video' and original_ext in ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv']:
            return original_ext
        elif content_type == 'audio' and original_ext in ['mp3', 'wav', 'aac', 'ogg', 'flac']:
            return original_ext
    
    # Map MIME types to proper extensions
    mime_to_ext = {
        # Images
        'image/jpeg': 'jpg',
        'image/jpg': 'jpg',
        'image/png': 'png',
        'image/gif': 'gif',
        'image/webp': 'webp',
        'image/bmp': 'bmp',
        'image/tiff': 'tiff',
        # Videos
        'video/mp4': 'mp4',
        'video/quicktime': 'mov',
        'video/x-msvideo': 'avi',
        'video/x-matroska': 'mkv',
        'video/webm': 'webm',
        'video/3gpp': '3gp',
        'video/x-flv': 'flv',
        # Audio
        'audio/mpeg': 'mp3',
        'audio/wav': 'wav',
        'audio/aac': 'aac',
        'audio/ogg': 'ogg',
        'audio/flac': 'flac',
    }
    
    # Return extension based on MIME type
    if mime_type and mime_type in mime_to_ext:
        return mime_to_ext[mime_type]
    
    # Fallback to default extensions based on content type
    if content_type == 'image':
        return 'jpg'
    elif content_type == 'video':
        return 'mp4'
    elif content_type == 'audio':
        return 'mp3'
    else:
        return 'bin'  # Binary file fallback


def detect_content_type_from_file(file_path, original_content_type=None):
    """
    Detect the actual content type of a file using python-magic if available.
    This helps ensure we're handling the file with the correct type.
    """
    try:
        if HAS_MAGIC:
            # Use python-magic to detect the actual MIME type
            mime_type = magic.from_file(file_path, mime=True)
            
            if mime_type.startswith('image/'):
                return 'image', mime_type
            elif mime_type.startswith('video/'):
                return 'video', mime_type
            elif mime_type.startswith('audio/'):
                return 'audio', mime_type
            else:
                # Fallback to original content type if detection fails
                return original_content_type or 'image', mime_type
        else:
            # Fallback to mimetypes module
            mime_type, _ = mimetypes.guess_type(file_path)
            if mime_type:
                if mime_type.startswith('image/'):
                    return 'image', mime_type
                elif mime_type.startswith('video/'):
                    return 'video', mime_type
                elif mime_type.startswith('audio/'):
                    return 'audio', mime_type
            
            return original_content_type or 'image', mime_type or 'application/octet-stream'
    except Exception as e:
        logger.warning(f"Failed to detect file type: {e}")
        # Final fallback
        return original_content_type or 'image', 'application/octet-stream'

# Initialize Firebase once
def get_firebase_storage():
    """Initialize Firebase and return storage bucket"""
    try:
        # Check if Firebase app is already initialized
        if not hasattr(get_firebase_storage, "_initialized"):
            cred_path = getattr(
                settings, 
                'FIREBASE_CRED_PATH', 
                '/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json'
            )
            if not firestore.client._apps:
                cred = credentials.Certificate(cred_path)
                initialize_app(cred, {
                    'storageBucket': 'livespot-b1eb4.appspot.com'
                })
            get_firebase_storage._initialized = True
            
        # Get storage bucket
        bucket = storage.bucket()
        return bucket
    except Exception as e:
        logger.error(f"Firebase storage initialization error: {e}")
        return None


class MediaFileViewSet(viewsets.ModelViewSet):
    """ViewSet for the MediaFile model"""
    serializer_class = MediaFileSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    
    def get_queryset(self):
        """Only return media files owned by the authenticated user"""
        return MediaFile.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        """Create a new media file and upload to Firebase Storage"""
        # Save to Django first
        media_file = serializer.save(user=self.request.user)
        
        try:
            # Upload to Firebase Storage
            bucket = get_firebase_storage()
            if bucket:
                # Get file path
                file_path = media_file.file.path
                
                # Determine content type for blob and get proper file extension
                detected_content_type, detected_mime_type = detect_content_type_from_file(file_path, media_file.content_type)
                
                # Use detected MIME type or fallback
                content_type = detected_mime_type or mimetypes.guess_type(file_path)[0]
                if not content_type:
                    if detected_content_type == 'image':
                        content_type = 'image/jpeg'
                    elif detected_content_type == 'video':
                        content_type = 'video/mp4'
                    elif detected_content_type == 'audio':
                        content_type = 'audio/mpeg'
                    else:
                        content_type = 'application/octet-stream'
                
                # Get proper file extension based on MIME type and content type
                proper_extension = get_proper_file_extension(content_type, detected_content_type, media_file.original_filename)
                
                # Create a unique Firebase path with proper extension
                firebase_path = f"attachments/{detected_content_type}/{media_file.id}.{proper_extension}"
                
                # Upload file to Firebase
                blob = bucket.blob(firebase_path)
                blob.upload_from_filename(
                    file_path,
                    content_type=content_type
                )
                
                # Make the blob publicly accessible
                blob.make_public()
                
                # Update MediaFile with Firebase URL
                firebase_url = blob.public_url
                media_file.firebase_url = firebase_url
                media_file.save()
                
                logger.info(f"File uploaded to Firebase: {firebase_url}")
            else:
                logger.warning("Firebase bucket not initialized, using local storage only")
        except Exception as e:
            logger.error(f"Firebase upload error: {e}")
            # Even if Firebase upload fails, we still have the file in Django storage
        
        return media_file


@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_media(request):
    """Upload a media file and return the URL"""
    try:
        if 'file' not in request.FILES:
            return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)
            
        file_obj = request.FILES['file']
        content_type = request.data.get('content_type', 'image')
        
        # Create a new MediaFile instance
        media_file = MediaFile(
            user=request.user,
            file=file_obj,
            content_type=content_type,
            original_filename=file_obj.name,
            file_size=file_obj.size
        )
        media_file.save()
        
        # Upload to Firebase Storage
        firebase_url = None
        try:
            bucket = get_firebase_storage()
            if bucket:
                # Get file path
                file_path = media_file.file.path
                
                # Determine content type for blob and get proper file extension
                detected_content_type, detected_mime_type = detect_content_type_from_file(file_path, content_type)
                
                # Use detected MIME type or fallback
                mime_type = detected_mime_type or mimetypes.guess_type(file_path)[0]
                if not mime_type:
                    if detected_content_type == 'image':
                        mime_type = 'image/jpeg'
                    elif detected_content_type == 'video':
                        mime_type = 'video/mp4'
                    elif detected_content_type == 'audio':
                        mime_type = 'audio/mpeg'
                    else:
                        mime_type = 'application/octet-stream'
                
                # Get proper file extension based on MIME type and content type
                proper_extension = get_proper_file_extension(mime_type, detected_content_type, file_obj.name)
                
                # Create a unique Firebase path with proper extension
                firebase_path = f"attachments/{detected_content_type}/{media_file.id}.{proper_extension}"
                
                # Upload file to Firebase
                blob = bucket.blob(firebase_path)
                blob.upload_from_filename(
                    file_path, 
                    content_type=mime_type
                )
                
                # Make the blob publicly accessible
                blob.make_public()
                
                # Update MediaFile with Firebase URL
                firebase_url = blob.public_url
                media_file.firebase_url = firebase_url
                media_file.save()
                
                logger.info(f"File uploaded to Firebase: {firebase_url}")
        except Exception as e:
            logger.error(f"Firebase upload error: {e}")
            # Continue even if Firebase upload fails
        
        # Return the media file data with Firebase URL if available
        serializer = MediaFileResponseSerializer(media_file)
        response_data = serializer.data
        
        # IMPORTANT: Always use Firebase URL in response if available
        # This prevents "localhost" URLs from being sent to clients
        if firebase_url:
            response_data['url'] = firebase_url
            response_data['firebase_url'] = firebase_url
        
        # Post-process the file to fix extensions and paths if needed
        try:
            # Check if file has wrong extension or is a .temp file
            if media_file.file and media_file.file.path:
                file_path = media_file.file.path
                file_name = os.path.basename(file_path)
                
                # Detect actual file type and fix if needed
                detected_content_type, detected_mime_type = detect_content_type_from_file(file_path, content_type)
                
                # If detected type is different from stored type, or file has .temp extension
                should_fix = (
                    file_name.endswith('.temp') or
                    detected_content_type != media_file.content_type or
                    (detected_content_type == 'video' and media_file.content_type == 'image')
                )
                
                if should_fix:
                    logger.info(f"Post-processing file {file_name}: detected as {detected_content_type}/{detected_mime_type}")
                    
                    if file_name.endswith('.temp'):
                        # Process .temp files
                        if FileProcessor.process_temp_file(media_file):
                            # Refresh the response data with updated URLs
                            media_file.refresh_from_db()
                            serializer = MediaFileResponseSerializer(media_file)
                            response_data = serializer.data
                            logger.info(f"Successfully processed .temp file: {response_data.get('firebase_url', response_data.get('url'))}")
                            
                            # Generate thumbnail for videos
                            if media_file.content_type == 'video':
                                FileProcessor.process_video_with_thumbnail(media_file)
                    else:
                        # Fix extension for files with wrong extensions
                        if FileProcessor.fix_file_extension_and_path(media_file, detected_mime_type):
                            # Refresh the response data with updated URLs
                            media_file.refresh_from_db()
                            serializer = MediaFileResponseSerializer(media_file)
                            response_data = serializer.data
                            logger.info(f"Successfully fixed file extension: {response_data.get('firebase_url', response_data.get('url'))}")
                            
        except Exception as e:
            logger.warning(f"File post-processing failed (continuing anyway): {e}")
        
        return Response(response_data, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"Media upload error: {e}")
        return Response(
            {'error': f'File upload failed: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def direct_upload(request):
    """Upload a media file via JSON data (base64-encoded)"""
    try:
        data = request.data
        file_data = data.get('file_data')
        file_name = data.get('file_name', 'uploaded_file.jpg')
        content_type = data.get('content_type', 'image')
        
        if not file_data:
            return Response({'error': 'No file data provided'}, status=status.HTTP_400_BAD_REQUEST)
            
        import base64
        from django.core.files.base import ContentFile
        
        # Decode base64 data
        try:
            if ',' in file_data:  # Handle data URIs
                file_data = file_data.split(',', 1)[1]
                
            binary_data = base64.b64decode(file_data)
        except Exception as e:
            logger.error(f"Base64 decode error: {e}")
            return Response({'error': 'Invalid file data format'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Create a file from binary data
        file_content = ContentFile(binary_data, name=file_name)
        
        # Create a new MediaFile instance
        media_file = MediaFile(
            user=request.user,
            file=file_content,
            content_type=content_type,
            original_filename=file_name,
            file_size=len(binary_data)
        )
        media_file.save()
        
        # Upload to Firebase Storage
        try:
            bucket = get_firebase_storage()
            if bucket:
                # Get file path
                file_path = media_file.file.path
                
                # Determine content type for blob and get proper file extension
                detected_content_type, detected_mime_type = detect_content_type_from_file(file_path, content_type)
                
                # Use detected MIME type or fallback
                import mimetypes
                mime_type = detected_mime_type or mimetypes.guess_type(file_path)[0]
                if not mime_type:
                    if detected_content_type == 'image':
                        mime_type = 'image/jpeg'
                    elif detected_content_type == 'video':
                        mime_type = 'video/mp4'
                    elif detected_content_type == 'audio':
                        mime_type = 'audio/mpeg'
                    else:
                        mime_type = 'application/octet-stream'
                
                # Get proper file extension based on MIME type and content type
                proper_extension = get_proper_file_extension(mime_type, detected_content_type, file_name)
                
                # Create a unique Firebase path with proper extension
                firebase_path = f"attachments/{detected_content_type}/{media_file.id}.{proper_extension}"
                
                # Upload file to Firebase
                blob = bucket.blob(firebase_path)
                blob.upload_from_filename(
                    file_path, 
                    content_type=mime_type
                )
                
                # Make the blob publicly accessible
                blob.make_public()
                
                # Update MediaFile with Firebase URL
                firebase_url = blob.public_url
                media_file.firebase_url = firebase_url
                media_file.save()
                
                logger.info(f"File uploaded to Firebase: {firebase_url}")
        except Exception as e:
            logger.error(f"Firebase upload error: {e}")
            # Continue even if Firebase upload fails
            
        # Return the media file data
        serializer = MediaFileResponseSerializer(media_file)
        response_data = serializer.data
        
        # Post-process the file to fix extensions and paths if needed
        try:
            # Check if file has wrong extension or is a .temp file
            if media_file.file and media_file.file.path:
                file_path = media_file.file.path
                file_name = os.path.basename(file_path) if hasattr(file_path, 'split') else file_name
                
                # Detect actual file type and fix if needed
                detected_content_type, detected_mime_type = detect_content_type_from_file(file_path, content_type)
                
                # If detected type is different from stored type, or file has .temp extension
                should_fix = (
                    file_name.endswith('.temp') or
                    detected_content_type != media_file.content_type or
                    (detected_content_type == 'video' and media_file.content_type == 'image')
                )
                
                if should_fix:
                    logger.info(f"Post-processing direct upload {file_name}: detected as {detected_content_type}/{detected_mime_type}")
                    
                    if file_name.endswith('.temp'):
                        # Process .temp files
                        if FileProcessor.process_temp_file(media_file):
                            # Refresh the response data with updated URLs
                            media_file.refresh_from_db()
                            serializer = MediaFileResponseSerializer(media_file)
                            response_data = serializer.data
                            logger.info(f"Successfully processed .temp file: {response_data.get('firebase_url', response_data.get('url'))}")
                            
                            # Generate thumbnail for videos
                            if media_file.content_type == 'video':
                                FileProcessor.process_video_with_thumbnail(media_file)
                    else:
                        # Fix extension for files with wrong extensions
                        if FileProcessor.fix_file_extension_and_path(media_file, detected_mime_type):
                            # Refresh the response data with updated URLs
                            media_file.refresh_from_db()
                            serializer = MediaFileResponseSerializer(media_file)
                            response_data = serializer.data
                            
                            # Generate thumbnail for videos
                            if media_file.content_type == 'video':
                                FileProcessor.process_video_with_thumbnail(media_file)
                            logger.info(f"Successfully fixed file extension: {response_data.get('firebase_url', response_data.get('url'))}")
                            
        except Exception as e:
            logger.warning(f"Direct upload post-processing failed (continuing anyway): {e}")
            
        return Response(response_data, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"Direct upload error: {e}")
        return Response(
            {'error': f'File upload failed: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_media(request, file_id):
    """Get details of a specific media file"""
    try:
        media_file = MediaFile.objects.get(id=file_id)
        
        # Check if user can access this file
        if media_file.user != request.user and not request.user.is_staff:
            raise PermissionDenied("You don't have permission to access this file")
            
        serializer = MediaFileSerializer(media_file)
        return Response(serializer.data)
    except MediaFile.DoesNotExist:
        return Response(
            {'error': 'File not found'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except PermissionDenied as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_403_FORBIDDEN
        )
    except Exception as e:
        logger.error(f"Error retrieving media file: {e}")
        return Response(
            {'error': f'Could not retrieve file: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_media(request, file_id):
    """Delete a media file"""
    try:
        media_file = MediaFile.objects.get(id=file_id)
        
        # Check if user can delete this file
        if media_file.user != request.user and not request.user.is_staff:
            raise PermissionDenied("You don't have permission to delete this file")
            
        # Delete from Firebase if URL exists
        if media_file.firebase_url:
            try:
                bucket = get_firebase_storage()
                if bucket:
                    # Extract blob name from URL
                    url_parts = media_file.firebase_url.split('/')
                    blob_name = '/'.join(url_parts[3:])  # Skip https://storage.googleapis.com/
                    
                    # Delete the blob
                    blob = bucket.blob(blob_name)
                    blob.delete()
                    logger.info(f"Deleted file from Firebase: {blob_name}")
            except Exception as e:
                logger.error(f"Error deleting file from Firebase: {e}")
                
        # Delete file from disk and database
        media_file.file.delete()
        media_file.delete()
        
        return Response(
            {'success': 'File deleted successfully'},
            status=status.HTTP_200_OK
        )
    except MediaFile.DoesNotExist:
        return Response(
            {'error': 'File not found'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except PermissionDenied as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_403_FORBIDDEN
        )
    except Exception as e:
        logger.error(f"Error deleting media file: {e}")
        return Response(
            {'error': f'Could not delete file: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_user_media(request):
    """List all media files for the authenticated user"""
    try:
        content_type = request.query_params.get('content_type', None)
        
        # Filter by content_type if provided
        if content_type:
            media_files = MediaFile.objects.filter(
                user=request.user,
                content_type=content_type
            ).order_by('-uploaded_at')
        else:
            media_files = MediaFile.objects.filter(
                user=request.user
            ).order_by('-uploaded_at')
            
        serializer = MediaFileResponseSerializer(media_files, many=True)
        return Response(serializer.data)
    except Exception as e:
        logger.error(f"Error listing media files: {e}")
        return Response(
            {'error': f'Could not retrieve media files: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
