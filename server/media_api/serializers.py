from rest_framework import serializers
from .models import MediaFile


class MediaFileSerializer(serializers.ModelSerializer):
    """Serializer for the MediaFile model"""
    full_url = serializers.ReadOnlyField()
    
    class Meta:
        model = MediaFile
        fields = [
            'id', 'file', 'content_type', 'original_filename', 
            'file_size', 'firebase_url', 'thumbnail_url', 'uploaded_at', 'full_url'
        ]
        read_only_fields = ['id', 'file_size', 'uploaded_at', 'full_url', 'thumbnail_url']
        

class MediaFileUploadSerializer(serializers.ModelSerializer):
    """Serializer for uploading media files"""
    class Meta:
        model = MediaFile
        fields = ['file', 'content_type']
        

class MediaFileResponseSerializer(serializers.ModelSerializer):
    """Serializer for media file responses with minimal fields"""
    url = serializers.SerializerMethodField()
    thumbnail_url = serializers.CharField(read_only=True, allow_null=True)
    
    class Meta:
        model = MediaFile
        fields = ['id', 'url', 'content_type', 'file_size', 'thumbnail_url']
    
    def get_url(self, obj):
        """Return the best available URL for the media file"""
        return obj.full_url