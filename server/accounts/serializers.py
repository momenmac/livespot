from rest_framework import serializers
from .models import Account

class AccountSerializer(serializers.ModelSerializer):
    profile_picture_url = serializers.SerializerMethodField()

    class Meta:
        model = Account
        fields = ('id', 'email', 'first_name', 'last_name', 
                  'profile_picture_url', 'google_id')
        
    def get_profile_picture_url(self, obj):
        """Get full URL for profile picture"""
        if obj.profile_picture and obj.profile_picture.url:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.profile_picture.url)
            return obj.profile_picture.url
        return None
