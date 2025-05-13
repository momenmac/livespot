from rest_framework import serializers
from .models import Account, VerificationCode, UserProfile

class AccountSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = Account
        fields = ['id', 'email', 'password', 'first_name', 'last_name', 'profile_picture',
                 'is_verified', 'is_admin', 'google_id', 'created_at', 'last_login']
        read_only_fields = ['id', 'is_verified', 'is_admin', 'created_at', 'last_login']
        extra_kwargs = {
            'password': {'write_only': True}
        }
    
    def create(self, validated_data):
        # Extract password from validated data
        password = validated_data.pop('password')
        
        # Create the user instance using the model's create_user method
        # which properly handles password hashing
        user = Account.objects.create_user(
            password=password,
            **validated_data
        )
        return user


class AccountAuthorSerializer(serializers.ModelSerializer):
    display_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Account
        fields = ['id', 'email', 'first_name', 'last_name', 'profile_picture', 'display_name', 'is_admin']
    
    def get_display_name(self, obj):
        # Try to get the username from the related UserProfile
        try:
            if hasattr(obj, 'userprofile') and obj.userprofile.username:
                return obj.userprofile.username
            else:
                return f"{obj.first_name} {obj.last_name}".strip() or obj.email.split('@')[0]
        except:
            # Fallback to a combination of first_name and last_name or the email prefix
            return f"{obj.first_name} {obj.last_name}".strip() or obj.email.split('@')[0]


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
