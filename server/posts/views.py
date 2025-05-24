from django.shortcuts import render
from django.db.models import Q
from django.contrib.postgres.search import SearchVector
from rest_framework import viewsets, status, permissions, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
import math  # Adding missing math import
from .models import Post, Thread, PostVote, PostThread
from .serializers import (
    PostSerializer, 
    ThreadSerializer, 
    ThreadDetailSerializer,
    PostVoteSerializer,
    PostThreadSerializer
)

class IsAuthorOrReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to edit it.
    """
    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed for any request
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions are only allowed to the author
        return obj.author == request.user

class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.all()
    serializer_class = PostSerializer
    permission_classes = [permissions.IsAuthenticated, IsAuthorOrReadOnly]
    filter_backends = [filters.SearchFilter]
    search_fields = ['title', 'content', 'tags']
    
    def perform_create(self, serializer):
        serializer.save()
    
    def get_queryset(self):
        queryset = Post.objects.select_related('author', 'location', 'thread')
        
        # Filter by category if provided
        category = self.request.query_params.get('category')
        if category:
            # Check if this is a comma-separated list of categories
            if ',' in category:
                categories = [cat.strip() for cat in category.split(',')]
                queryset = queryset.filter(category__in=categories)
            else:
                queryset = queryset.filter(category=category)
        
        # Filter by date if provided
        date = self.request.query_params.get('date')
        if date:
            try:
                # Filter by date but order by most recent first
                queryset = queryset.filter(created_at__date=date).order_by('-created_at')
                
                # Get page size from request or use default
                page_size = int(self.request.query_params.get('page_size', '10'))
                
                # Log query info for debugging
                print(f"Date filter query: date={date}, page_size={page_size}")
                print(f"Total posts for date: {queryset.count()}")
            except Exception as e:
                print(f"Date filtering error: {e}")
                # Instead of failing, provide a graceful fallback by getting recent posts
                thirty_days_ago = timezone.now() - timedelta(days=30)
                queryset = queryset.filter(created_at__gte=thirty_days_ago).order_by('-created_at')
        
        # Filter by tag if provided
        tag = self.request.query_params.get('tag')
        if tag:
            queryset = queryset.filter(tags__contains=[tag])
        
        # Default to published posts only
        status_param = self.request.query_params.get('status', 'published')
        if status_param != 'all':
            queryset = queryset.filter(status=status_param)
            
        return queryset
    
    @action(detail=False, methods=['get'])
    def user_posts(self, request):
        """Get posts created by specified user ID"""
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response(
                {"error": "user_id parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Filter out anonymous posts for public viewing
        posts = self.get_queryset().filter(author_id=user_id, is_anonymous=False)
        page = self.paginate_queryset(posts)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def following(self, request):
        """Get posts from users the current user is following"""
        user = request.user
        
        # Get list of users that the current user follows
        following_users = user.following.values_list('followee_id', flat=True)
        
        # Filter out anonymous posts
        posts = self.get_queryset().filter(author_id__in=following_users, is_anonymous=False)
        page = self.paginate_queryset(posts)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get posts near a specific location"""
        try:
            lat = float(request.query_params.get('lat', 0))
            lng = float(request.query_params.get('lng', 0))
            radius = int(request.query_params.get('radius', 1000))  # meters
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid parameters. lat, lng must be floats, radius must be integer"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Approximate 1 degree of lat/lng in meters
        # Rough conversion that works for small distances
        lat_range = radius / 111320.0  # 1 degree of latitude is approximately 111,320 meters
        # Longitude distance varies with latitude
        lng_range = radius / (111320.0 * abs(math.cos(math.radians(lat))))
        
        # Filter posts within the bounding box and exclude anonymous posts
        queryset = self.get_queryset().filter(
            location__latitude__range=(lat - lat_range, lat + lat_range),
            location__longitude__range=(lng - lng_range, lng + lng_range),
            is_anonymous=False
        )
        
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def search(self, request):
        """Search posts by keywords"""
        query = request.query_params.get('query', '')
        if not query:
            return Response(
                {"error": "query parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        posts = Post.objects.annotate(
            search=SearchVector('title', 'content', 'tags')
        ).filter(search=query, is_anonymous=False)  # Exclude anonymous posts from search
        
        page = self.paginate_queryset(posts)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def vote(self, request, pk=None):
        """Vote (upvote/downvote) on a post"""
        # Override default permissions - any authenticated user can vote
        self.permission_classes = [permissions.IsAuthenticated]
        self.check_permissions(request)
        
        post = self.get_object()
        
        # Check if is_upvote is provided
        is_upvote = request.data.get('is_upvote')
        if is_upvote is None:
            return Response(
                {"error": "is_upvote parameter is required (true/false)"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        serializer = PostVoteSerializer(
            data={'post': post.id, 'is_upvote': is_upvote},
            context={'request': request}
        )
        
        if serializer.is_valid():
            try:
                vote = serializer.save()
                
                # Check if vote was removed (has our custom attribute)
                vote_removed = hasattr(vote, '_vote_removed') and vote._vote_removed
                
                # Force reload the post to get accurate counts
                post = Post.objects.get(id=pk)
                
                # Ensure honesty score is recalculated correctly
                total_votes = post.upvotes + post.downvotes
                if total_votes > 0:
                    honesty_ratio = (post.upvotes / total_votes) * 100
                    post.honesty_score = int(honesty_ratio)
                else:
                    post.honesty_score = 50  # Default value when there are no votes
                
                post.save()
                
                # Determine user's current vote status for the response
                user_vote = 0  # Default: no vote
                if not vote_removed:
                    # Check if vote exists and get current state
                    try:
                        user_vote_obj = PostVote.objects.get(
                            post=post,
                            user=request.user
                        )
                        user_vote = 1 if user_vote_obj.is_upvote else -1
                    except PostVote.DoesNotExist:
                        user_vote = 0
                
                # Set user_vote on post for serialization
                setattr(post, '_user_vote', user_vote)
                
                return Response(
                    {
                        'upvotes': post.upvotes,
                        'downvotes': post.downvotes,
                        'honesty_score': post.honesty_score,
                        'vote_removed': vote_removed,
                        'user_vote': user_vote
                    }
                )
            except Exception as e:
                return Response(
                    {"error": f"Failed to process vote: {str(e)}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def saved(self, request):
        """Get saved posts for the specified user"""
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response(
                {"error": "user_id parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Get saved posts from user's saved_posts relation
        from accounts.models import UserProfile
        try:
            user_profile = UserProfile.objects.get(user_id=user_id)
            # Use a try-except block to handle the case where saved_posts might not exist yet
            try:
                saved_post_ids = list(user_profile.saved_posts.values_list('id', flat=True))
                # Filter out anonymous posts from saved posts
                posts = self.get_queryset().filter(id__in=saved_post_ids, is_anonymous=False)
                
                page = self.paginate_queryset(posts)
                if page is not None:
                    serializer = self.get_serializer(page, many=True)
                    return self.get_paginated_response(serializer.data)
                    
                serializer = self.get_serializer(posts, many=True)
                return Response(serializer.data)
            except AttributeError:
                # Return empty list if saved_posts doesn't exist
                return Response([], status=status.HTTP_200_OK)
        except UserProfile.DoesNotExist:
            return Response([], status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'])
    def upvoted(self, request):
        """Get posts upvoted by the specified user"""
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response(
                {"error": "user_id parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Get posts the user has upvoted - exclude anonymous posts
        upvoted_post_ids = PostVote.objects.filter(
            user_id=user_id, 
            is_upvote=True
        ).values_list('post_id', flat=True)
        
        posts = self.get_queryset().filter(id__in=upvoted_post_ids, is_anonymous=False)
        
        page = self.paginate_queryset(posts)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def toggle_save(self, request, pk=None):
        """Save or unsave a post"""
        # Only authenticated users can save posts
        self.permission_classes = [permissions.IsAuthenticated]
        self.check_permissions(request)
        
        post = self.get_object()
        user = request.user
        
        # Get or create the user profile
        from accounts.models import UserProfile
        user_profile = UserProfile.objects.get(user=user)
        
        # Check if post is already saved
        is_saved = user_profile.saved_posts.filter(id=post.id).exists()
        
        if is_saved:
            # Remove post from saved posts
            user_profile.saved_posts.remove(post)
            return Response({'status': 'unsaved'})
        else:
            # Add post to saved posts
            user_profile.saved_posts.add(post)
            return Response({'status': 'saved'})
    
    @action(detail=False, methods=['get'])
    def following_posts(self, request):
        """Get posts from users the current user is following, grouped by user"""
        user = request.user
        
        # Get list of users that the current user follows - check profile model relationship
        try:
            from accounts.models import UserProfile
            # Get the current user's profile
            user_profile = UserProfile.objects.get(user=user)
            # Get the users they are following
            following_users = user_profile.following.values_list('user', flat=True)
            
            # Get recent posts from those users (with media) - exclude anonymous posts
            recent_posts = self.get_queryset().filter(
                author_id__in=following_users,
                is_anonymous=False
            ).filter(media_urls__isnull=False).exclude(media_urls=[])
            
            # Group posts by user
            posts_by_user = {}
            for post in recent_posts:
                username = f"{post.author.first_name} {post.author.last_name}".strip()
                if not username:
                    username = post.author.username  # Fallback to username if name is empty
                
                if username not in posts_by_user:
                    posts_by_user[username] = []
                
                # Format post with complete data for display as story
                post_data = {
                    'id': post.id,
                    'title': post.title,
                    'content': post.content,
                    'category': post.category,
                    'time': post.created_at.isoformat(),
                    'imageUrl': post.media_urls[0] if post.media_urls else '',
                    'upvotes': post.upvotes,
                    'honesty_score': post.honesty_score,
                    'comments': post.thread.posts.count() if post.thread else 0,
                    'isVerified': post.is_verified_location,
                    'is_admin': post.author.is_admin,
                    'location': {
                        'coordinates': {
                            'latitude': post.location.latitude,
                            'longitude': post.location.longitude
                        },
                        'address': post.location.address or 'Location available'
                    }
                }
                
                posts_by_user[username].append(post_data)
            
            return Response(posts_by_user)
        except Exception as e:
            return Response(
                {"error": f"Failed to retrieve stories: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class ThreadViewSet(viewsets.ModelViewSet):
    queryset = Thread.objects.all()
    serializer_class = ThreadSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ThreadDetailSerializer
        return ThreadSerializer
    
    def get_queryset(self):
        queryset = Thread.objects.all()
        
        # Filter by category if provided
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
        
        # Filter by date if provided
        date = self.request.query_params.get('date')
        if date:
            queryset = queryset.filter(created_at__date=date)
        
        # Filter by tag if provided
        tag = self.request.query_params.get('tag')
        if tag:
            queryset = queryset.filter(tags__contains=[tag])
            
        return queryset
    
    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get threads near a specific location"""
        import math
        
        try:
            lat = float(request.query_params.get('lat', 0))
            lng = float(request.query_params.get('lng', 0))
            radius = int(request.query_params.get('radius', 1000))  # meters
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid parameters. lat, lng must be floats, radius must be integer"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Approximate 1 degree of lat/lng in meters
        # Rough conversion that works for small distances
        lat_range = radius / 111320.0  # 1 degree of latitude is approximately 111,320 meters
        # Longitude distance varies with latitude
        lng_range = radius / (111320.0 * abs(math.cos(math.radians(lat))))
        
        # Filter threads within the bounding box
        queryset = self.get_queryset().filter(
            location__latitude__range=(lat - lat_range, lat + lat_range),
            location__longitude__range=(lng - lng_range, lng + lng_range)
        ).prefetch_related('posts')
        
        # Apply category filter if provided
        category = request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
            
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = ThreadDetailSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = ThreadDetailSerializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def add_post(self, request, pk=None):
        """Add a post to a thread"""
        thread = self.get_object()
        post_data = request.data.copy()
        post_data['thread'] = thread.id
        
        serializer = PostSerializer(data=post_data, context={'request': request})
        if serializer.is_valid():
            post = serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PostThreadViewSet(viewsets.ModelViewSet):
    serializer_class = PostThreadSerializer
    permission_classes = [permissions.IsAuthenticated, IsAuthorOrReadOnly]
    
    def get_queryset(self):
        # Get threads for a specific post if post_id is provided
        post_id = self.request.query_params.get('post_id')
        if post_id:
            return PostThread.objects.filter(post_id=post_id).select_related('author', 'post')
        return PostThread.objects.all().select_related('author', 'post')
    
    def perform_create(self, serializer):
        """Create a new thread with location verification"""
        post_id = serializer.validated_data.get('post').id
        try:
            post = Post.objects.get(id=post_id)
            
            # Verify the user's location is close to the post's location
            user_lat = self.request.data.get('user_latitude')
            user_lng = self.request.data.get('user_longitude')
            
            if user_lat and user_lng:
                # Convert to float
                user_lat = float(user_lat)
                user_lng = float(user_lng)
                
                # Calculate the distance between user and post location
                import math
                
                # Earth's radius in meters
                R = 6371000  
                
                # Convert latitude and longitude from degrees to radians
                lat1_rad = math.radians(user_lat)
                lng1_rad = math.radians(user_lng)
                lat2_rad = math.radians(post.location.latitude)
                lng2_rad = math.radians(post.location.longitude)
                
                # Haversine formula to calculate distance
                dlat = lat2_rad - lat1_rad
                dlng = lng2_rad - lng1_rad
                a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng/2) * math.sin(dlng/2)
                c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
                distance = R * c  # Distance in meters
                
                # Set the is_verified_location flag if user is within 1000 meters
                is_verified = distance <= 1000  # Within 1km
                serializer.save(is_verified_location=is_verified)
            else:
                # If user location not provided, set as not verified
                serializer.save(is_verified_location=False)
        except Post.DoesNotExist:
            # If post doesn't exist, still create the thread but mark as not verified
            serializer.save(is_verified_location=False)
    
    def create(self, request, *args, **kwargs):
        """Override create to enforce image requirement"""
        # Check if media URL is provided
        if not request.data.get('media_url'):
            return Response(
                {"error": "An image is required to create a thread"},
                status=status.HTTP_400_BAD_REQUEST
            )
            
        return super().create(request, *args, **kwargs)
