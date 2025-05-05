from rest_framework import serializers
from .models import Account, VerificationCode, UserProfile

class AccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = ['id', 'email', 'first_name', 'last_name', 'profile_picture',
                 'is_verified', 'google_id', 'created_at', 'last_login']
        read_only_fields = ['id', 'is_verified', 'created_at', 'last_login']


class UserProfileSerializer(serializers.ModelSerializer):
    account = AccountSerializer(source='user', read_only=True)
    join_date = serializers.DateTimeField(source='user.created_at', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = [
            'account', 'username', 'bio', 'location', 'website',
            'honesty_score', 'followers_count', 'following_count',
            'posts_count', 'saved_posts_count', 'upvoted_posts_count',
            'comments_count', 'join_date', 'activity_status',
            'is_verified', 'interests', 'cover_photo'
        ]
        read_only_fields = ['account', 'followers_count', 'following_count',
                           'posts_count', 'saved_posts_count', 'upvoted_posts_count',
                           'comments_count', 'join_date', 'honesty_score', 'is_verified']


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['username', 'bio', 'location', 'website', 'interests']
        

class UserSearchResultSerializer(serializers.ModelSerializer):
    account = AccountSerializer(source='user', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = ['account', 'username', 'bio', 'is_verified', 'followers_count', 'following_count']
