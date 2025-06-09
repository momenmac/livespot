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
    # Event status fields
    event_status = serializers.CharField(write_only=True, required=False)
    is_happening = serializers.SerializerMethodField(read_only=True)
    is_ended = serializers.SerializerMethodField(read_only=True)
    ended_votes_count = serializers.SerializerMethodField(read_only=True)
    happening_votes_count = serializers.SerializerMethodField(read_only=True)
    user_status_vote = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Post
        fields = [
            'id', 'title', 'content', 'media_urls', 'category',
            'location', 'author', 'created_at', 'updated_at',
            'upvotes', 'downvotes', 'honesty_score', 'status',
            'is_verified_location', 'taken_within_app',
            'tags', 'user_vote', 'is_anonymous', 'is_saved',
            'related_post', 'related_posts_count', 'event_status',
            'is_happening', 'is_ended', 'ended_votes_count', 
            'happening_votes_count', 'user_status_vote'
        ]
        read_only_fields = ['id', 'updated_at', 'upvotes', 
                           'downvotes', 'honesty_score', 'user_vote', 
                           'is_saved', 'related_posts_count', 'is_happening',
                           'is_ended', 'ended_votes_count', 'happening_votes_count',
                           'user_status_vote']
        
    def create(self, validated_data):
        print(f"🔍 PostSerializer.create received validated_data: {validated_data}")
        
        # Extract location data and create PostCoordinates object
        location_data = validated_data.pop('location')
        
        # Handle URL-encoded address by decoding it
        if location_data.get('address'):
            try:
                import urllib.parse
                location_data['address'] = urllib.parse.unquote(location_data['address'])
            except Exception as e:
                print(f"Error decoding address: {e}")
        
        location = PostCoordinates.objects.create(**location_data)
        
        # Handle event_status mapping to status field
        event_status = validated_data.pop('event_status', None)
        print(f"🔍 PostSerializer.create: event_status = {event_status} (type: {type(event_status)})")
        
        if event_status:
            # Map frontend event_status to backend status field
            if event_status == 'ended':
                validated_data['status'] = 'ended'
                print(f"🔍 PostSerializer.create: Setting status to 'ended'")
            elif event_status == 'happening':
                validated_data['status'] = 'happening'
                print(f"🔍 PostSerializer.create: Setting status to 'happening'")
            else:
                # Default to happening if invalid status
                validated_data['status'] = 'happening'
                print(f"🔍 PostSerializer.create: Invalid event_status '{event_status}', defaulting to 'happening'")
        else:
            print(f"🔍 PostSerializer.create: No event_status provided, status field will be default")
        
        # Handle custom created_at datetime (for admin users)
        custom_created_at = validated_data.get('created_at')
        if custom_created_at:
            # Ensure the datetime is timezone-aware
            if timezone.is_naive(custom_created_at):
                # Convert naive datetime to UTC
                custom_created_at = timezone.make_aware(custom_created_at, timezone.utc)
                validated_data['created_at'] = custom_created_at
            print(f"🔍 PostSerializer.create: Using custom created_at: {custom_created_at}")
        else:
            # Use current UTC time if no custom datetime provided
            validated_data['created_at'] = timezone.now()
            print(f"🔍 PostSerializer.create: Using current time: {validated_data['created_at']}")
        
        # Set updated_at = created_at for new posts
        validated_data['updated_at'] = validated_data['created_at']
        
        print(f"🔍 PostSerializer.create: Final validated_data before creating post: {validated_data}")
        
        # Create the post with the author from the request context
        author = self.context['request'].user
        post = Post.objects.create(
            author=author,
            location=location,
            **validated_data
        )
        
        print(f"🔍 PostSerializer.create: Created post with ID {post.id}, status = '{post.status}'")
        
        # Check for similar posts and link if needed
        # Note: find_similar_post enforces strict validation:
        # - Same category required
        # - Within 24 hours required  
        # - Within 100 meters required
        # - Similar content required
        similar_post = self.find_similar_post(post)
        if similar_post:
            print(f"🔍 PostSerializer.create: Linking post {post.id} to similar post {similar_post.id}")
            post.related_post = similar_post
            post.save()
        else:
            print(f"🔍 PostSerializer.create: No similar posts found - post {post.id} will be a main post")
            
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
        
        # Get posts within the last 24 hours only
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
        
        # Find posts with similar content - ensure strict filtering
        similar_posts = Post.objects.filter(
            related_post__isnull=True,  # Only consider main posts
            category=post.category,  # Must have the same category
            created_at__gte=recent_time,  # Must be within 24 hours
        ).exclude(id=post.id)
        
        # Apply content filter only if we have words to match
        if important_words:
            similar_posts = similar_posts.filter(content_filters)
        
        print(f"🔍 COMBINATION DEBUG - Looking for similar posts to combine with post: {post.title}")
        print(f"🔍 COMBINATION DEBUG - Post category: {post.category}, created_at: {post.created_at}")
        print(f"🔍 COMBINATION DEBUG - Recent time threshold: {recent_time}")
        print(f"🔍 COMBINATION DEBUG - Found {similar_posts.count()} candidate posts after category and date filtering")
        
        # Filter for nearby posts using Haversine formula
        for similar_post in similar_posts:
            distance = self.calculate_distance(
                post.location.latitude, post.location.longitude,
                similar_post.location.latitude, similar_post.location.longitude
            )
            
            print(f"🔍 COMBINATION DEBUG - Checking post '{similar_post.title}' (category: {similar_post.category}, created: {similar_post.created_at})")
            print(f"🔍 COMBINATION DEBUG - Distance: {distance:.3f} km (max allowed: {MAX_DISTANCE_KM} km)")
            
            if distance <= MAX_DISTANCE_KM:
                print(f"✅ COMBINATION DEBUG - Found matching post to combine with: '{similar_post.title}'")
                return similar_post
                
        print(f"❌ COMBINATION DEBUG - No suitable posts found for combination")
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
            
            # Use cached votes if available (added in get_queryset)
            if hasattr(request, '_cached_user_votes'):
                user_vote = request._cached_user_votes.get(instance.id, 0)
                representation['user_vote'] = user_vote
                setattr(instance, '_user_vote', user_vote)
            else:
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
            
            # Get the cached saved post IDs from the context if they exist
            if not hasattr(request, '_cached_saved_post_ids'):
                from accounts.models import UserProfile
                try:
                    profile = UserProfile.objects.get(user=user)
                    if hasattr(profile, 'saved_posts'):
                        # Fetch all saved post IDs at once and store them in a set for O(1) lookup
                        request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                    else:
                        request._cached_saved_post_ids = set()
                except UserProfile.DoesNotExist:
                    request._cached_saved_post_ids = set()
            
            # Use the cached set for fast lookup
            is_saved = obj.id in request._cached_saved_post_ids
            return is_saved
            
        return False
    
    def get_is_happening(self, obj):
        """Check if the event is currently happening"""
        return obj.is_happening
    
    def get_is_ended(self, obj):
        """Check if the event has ended"""
        return obj.is_ended
    
    def get_ended_votes_count(self, obj):
        """Get count of users who voted that this event has ended"""
        # Use cached value if it exists on the instance to avoid DB query
        if hasattr(obj, '_ended_votes_count'):
            return obj._ended_votes_count
        return obj.get_ended_votes_count()
    
    def get_happening_votes_count(self, obj):
        """Get count of users who voted that this event is still happening"""
        # Use cached value if it exists on the instance to avoid DB query
        if hasattr(obj, '_happening_votes_count'):
            return obj._happening_votes_count
        return obj.get_happening_votes_count()
    
    def get_user_status_vote(self, obj):
        """Get the current user's vote on whether this event has ended"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # Check if we have cached status votes
            if hasattr(request, '_cached_status_votes'):
                # Return cached status vote if available
                if obj.id in request._cached_status_votes:
                    return request._cached_status_votes[obj.id]
            else:
                # Create the cache if it doesn't exist
                request._cached_status_votes = {}
                
            # If not in cache, query the database
            from .models import EventStatusVote
            try:
                vote = EventStatusVote.objects.get(user=request.user, post=obj)
                status_vote = 'ended' if vote.voted_ended else 'happening'
                # Cache the result for future use
                request._cached_status_votes[obj.id] = status_vote
                return status_vote
            except EventStatusVote.DoesNotExist:
                # Cache the null result as well
                request._cached_status_votes[obj.id] = None
                return None  # User hasn't voted on status
        return None

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

class UserPostSerializer(PostSerializer):
    """
    Optimized serializer for user_posts endpoint that excludes is_saved field
    to prevent unnecessary database queries when fetching user's own posts
    """
    class Meta(PostSerializer.Meta):
        fields = [field for field in PostSerializer.Meta.fields if field != 'is_saved']
        read_only_fields = [field for field in PostSerializer.Meta.read_only_fields if field != 'is_saved']
    
    def get_is_saved(self, obj):
        # Override to skip is_saved calculation for performance
        return False