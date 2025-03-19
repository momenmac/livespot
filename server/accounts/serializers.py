from rest_framework import serializers
from .models import Account
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

class AccountSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    profile_picture_url = serializers.SerializerMethodField()
    tokens = serializers.SerializerMethodField()

    class Meta:
        model = Account
        fields = ['id', 'email', 'first_name', 'last_name', 'password', 'profile_picture_url', 'google_id', 'tokens', 'is_verified']
        extra_kwargs = {'password': {'write_only': True}}
    
    def create(self, validated_data):
        user = Account.objects.create_user(
            email=validated_data['email'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            password=validated_data['password']
        )
        return user

    def get_profile_picture_url(self, obj):
        """Get full URL for profile picture"""
        if obj.profile_picture and obj.profile_picture.url:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.profile_picture.url)
            return obj.profile_picture.url
        return None
        
    def get_tokens(self, obj):
        """Get JWT tokens for the user"""
        return obj.get_tokens() if hasattr(obj, 'get_tokens') else None
