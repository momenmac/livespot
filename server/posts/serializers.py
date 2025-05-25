from rest_framework import serializers
from accounts.serializers import AccountAuthorSerializer
from .models import PostCoordinates, Post, PostVote

class PostCoordinatesSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostCoordinates
        fields = ['id', 'latitude', 'longitude', 'address']

class PostSerializer(serializers.ModelSerializer):
    location = PostCoordinatesSerializer()
    author = AccountAuthorSerializer(read_only=True)
    user_vote = serializers.IntegerField(read_only=True)
    is_saved = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Post
        fields = [
            'id', 'title', 'content', 'media_urls', 'category',
            'location', 'author', 'created_at', 'updated_at',
            'upvotes', 'downvotes', 'honesty_score', 'status',
            'is_verified_location', 'taken_within_app',
            'tags', 'user_vote', 'is_anonymous', 'is_saved'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'upvotes', 'downvotes', 'honesty_score', 'user_vote', 'is_saved']
        
    def create(self, validated_data):
        # Extract location data and create PostCoordinates object
        location_data = validated_data.pop('location')
        location = PostCoordinates.objects.create(**location_data)
        
        # Create the post with the author from the request context
        author = self.context['request'].user
        post = Post.objects.create(
            author=author,
            location=location,
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
    
    def get_is_saved(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            user = request.user
            from accounts.models import UserProfile
            try:
                profile = UserProfile.objects.get(user=user)
                # Check if the profile has saved_posts attribute and if this post is in it
                if hasattr(profile, 'saved_posts'):
                    return profile.saved_posts.filter(id=obj.id).exists()
            except UserProfile.DoesNotExist:
                pass
        return False

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