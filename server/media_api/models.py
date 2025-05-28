import uuid
import os
from django.db import models
from django.conf import settings
from accounts.models import Account


def attachment_upload_path(instance, filename):
    """Generate a unique path for each uploaded file"""
    # Get the file extension
    ext = filename.split('.')[-1] if '.' in filename else ''
    # Generate unique filename with UUID
    unique_filename = f"{uuid.uuid4()}.{ext}"
    # Return the upload path
    return os.path.join('attachments', instance.content_type, unique_filename)


class MediaFile(models.Model):
    """Model for storing media attachments"""
    CONTENT_TYPE_CHOICES = (
        ('image', 'Image'),
        ('video', 'Video'),
        ('audio', 'Audio'),
        ('document', 'Document'),
        ('other', 'Other'),
    )
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        Account, 
        related_name='media_files', 
        on_delete=models.CASCADE
    )
    file = models.FileField(upload_to=attachment_upload_path)
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES, default='image')
    original_filename = models.CharField(max_length=255, blank=True)
    file_size = models.IntegerField(default=0)  # Size in bytes
    firebase_url = models.URLField(max_length=500, blank=True, null=True)
    thumbnail_url = models.URLField(max_length=500, blank=True, null=True)  # For video thumbnails
    uploaded_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.content_type} by {self.user.email} - {self.id}"
    
    def save(self, *args, **kwargs):
        # Auto-set file size if not provided
        if self.file and not self.file_size:
            self.file_size = self.file.size
            
        # Auto-set original filename if not provided
        if self.file and not self.original_filename:
            self.original_filename = os.path.basename(self.file.name)
            
        super().save(*args, **kwargs)
    
    @property
    def full_url(self):
        """Get the full URL for the file"""
        if self.firebase_url:
            return self.firebase_url
        if self.file:
            return f"{settings.BASE_URL}{self.file.url}"
        return None
