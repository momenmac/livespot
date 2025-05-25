from rest_framework import serializers
from accounts.serializers import AccountAuthorSerializer
from .models import PostCoordinates, Post, PostVote
from django.db.models import Q, Count
from django.utils import timezone
from datetime import timedelta
from math import radians, cos, sin, asin, sqrt

class PostCoordinatesSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostCoordinates
        fields = ['id', 'latitude', 'longitude', 'address']

class PostSerializer(serializers.ModelSerializer):
    location = PostCoordinatesSerializer()
    author = AccountAuthorSerializer(read_only=True)
    user_vote = serializers.IntegerField(read_only=True)
    is_saved = serializers.SerializerMethodField(read_only=True)
    related_posts_count = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Post
        fields = [
            'id', 'title', 'content', 'media_urls', 'category',
            'location', 'author', 'created_at', 'updated_at',
            'upvotes', 'downvotes', 'honesty_score', 'status',
            'is_verified_location', 'taken_within_app',
            'tags', 'user_vote', 'is_anonymous', 'is_saved',
            'related_post', 'related_posts_count'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'upvotes', 
                           'downvotes', 'honesty_score', 'user_vote', 
                           'is_saved', 'related_posts_count']
        
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
        
        # Check for similar posts and link if needed
        similar_post = self.find_similar_post(post)
        if similar_post:
            post.related_post = similar_post
            post.save()
            
        return post
    
    def get_related_posts_count(self, obj):
        """Get the count of posts related to this post"""
        if obj.related_post is None:  # This is a main post
            return Post.objects.filter(related_post=obj).count()
        return 0
    
    def find_similar_post(self, post):
        """Find posts with similar content and nearby location"""
        # Define what "nearby" means in kilometers (100 meters)
        MAX_DISTANCE_KM = 0.1  # 100 meters
        
        # Get posts within the last 24 hours
        recent_time = timezone.now() - timedelta(hours=24)
        
        # Simple content similarity check - match on some keywords
        important_words = [word for word in post.title.lower().split() if len(word) > 4]
        important_words += [word for word in post.content.lower().split() if len(word) > 4]
        
        # If no substantial words found, use any words
        if not important_words and post.title:
            important_words = [word for word in post.title.lower().split()]
        
        content_filters = Q()
        for word in important_words:
            content_filters |= Q(title__icontains=word) | Q(content__icontains=word)
        
        # Find posts with similar content - ensure date filtering works
        similar_posts = Post.objects.filter(
            related_post__isnull=True,  # Only consider main posts
        ).exclude(id=post.id)
        
        # Apply content filter only if we have words to match
        if important_words:
            similar_posts = similar_posts.filter(content_filters)
        
        # Apply date filter separately to ensure it works
        similar_posts = similar_posts.filter(created_at__gte=recent_time)
        
        # Filter for nearby posts using Haversine formula
        for similar_post in similar_posts:
            if self.calculate_distance(
                post.location.latitude, post.location.longitude,
                similar_post.location.latitude, similar_post.location.longitude
            ) <= MAX_DISTANCE_KM:
                return similar_post
                
        return None
    
    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """Calculate distance between two points in kilometers using Haversine formula"""
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlon = lon2 - lon1
        dlat = lat2 - lat1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a))
        r = 6371  # Radius of earth in kilometers
        return c * r
    
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