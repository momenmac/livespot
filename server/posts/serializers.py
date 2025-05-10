from rest_framework import serializers
from accounts.serializers import AccountAuthorSerializer
from .models import PostCoordinates, Post, Thread, PostVote, PostThread

class PostCoordinatesSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostCoordinates
        fields = ['id', 'latitude', 'longitude', 'address']

class ThreadSerializer(serializers.ModelSerializer):
    location = PostCoordinatesSerializer()
    
    class Meta:
        model = Thread
        fields = [
            'id', 'title', 'category', 'location', 'created_at', 
            'updated_at', 'tags', 'honesty_score'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
        
    def create(self, validated_data):
        location_data = validated_data.pop('location')
        location = PostCoordinates.objects.create(**location_data)
        thread = Thread.objects.create(location=location, **validated_data)
        return thread

class PostSerializer(serializers.ModelSerializer):
    location = PostCoordinatesSerializer()
    author = AccountAuthorSerializer(read_only=True)
    user_vote = serializers.IntegerField(read_only=True)
    
    class Meta:
        model = Post
        fields = [
            'id', 'title', 'content', 'media_urls', 'category',
            'location', 'author', 'created_at', 'updated_at',
            'upvotes', 'downvotes', 'honesty_score', 'status',
            'thread', 'is_verified_location', 'taken_within_app',
            'tags', 'user_vote', 'is_anonymous'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'upvotes', 'downvotes', 'honesty_score', 'user_vote']
        
    def create(self, validated_data):
        # Extract location data and create PostCoordinates object
        location_data = validated_data.pop('location')
        location = PostCoordinates.objects.create(**location_data)
        
        # Get the thread ID if provided
        thread_id = validated_data.pop('thread', None)
        thread = None
        
        if thread_id:
            try:
                thread = Thread.objects.get(id=thread_id)
            except Thread.DoesNotExist:
                pass
        
        # Create the post with the author from the request context
        author = self.context['request'].user
        post = Post.objects.create(
            author=author,
            location=location,
            thread=thread,
            **validated_data
        )
        return post
    
    def to_representation(self, instance):
        # Call the parent class's to_representation to get the default representation
        representation = super().to_representation(instance)
        
        # If there's a request context, set the user_vote field
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            user = request.user
            try:
                vote = PostVote.objects.get(user=user, post=instance)
                representation['user_vote'] = 1 if vote.is_upvote else -1
                # Also set on the instance for internal use
                setattr(instance, '_user_vote', 1 if vote.is_upvote else -1)
            except PostVote.DoesNotExist:
                representation['user_vote'] = 0
                setattr(instance, '_user_vote', 0)
        else:
            representation['user_vote'] = 0
            setattr(instance, '_user_vote', 0)
            
        return representation
    
class ThreadDetailSerializer(ThreadSerializer):
    posts = PostSerializer(many=True, read_only=True)
    
    class Meta(ThreadSerializer.Meta):
        fields = ThreadSerializer.Meta.fields + ['posts']

class PostVoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostVote
        fields = ['id', 'post', 'is_upvote', 'created_at']
        read_only_fields = ['id', 'created_at']
        
    def create(self, validated_data):
        # Get the user from the request context
        user = self.context['request'].user
        post = validated_data.get('post')
        is_upvote = validated_data.get('is_upvote')
        
        # Temporary variable to track if vote was removed
        vote_removed = False
        
        # Check if user has already voted on this post
        try:
            vote = PostVote.objects.get(user=user, post=post)
            
            # If vote type is the same, remove the vote (toggle)
            if vote.is_upvote == is_upvote:
                # Update post vote count before deleting
                if is_upvote:
                    post.upvotes = max(0, post.upvotes - 1)
                else:
                    post.downvotes = max(0, post.downvotes - 1)
                post.save()
                
                # Store the vote ID before deleting for return value
                vote_id = vote.id
                vote.delete()
                
                # Mark that vote was removed
                vote_removed = True
                
                # Create a placeholder vote object to return
                # This isn't saved to DB but satisfies DRF's requirement
                vote = PostVote(id=vote_id, user=user, post=post, is_upvote=is_upvote)
                setattr(vote, '_vote_removed', True)  # Add custom attribute to signal removal
                return vote
            
            # Otherwise, change the vote type
            else:
                # Update post vote count before changing
                if is_upvote:
                    post.upvotes += 1
                    post.downvotes = max(0, post.downvotes - 1)
                else:
                    post.downvotes += 1
                    post.upvotes = max(0, post.upvotes - 1)
                    
                vote.is_upvote = is_upvote
                vote.save()
                post.save()
                return vote
                
        except PostVote.DoesNotExist:
            # Create new vote
            vote = PostVote.objects.create(user=user, post=post, is_upvote=is_upvote)
            
            # Update post vote count
            if is_upvote:
                post.upvotes += 1
            else:
                post.downvotes += 1
                
            post.save()
            return vote

class PostThreadSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    author_profile_pic = serializers.SerializerMethodField()
    time_ago = serializers.SerializerMethodField()
    
    class Meta:
        model = PostThread
        fields = [
            'id', 'post', 'author', 'author_name', 'author_profile_pic',
            'content', 'media_url', 'created_at', 'updated_at', 
            'likes', 'replies', 'is_verified_location', 'time_ago'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'likes', 'replies']
    
    def get_author_name(self, obj):
        return f"{obj.author.first_name} {obj.author.last_name}".strip() or obj.author.username
    
    def get_author_profile_pic(self, obj):
        # Get author profile picture if available
        if hasattr(obj.author, 'profile') and obj.author.profile.profile_picture:
            return obj.author.profile.profile_picture.url
        return ""
    
    def get_time_ago(self, obj):
        from django.utils import timezone
        from datetime import timedelta
        
        now = timezone.now()
        diff = now - obj.created_at
        
        if diff < timedelta(minutes=1):
            return "Just now"
        elif diff < timedelta(hours=1):
            minutes = int(diff.total_seconds() / 60)
            return f"{minutes}m ago"
        elif diff < timedelta(days=1):
            hours = int(diff.total_seconds() / 3600)
            return f"{hours}h ago"
        elif diff < timedelta(days=7):
            days = diff.days
            return f"{days}d ago"
        else:
            return obj.created_at.strftime("%b %d, %Y")
    
    def create(self, validated_data):
        # Get the user from the request context
        user = self.context['request'].user
        
        # Create the thread with the current user as author
        thread = PostThread.objects.create(
            author=user,
            **validated_data
        )
        
        return thread