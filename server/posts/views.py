from django.shortcuts import render
from django.db.models import Q, Count, F, Sum
from django.contrib.postgres.search import SearchVector
from django.http import JsonResponse
from rest_framework import viewsets, status, permissions, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import datetime, timedelta
import math  # Adding missing math import
from .models import Post, PostVote, EventStatusVote, CategoryInteraction
from .serializers import (
    PostSerializer, 
    PostVoteSerializer
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
    
    def get_serializer_context(self):
        """
        Ensure the serializer has access to the request context for user-specific fields like is_saved
        """
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def perform_create(self, serializer):
        print(f"🔍 PostViewSet.perform_create: Raw request data = {self.request.data}")
        post = serializer.save()
        print(f"🔍 PostViewSet.perform_create: Created post ID {post.id}, category: {post.category}")
        if post.related_post:
            print(f"🔍 PostViewSet.perform_create: Post linked to main post ID {post.related_post.id}")
        else:
            print(f"🔍 PostViewSet.perform_create: Post created as main post (no related post)")
        return post
    
    def get_queryset(self):
        """
        Get the list of posts based on various filter criteria.
        By default, return only main posts (where related_post is null).
        """
        from django.db.models import Count, Q, Case, When, IntegerField
        import datetime
        from django.utils import timezone
        
        # Check if we have a request-level cache of the queryset
        if hasattr(self.request, '_cached_base_queryset'):
            queryset = self.request._cached_base_queryset
        else:
            # Start with a base queryset that includes select_related to reduce DB queries
            queryset = Post.objects.select_related('author', 'location', 'related_post').order_by('-created_at')
            
            # Store at request level for reuse in the same request
            self.request._cached_base_queryset = queryset
        
        # Check and update event status for time-based auto-ending (with optimization)
        self._check_and_update_event_status(queryset)
        
        # Annotate with related posts count (sons count for fathers)
        queryset = queryset.annotate(
            _related_posts_count=Case(
                When(related_post__isnull=True, then=Count('related_posts')),
                default=0,
                output_field=IntegerField()
            )
        )
        
        # Date filtering - proper implementation
        date_str = self.request.query_params.get('date')
        if date_str:
            try:
                # Parse the date string
                filter_date = datetime.datetime.strptime(date_str, '%Y-%m-%d').date()
                
                # Create datetime objects for the start and end of the day
                start_datetime = datetime.datetime.combine(filter_date, datetime.datetime.min.time())
                end_datetime = datetime.datetime.combine(filter_date, datetime.datetime.max.time())
                
                # Apply timezone awareness if using timezone-aware datetimes in Django
                if timezone.is_aware(timezone.now()):
                    start_datetime = timezone.make_aware(start_datetime)
                    end_datetime = timezone.make_aware(end_datetime)
                
                # Filter queryset by date range
                queryset = queryset.filter(created_at__gte=start_datetime, created_at__lte=end_datetime)
                
                # Debug output to help diagnose issues
                print(f"Date filtering: {date_str} -> {start_datetime} to {end_datetime}")
                print(f"Found {queryset.count()} posts for this date")
            except ValueError:
                print(f"Invalid date format: {date_str}")
        
        # By default, only show main posts (fathers)
        show_related = self.request.query_params.get('show_related', 'false').lower() == 'true'
        if not show_related:
            queryset = queryset.filter(related_post__isnull=True)
            
        # Add filtering by related_post_id to get all posts related to a specific post
        related_to = self.request.query_params.get('related_to')
        if related_to:
            try:
                related_to_id = int(related_to)
                # Get the main post and all its related posts
                main_post = Post.objects.get(id=related_to_id)
                if main_post.related_post is None:
                    # This is a main post, get it and all its related posts
                    queryset = Post.objects.filter(
                        Q(id=related_to_id) | Q(related_post_id=related_to_id)
                    ).select_related('author', 'location')
                else:
                    # This is a related post, get the main post and all related posts
                    queryset = Post.objects.filter(
                        Q(id=main_post.related_post.id) | Q(related_post_id=main_post.related_post.id)
                    ).select_related('author', 'location')
                
                # Prefetch votes for better performance
                queryset = queryset.prefetch_related('votes')
            except (ValueError, Post.DoesNotExist):
                pass
        
        # Category filtering with interaction tracking
        category = self.request.query_params.get('category')
        if category and category.upper() != 'ALL':
            # Validate category
            from .models import PostCategory
            valid_categories = [choice[0] for choice in PostCategory.choices]
            if category.lower() in valid_categories:
                queryset = queryset.filter(category=category.lower())
                
                # Track category interaction for analytics
                if hasattr(self, 'request') and self.request.user.is_authenticated:
                    try:
                        CategoryInteraction.increment_interaction(
                            user=self.request.user,
                            category=category.lower(),
                            interaction_type='filter'
                        )
                        print(f"📊 ANALYTICS - User {self.request.user.id} filtered by category: {category}")
                    except Exception as e:
                        print(f"⚠️ ANALYTICS - Failed to track category interaction: {e}")
                
        # Cache the user's saved posts if the user is authenticated
        if hasattr(self, 'request') and self.request.user.is_authenticated:
            if not hasattr(self.request, '_cached_saved_post_ids'):
                from accounts.models import UserProfile
                try:
                    profile = UserProfile.objects.get(user=self.request.user)
                    if hasattr(profile, 'saved_posts'):
                        # Fetch all saved post IDs at once and store them in a set for O(1) lookup
                        self.request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                    else:
                        self.request._cached_saved_post_ids = set()
                except UserProfile.DoesNotExist:
                    self.request._cached_saved_post_ids = set()
        
        # Cache user votes for better performance in serializer
        if hasattr(self, 'request') and self.request.user.is_authenticated and not hasattr(self.request, '_cached_user_votes'):
            from .models import PostVote
            user_votes = PostVote.objects.filter(user=self.request.user)
            self.request._cached_user_votes = {v.post_id: (1 if v.is_upvote else -1) for v in user_votes}
                    
        return queryset
    
    @action(detail=False, methods=['get'])
    def user_posts(self, request):
        """Get posts created by specified user ID"""
        import datetime
        from django.utils import timezone
        
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response(
                {"error": "user_id parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Get ALL posts by user (including both main posts and related posts) with optimized queries
        # Use select_related to reduce DB queries
        posts = Post.objects.filter(author_id=user_id, is_anonymous=False)\
            .select_related('author', 'location')\
            .order_by('-created_at')
        
        # Date filtering - same implementation as main posts endpoint
        date_str = request.query_params.get('date')
        if date_str:
            try:
                # Parse the date string
                filter_date = datetime.datetime.strptime(date_str, '%Y-%m-%d').date()
                
                # Create datetime objects for the start and end of the day
                start_datetime = datetime.datetime.combine(filter_date, datetime.datetime.min.time())
                end_datetime = datetime.datetime.combine(filter_date, datetime.datetime.max.time())
                
                # Apply timezone awareness if using timezone-aware datetimes in Django
                if timezone.is_aware(timezone.now()):
                    start_datetime = timezone.make_aware(start_datetime)
                    end_datetime = timezone.make_aware(end_datetime)
                
                # Filter posts by date range
                posts = posts.filter(created_at__gte=start_datetime, created_at__lte=end_datetime)
                
                # Debug output to help diagnose issues
                print(f"User {user_id} posts date filtering: {date_str} -> {start_datetime} to {end_datetime}")
                print(f"Found {posts.count()} posts for user {user_id} on this date")
            except ValueError:
                print(f"Invalid date format: {date_str}")
                return Response(
                    {"error": "Invalid date format. Use YYYY-MM-DD"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Annotate with related posts count (sons count for fathers)
        from django.db.models import Case, When, IntegerField
        posts = posts.annotate(
            _related_posts_count=Case(
                When(related_post__isnull=True, then=Count('related_posts')),
                default=0,
                output_field=IntegerField()
            )
        )
        
        # Use optimized serializer for user posts that excludes is_saved field
        from .serializers import UserPostSerializer
        
        page = self.paginate_queryset(posts)
        if page is not None:
            serializer = UserPostSerializer(page, many=True, context={'request': request})
            return self.get_paginated_response(serializer.data)
            
        serializer = UserPostSerializer(posts, many=True, context={'request': request})
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
            radius = float(request.query_params.get('radius', 1000))  # meters
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid parameters. lat, lng must be floats, radius must be a number"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Approximate 1 degree of lat/lng in meters
        # Rough conversion that works for small distances
        lat_range = radius / 111320.0  # 1 degree of latitude is approximately 111,320 meters
        # Longitude distance varies with latitude
        lng_range = radius / (111320.0 * abs(math.cos(math.radians(lat))))
        
        # Filter posts within the bounding box and exclude anonymous posts
        # Use select_related and prefetch_related for better performance
        queryset = self.get_queryset().filter(
            location__latitude__range=(lat - lat_range, lat + lat_range),
            location__longitude__range=(lng - lng_range, lng + lng_range),
            is_anonymous=False
        ).select_related('author', 'location', 'related_post')\
         .prefetch_related('votes')
        
        # Ensure the user's saved post IDs are cached for the serializer
        if request.user.is_authenticated and not hasattr(request, '_cached_saved_post_ids'):
            from accounts.models import UserProfile
            try:
                profile = UserProfile.objects.get(user=request.user)
                if hasattr(profile, 'saved_posts'):
                    request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                else:
                    request._cached_saved_post_ids = set()
            except UserProfile.DoesNotExist:
                request._cached_saved_post_ids = set()
        
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            paginated_response = self.get_paginated_response(serializer.data)
            return Response({
                'success': True,
                'data': paginated_response.data
            })
            
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'success': True,
            'data': serializer.data
        })
    
    @action(detail=False, methods=['get'])
    def search(self, request):
        """Search posts by keywords"""
        query = request.query_params.get('query', '')
        if not query:
            return Response(
                {"error": "query parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        # Use select_related to optimize the query
        posts = Post.objects.annotate(
            search=SearchVector('title', 'content', 'tags')
        ).filter(
            search=query, 
            is_anonymous=False
        ).select_related(
            'author', 'location', 'related_post'
        ).prefetch_related(
            'votes'
        )
        
        # Ensure the user's saved post IDs are cached for the serializer
        if request.user.is_authenticated and not hasattr(request, '_cached_saved_post_ids'):
            from accounts.models import UserProfile
            try:
                profile = UserProfile.objects.get(user=request.user)
                if hasattr(profile, 'saved_posts'):
                    request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                else:
                    request._cached_saved_post_ids = set()
            except UserProfile.DoesNotExist:
                request._cached_saved_post_ids = set()
        
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
        
        print(f"🎯 VOTE DEBUG - Starting vote process for post {post.id}, user {request.user.id}, is_upvote: {is_upvote}")
        
        # Check current vote state before operation
        try:
            existing_vote = PostVote.objects.get(post=post, user=request.user)
            print(f"📋 VOTE DEBUG - Existing vote found: is_upvote={existing_vote.is_upvote}")
        except PostVote.DoesNotExist:
            print(f"📋 VOTE DEBUG - No existing vote found")
        
        serializer = PostVoteSerializer(
            data={'post': post.id, 'is_upvote': is_upvote},
            context={'request': request}
        )
        
        if serializer.is_valid():
            try:
                vote = serializer.save()
                print(f"💾 VOTE DEBUG - Serializer save completed. Vote removed: {hasattr(vote, '_vote_removed') and vote._vote_removed}")
                
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
                print(f"📊 VOTE DEBUG - Post updated: upvotes={post.upvotes}, downvotes={post.downvotes}")
                
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
                        print(f"✅ VOTE DEBUG - Found user vote: {user_vote} for post {post.id} user {request.user.id}")
                    except PostVote.DoesNotExist:
                        user_vote = 0
                        print(f"⚠️ VOTE DEBUG - No vote found for post {post.id} user {request.user.id}")
                else:
                    print(f"🗑️ VOTE DEBUG - Vote was removed for post {post.id} user {request.user.id}")
                
                # Set user_vote on post for serialization
                setattr(post, '_user_vote', user_vote)
                
                # Update the vote cache if it exists
                if hasattr(request, '_cached_user_votes'):
                    if user_vote == 0:
                        if post.id in request._cached_user_votes:
                            del request._cached_user_votes[post.id]
                    else:
                        request._cached_user_votes[post.id] = user_vote
                
                response_data = {
                    'upvotes': post.upvotes,
                    'downvotes': post.downvotes,
                    'honesty_score': post.honesty_score,
                    'vote_removed': vote_removed,
                    'user_vote': user_vote
                }
                print(f"📤 VOTE DEBUG - Returning response: {response_data}")
                
                return Response(response_data)
            except Exception as e:
                print(f"❌ VOTE DEBUG - Exception occurred: {str(e)}")
                import traceback
                traceback.print_exc()
                return Response(
                    {"error": f"Failed to process vote: {str(e)}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        print(f"❌ VOTE DEBUG - Serializer validation failed: {serializer.errors}")
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
            # Use select_related to optimize the query
            user_profile = UserProfile.objects.get(user_id=user_id)
            
            # Use prefetch_related to optimize the query for saved posts
            saved_post_ids = list(user_profile.saved_posts.values_list('id', flat=True))
            
            if not saved_post_ids:
                return Response([], status=status.HTTP_200_OK)
                
            # Filter out anonymous posts from saved posts and use prefetch_related for related fields
            posts = self.get_queryset().filter(id__in=saved_post_ids, is_anonymous=False)\
                .select_related('author', 'location')\
                .prefetch_related('votes')
            
            # Cache the saved post IDs for the serializer
            request._cached_saved_post_ids = set(saved_post_ids)
            
            page = self.paginate_queryset(posts)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response(serializer.data)
                
            serializer = self.get_serializer(posts, many=True)
            return Response(serializer.data)
            
        except (UserProfile.DoesNotExist, AttributeError):
            # Return empty list if profile doesn't exist or has no saved_posts
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
        
        if not upvoted_post_ids:
            return Response([], status=status.HTTP_200_OK)
            
        # Use select_related and prefetch_related to optimize the query
        posts = self.get_queryset().filter(id__in=upvoted_post_ids, is_anonymous=False)\
            .select_related('author', 'location')\
            .prefetch_related('votes')
        
        # Cache user's saved posts for serializer if the user is viewing their own upvoted posts
        if str(request.user.id) == str(user_id) and not hasattr(request, '_cached_saved_post_ids'):
            from accounts.models import UserProfile
            try:
                profile = UserProfile.objects.get(user=request.user)
                if hasattr(profile, 'saved_posts'):
                    request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                else:
                    request._cached_saved_post_ids = set()
            except UserProfile.DoesNotExist:
                request._cached_saved_post_ids = set()
        
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
            from django.db.models import Prefetch
            
            # Get the current user's profile and prefetch following users
            user_profile = UserProfile.objects.get(user=user)
            
            # Get the users they are following
            following_users = user_profile.following.values_list('user', flat=True)
            
            if not following_users:
                # Early return if not following anyone
                return Response({})
            
            # Cache saved posts for better performance
            if not hasattr(request, '_cached_saved_post_ids'):
                if hasattr(user_profile, 'saved_posts'):
                    request._cached_saved_post_ids = set(user_profile.saved_posts.values_list('id', flat=True))
                else:
                    request._cached_saved_post_ids = set()
            
            # Get recent posts from those users (with media) - exclude anonymous posts
            # Use select_related and prefetch_related to optimize database queries
            recent_posts = Post.objects.filter(
                author_id__in=following_users,
                is_anonymous=False,
                media_urls__isnull=False
            ).exclude(
                media_urls=[]
            ).select_related(
                'author', 'location', 'related_post'
            ).prefetch_related(
                'votes', 'status_votes'
            ).order_by('-created_at')
            
            # Date filtering - same implementation as other endpoints
            import datetime 
            from django.utils import timezone
            
            date_str = request.query_params.get('date')
            if date_str:
                try:
                    # Parse the date string
                    filter_date = datetime.datetime.strptime(date_str, '%Y-%m-%d').date()
                    
                    # Create datetime objects for the start and end of the day
                    start_datetime = datetime.datetime.combine(filter_date, datetime.datetime.min.time())
                    end_datetime = datetime.datetime.combine(filter_date, datetime.datetime.max.time())
                    
                    # Apply timezone awareness if using timezone-aware datetimes in Django
                    if timezone.is_aware(timezone.now()):
                        start_datetime = timezone.make_aware(start_datetime)
                        end_datetime = timezone.make_aware(end_datetime)
                    
                    # Filter posts by date range
                    recent_posts = recent_posts.filter(created_at__gte=start_datetime, created_at__lte=end_datetime)
                    
                    # Debug output to help diagnose issues
                    print(f"Following posts date filtering: {date_str} -> {start_datetime} to {end_datetime}")
                    print(f"Found {recent_posts.count()} following posts for this date")
                except ValueError:
                    print(f"Invalid date format in following_posts: {date_str}")
                    return Response(
                        {"error": "Invalid date format. Use YYYY-MM-DD"}, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Group posts by user in memory to reduce database queries
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
                    'comments': 0,  # Thread functionality removed
                    'isVerified': post.is_verified_location,
                    'is_admin': post.author.is_admin,
                    'profile_picture_url': post.author.profile_picture.url if post.author.profile_picture else None,
                    'author_id': post.author.id,
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
    
    @action(detail=True, methods=['get'])
    def related(self, request, pk=None):
        """Get all posts related to this post"""
        try:
            print(f"DEBUG: Related endpoint called with pk={pk}")
            
            # Get the post with optimized query using select_related
            post = Post.objects.select_related('related_post', 'author', 'location').get(pk=pk)
            
            print(f"DEBUG: Getting related posts for post {pk}")
            print(f"DEBUG: Post {pk} related_post field: {post.related_post}")
            print(f"DEBUG: Post {pk} is_main_post: {post.is_main_post}")
            
            # If this is a main post (father), get all its related posts (sons)
            if post.related_post is None:
                # Optimize query with select_related and prefetch_related
                related_posts = Post.objects.filter(related_post=post)\
                    .select_related('author', 'location')\
                    .prefetch_related('votes')
                
                print(f"DEBUG: This is a main post, found {related_posts.count()} related posts")
            else:
                # This is a related post (son), get all other posts related to the same main post
                main_post = post.related_post
                
                # Optimize query with select_related and prefetch_related
                related_posts = Post.objects.filter(
                    Q(related_post=main_post) | Q(id=main_post.id)
                ).exclude(id=post.id)\
                    .select_related('author', 'location')\
                    .prefetch_related('votes')
                
                print(f"DEBUG: This is a related post, found {related_posts.count()} related posts")
            
            # Cache the user's saved posts for better performance
            if request.user.is_authenticated and not hasattr(request, '_cached_saved_post_ids'):
                from accounts.models import UserProfile
                try:
                    profile = UserProfile.objects.get(user=request.user)
                    if hasattr(profile, 'saved_posts'):
                        request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
                    else:
                        request._cached_saved_post_ids = set()
                except UserProfile.DoesNotExist:
                    request._cached_saved_post_ids = set()
            
            # Ensure proper UTF-8 encoding for Arabic content
            serializer = self.get_serializer(related_posts, many=True)
            response_data = serializer.data
            
            print(f"DEBUG: Serialized {len(response_data)} posts for response")
            
            # Return JsonResponse with ensure_ascii=False to properly handle Arabic
            from django.http import JsonResponse
            return JsonResponse(
                response_data, 
                safe=False, 
                json_dumps_params={'ensure_ascii': False}
            )
            
        except Post.DoesNotExist:
            print(f"DEBUG: Post {pk} does not exist")
            return Response(status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            print(f"DEBUG: Exception in related endpoint: {e}")
            return Response(
                {"error": str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=True, methods=['post'])
    def vote_status(self, request, pk=None):
        """Vote on whether an event has ended or is still happening"""
        self.permission_classes = [permissions.IsAuthenticated]
        self.check_permissions(request)
        
        # Get the post with select_related for better performance
        post = Post.objects.select_related('author', 'location').get(pk=pk)
        
        # Check if event_ended is provided
        event_ended = request.data.get('event_ended')
        if event_ended is None:
            return Response(
                {"error": "event_ended parameter is required (true/false)"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Import the EventStatusVote model
        from .models import EventStatusVote, PostStatus
        
        print(f"🎯 STATUS VOTE DEBUG - User {request.user.id} voting on post {post.id}, event_ended: {event_ended}")
        
        # Get or create the vote
        vote, created = EventStatusVote.objects.get_or_create(
            post=post,
            user=request.user,
            defaults={'voted_ended': event_ended}
        )
        
        if not created:
            # Update existing vote
            vote.voted_ended = event_ended
            vote.save()
            print(f"📋 STATUS VOTE DEBUG - Updated existing vote")
        else:
            print(f"📋 STATUS VOTE DEBUG - Created new vote")
        
        # Update the cache if it exists
        if hasattr(request, '_cached_status_votes'):
            request._cached_status_votes[post.id] = 'ended' if event_ended else 'happening'
        
        # Check if event should be marked as ended based on votes
        if post.should_mark_as_ended() and post.status == PostStatus.HAPPENING:
            post.status = PostStatus.ENDED
            post.save(update_fields=['status'])
            print(f"🎯 STATUS VOTE DEBUG - Event marked as ended due to votes")
        
        # Get current vote counts - use optimized Count query to avoid multiple queries
        from django.db.models import Count, Q
        vote_counts = EventStatusVote.objects.filter(post=post).aggregate(
            ended_votes=Count('id', filter=Q(voted_ended=True)),
            happening_votes=Count('id', filter=Q(voted_ended=False))
        )
        
        response_data = {
            'status': post.status,
            'ended_votes': vote_counts['ended_votes'],
            'happening_votes': vote_counts['happening_votes'],
            'user_voted_ended': event_ended
        }
        
        # Cache the vote counts on the post instance for future use
        post._ended_votes_count = vote_counts['ended_votes']
        post._happening_votes_count = vote_counts['happening_votes']
        
        print(f"📤 STATUS VOTE DEBUG - Returning response: {response_data}")
        return Response(response_data)
    
    @action(detail=False, methods=['get'])
    def category_analytics(self, request):
        """Get category interaction analytics for the authenticated user"""
        if not request.user.is_authenticated:
            return Response(
                {"error": "Authentication required"}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        from django.db.models import Count
        from datetime import datetime, timedelta
        from django.utils import timezone
        
        # Get time range for analytics (default: last 30 days)
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now() - timedelta(days=days)
        
        # Get category interactions for the user
        interactions = CategoryInteraction.objects.filter(
            user=request.user,
            created_at__gte=start_date
        ).values('category').annotate(
            count=Count('id')
        ).order_by('-count')
        
        # Get all possible categories for completeness
        from .models import PostCategory
        all_categories = [choice[0] for choice in PostCategory.choices]
        
        # Create a complete dataset with zeros for categories not interacted with
        analytics_data = {}
        for category in all_categories:
            analytics_data[category] = 0
        
        # Fill in actual interaction counts
        for interaction in interactions:
            analytics_data[interaction['category']] = interaction['count']
        
        # Convert to list format for easier frontend consumption
        category_stats = [
            {
                'category': category,
                'count': count,
                'label': dict(PostCategory.choices).get(category, category.title())
            }
            for category, count in analytics_data.items()
        ]
        
        # Sort by count descending
        category_stats.sort(key=lambda x: x['count'], reverse=True)
        
        return Response({
            'success': True,
            'data': {
                'period_days': days,
                'total_interactions': sum(analytics_data.values()),
                'categories': category_stats
            }
        })
    
    @action(detail=False, methods=['get'])
    def recommended(self, request):
        """Get smart recommendations based on user location, preferences, time, and content diversity"""
        if not request.user.is_authenticated:
            return Response(
                {"error": "Authentication required"}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Get user location parameters
        user_lat = request.query_params.get('latitude')
        user_lng = request.query_params.get('longitude')
        radius_km = float(request.query_params.get('radius', 50))  # Increased default radius to 50km
        limit = int(request.query_params.get('limit', 20))  # Default 20 posts
        date_filter = request.query_params.get('date')  # Optional date filter (YYYY-MM-DD)
        
        if not user_lat or not user_lng:
            return Response(
                {"error": "User location (latitude, longitude) is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user_lat = float(user_lat)
            user_lng = float(user_lng)
        except ValueError:
            return Response(
                {"error": "Invalid latitude or longitude format"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        print(f"🎯 RECOMMENDATIONS - User location: ({user_lat}, {user_lng}), radius: {radius_km}km")
        
        # Get user's category preferences from analytics with time decay
        user_preferences, user_has_preferences = self._get_smart_user_preferences(request.user)
        print(f"🎯 RECOMMENDATIONS - User preferences: {user_preferences} (has_prefs: {user_has_preferences})")
        
        # Get candidate posts (nearby + some global trending if needed)
        nearby_posts = self._get_nearby_posts(user_lat, user_lng, radius_km, date_filter)
        print(f"🎯 RECOMMENDATIONS - Found {len(nearby_posts)} nearby posts")
        
        # If we don't have enough nearby posts, expand search or add trending posts
        if len(nearby_posts) < limit:
            additional_posts = self._get_fallback_posts(request.user, user_lat, user_lng, 
                                                       limit - len(nearby_posts), date_filter)
            print(f"🎯 RECOMMENDATIONS - Added {len(additional_posts)} fallback posts")
            
            # Remove duplicates before extending
            nearby_ids = set(post.id for post in nearby_posts)
            unique_additional = [post for post in additional_posts if post.id not in nearby_ids]
            nearby_posts.extend(unique_additional)
        
        # Remove any remaining duplicates
        seen_ids = set()
        unique_posts = []
        for post in nearby_posts:
            if post.id not in seen_ids:
                seen_ids.add(post.id)
                unique_posts.append(post)
        
        # Apply sophisticated scoring algorithm
        recommended_posts = self._calculate_smart_recommendation_scores(
            unique_posts, user_preferences, request.user, user_lat, user_lng
        )
        
        # Ensure content diversity and category mixing
        diversified_posts = self._ensure_smart_content_diversity(
            recommended_posts, user_preferences, user_has_preferences
        )
        
        # Limit results
        final_recommendations = diversified_posts[:limit]
        
        # Add recommendation metadata to posts
        for post in final_recommendations:
            post.is_recommended = getattr(post, 'recommendation_score', 0) > 0.5
            post.recommendation_reason = getattr(post, 'recommendation_reason', 'location')
        
        # Serialize the results
        serializer = PostSerializer(final_recommendations, many=True, context={'request': request})
        
        # Calculate statistics
        recommended_count = len([p for p in final_recommendations if getattr(p, 'is_recommended', False)])
        other_count = len(final_recommendations) - recommended_count
        
        return Response({
            'success': True,
            'data': {
                'total_nearby': len(nearby_posts),
                'total_recommended': len(final_recommendations),
                'user_location': {'latitude': user_lat, 'longitude': user_lng},
                'radius_km': radius_km,
                'date_filter': date_filter,
                'recommendation_info': {
                    'user_has_preferences': user_has_preferences,
                    'recommended_posts': recommended_count,
                    'other_posts': other_count,
                    'total_posts': len(final_recommendations)
                },
                'posts': serializer.data
            }
        })
    
    def _get_smart_user_preferences(self, user):
        """Get user's category preferences with time decay and emphasis on recently filtered categories"""
        now = timezone.now()
        start_date = now - timedelta(days=30)
        
        # Get category interactions with emphasis on 'filter' type interactions (category clicks)
        interactions = CategoryInteraction.objects.filter(
            user=user,
            created_at__gte=start_date
        ).values('category', 'count', 'last_updated', 'interaction_type')
        
        prefs_dict = {}
        total_weight = 0
        
        for interaction in interactions:
            # Calculate time-based weight with stronger decay for filter interactions
            hours_old = (now - interaction['last_updated']).total_seconds() / 3600
            
            # Different time decay based on interaction type
            if interaction['interaction_type'] == 'filter':
                # Category filter clicks get much stronger recent boost
                if hours_old < 1:  # Last hour
                    time_weight = 5.0  # 5x boost for very recent filter clicks
                elif hours_old < 6:  # Last 6 hours
                    time_weight = 3.0  # 3x boost for recent filter clicks
                elif hours_old < 24:  # Last day
                    time_weight = 2.0  # 2x boost for same-day filter clicks
                elif hours_old < 168:  # Last week
                    time_weight = 1.5  # 1.5x boost for recent week
                else:
                    time_weight = max(0.1, 1.0 - (hours_old / (30 * 24)))  # Normal decay
                
                # Filter interactions get base multiplier
                base_multiplier = 2.0
                
            elif interaction['interaction_type'] == 'view':
                # Views get moderate time-based boost
                if hours_old < 24:
                    time_weight = 1.2
                else:
                    time_weight = max(0.1, 1.0 - (hours_old / (30 * 24)))
                base_multiplier = 1.0
                
            else:  # Other interactions (vote, save, etc.)
                # Regular interactions get normal weight
                time_weight = max(0.1, 1.0 - (hours_old / (30 * 24)))
                base_multiplier = 1.5
            
            # Calculate final weighted count
            weighted_count = interaction['count'] * time_weight * base_multiplier
            
            if interaction['category'] in prefs_dict:
                prefs_dict[interaction['category']] += weighted_count
            else:
                prefs_dict[interaction['category']] = weighted_count
            
            total_weight += weighted_count
            
            # Debug recent filter interactions
            if interaction['interaction_type'] == 'filter' and hours_old < 24:
                print(f"🎯 FILTER BOOST - Category '{interaction['category']}' filtered {hours_old:.1f}h ago, weight: {time_weight}x")
        
        # Normalize preferences
        if total_weight > 0:
            for category in prefs_dict:
                prefs_dict[category] = prefs_dict[category] / total_weight
        
        user_has_preferences = len(prefs_dict) > 0
        
        # If user has no preferences, create balanced default weights for all categories
        if not user_has_preferences:
            from .models import PostCategory
            all_categories = [choice[0] for choice in PostCategory.choices]
            equal_weight = 1.0 / len(all_categories)
            prefs_dict = {cat: equal_weight for cat in all_categories}
        
        return prefs_dict, user_has_preferences
    
    def _get_nearby_posts(self, user_lat, user_lng, radius_km, date_filter=None):
        """Get posts within specified radius with optional date filtering"""
        # Haversine formula approximation for filtering
        lat_range = radius_km / 111.0  # Approximate km per degree latitude
        lng_range = radius_km / (111.0 * math.cos(math.radians(user_lat)))
        
        # Base query with location filtering
        queryset = Post.objects.select_related(
            'location', 'author'
        ).prefetch_related(
            'votes'
        ).filter(
            location__latitude__range=(user_lat - lat_range, user_lat + lat_range),
            location__longitude__range=(user_lng - lng_range, user_lng + lng_range)
        )
        
        # Apply date filter if provided
        if date_filter:
            try:
                from datetime import datetime
                filter_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
                queryset = queryset.filter(created_at__date=filter_date)
                print(f"🎯 NEARBY - Applied date filter: {filter_date}")
            except ValueError:
                print(f"⚠️ Invalid date format: {date_filter}, ignoring date filter")
        else:
            # Default: posts from last 7 days (more recent than before)
            queryset = queryset.filter(
                created_at__gte=timezone.now() - timedelta(days=7)
            )
        
        candidate_posts = queryset.order_by('-created_at')[:100]  # Limit to prevent huge queries
        
        # Calculate exact distances and filter
        nearby_posts = []
        for post in candidate_posts:
            distance = self._calculate_distance(
                user_lat, user_lng, 
                post.location.latitude, post.location.longitude
            )
            if distance <= radius_km:
                post.distance_km = distance
                nearby_posts.append(post)
        
        return nearby_posts
    
    def _get_fallback_posts(self, user, user_lat, user_lng, needed_count, date_filter=None):
        """Get fallback posts when not enough nearby posts are found"""
        if needed_count <= 0:
            return []
        
        # Strategy 1: Expand radius to find more posts
        expanded_posts = self._get_nearby_posts(user_lat, user_lng, 100, date_filter)  # 100km radius
        if len(expanded_posts) >= needed_count:
            return expanded_posts[:needed_count]
        
        # Strategy 2: Get trending/popular posts regardless of location
        trending_query = Post.objects.select_related(
            'location', 'author'
        ).prefetch_related('votes')
        
        # Apply date filter if provided
        if date_filter:
            try:
                from datetime import datetime
                filter_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
                trending_query = trending_query.filter(created_at__date=filter_date)
            except ValueError:
                pass
        else:
            # Last 3 days for trending content
            trending_query = trending_query.filter(
                created_at__gte=timezone.now() - timedelta(days=3)
            )
        
        trending_posts = list(trending_query.order_by('-upvotes', '-created_at')[:needed_count * 2])
        
        # Filter for posts with positive vote scores using the property
        filtered_trending = [post for post in trending_posts if post.vote_score >= 1][:needed_count]
        
        # Add distance calculation for these posts too
        for post in filtered_trending:
            post.distance_km = self._calculate_distance(
                user_lat, user_lng,
                post.location.latitude, post.location.longitude
            )
        
        # Combine and remove duplicates based on post ID
        expanded_ids = set(post.id for post in expanded_posts)
        unique_trending = [post for post in filtered_trending if post.id not in expanded_ids]
        
        # Limit to needed count
        all_fallback_posts = expanded_posts + unique_trending
        return all_fallback_posts[:needed_count]
    
    def _calculate_distance(self, lat1, lng1, lat2, lng2):
        """Calculate distance between two points using Haversine formula"""        
        # Convert to radians
        lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
        c = 2 * math.asin(math.sqrt(a))
        r = 6371  # Radius of earth in kilometers
        
        return c * r
    
    def _calculate_smart_recommendation_scores(self, posts, user_preferences, user, user_lat, user_lng):
        """Calculate sophisticated recommendation scores based on multiple factors with enhanced weighting"""
        scored_posts = []
        
        # Get max preference weight for normalization
        max_pref_weight = max(user_preferences.values()) if user_preferences else 1
        
        # Get user's voting history for personalization
        user_voted_posts = set(PostVote.objects.filter(user=user).values_list('post_id', flat=True))
        
        # Calculate engagement statistics for better normalization
        all_upvotes = [post.upvotes for post in posts if post.upvotes > 0]
        max_upvotes = max(all_upvotes) if all_upvotes else 1
        avg_upvotes = sum(all_upvotes) / len(all_upvotes) if all_upvotes else 0
        
        for post in posts:
            score = 0
            reasons = []
            
            # 1. ENHANCED Distance Score (30% weight) - Much stronger proximity factor
            max_distance = 50.0
            if post.distance_km <= 1.0:
                # Super close - almost guaranteed recommendation
                distance_score = 1.0
                reasons.append("right next to you")
            elif post.distance_km <= 5.0:
                # Very close - exponential scoring for close proximity
                distance_score = 0.9 + 0.1 * (5.0 - post.distance_km) / 4.0
                reasons.append("very close to you")
            elif post.distance_km <= 15.0:
                # Close - strong preference
                distance_score = 0.7 + 0.2 * (15.0 - post.distance_km) / 10.0
                reasons.append("nearby")
            elif post.distance_km <= 30.0:
                # Moderate distance
                distance_score = 0.4 + 0.3 * (30.0 - post.distance_km) / 15.0
                reasons.append("in your area")
            else:
                # Far - linear decay
                distance_score = max(0.1, (max_distance - post.distance_km) / max_distance)
                if distance_score > 0.2:
                    reasons.append("within range")
            
            score += distance_score * 0.30
            
            # 2. ENHANCED Engagement Score (25% weight) - Much stronger reaction factor
            engagement_score = 0
            if post.upvotes > 0 or post.downvotes > 0:
                # Calculate engagement ratio and popularity
                net_votes = post.upvotes - post.downvotes
                total_votes = post.upvotes + post.downvotes
                
                # Engagement quality (upvote ratio)
                engagement_ratio = post.upvotes / total_votes if total_votes > 0 else 0
                
                # Popularity factor (compared to other posts)
                popularity_factor = min(1.0, post.upvotes / max_upvotes) if max_upvotes > 0 else 0
                
                # Volume factor (more engagement = better)
                volume_factor = min(1.0, total_votes / 10.0)  # Normalize around 10 votes
                
                # Combine factors with different weights
                engagement_score = (
                    engagement_ratio * 0.4 +      # 40% for quality (upvote ratio)
                    popularity_factor * 0.4 +     # 40% for popularity (vs other posts)
                    volume_factor * 0.2           # 20% for engagement volume
                )
                
                # Add engagement reasons
                if post.upvotes >= 10:
                    reasons.append("very popular")
                elif post.upvotes >= 5:
                    reasons.append("highly rated")
                elif post.upvotes >= 2:
                    reasons.append("community approved")
                
                if engagement_ratio >= 0.8 and total_votes >= 3:
                    reasons.append("highly positive")
            
            score += engagement_score * 0.25
            
            # 3. ENHANCED Recency Score (20% weight) - Better time decay
            hours_old = (timezone.now() - post.created_at).total_seconds() / 3600
            
            if hours_old <= 1:
                # Brand new - maximum recency
                recency_score = 1.0
                reasons.append("just posted")
            elif hours_old <= 6:
                # Very fresh - exponential decay
                recency_score = 0.9 + 0.1 * (6 - hours_old) / 5
                reasons.append("breaking news")
            elif hours_old <= 24:
                # Fresh - strong preference
                recency_score = 0.7 + 0.2 * (24 - hours_old) / 18
                reasons.append("recent update")
            elif hours_old <= 72:
                # Recent - moderate preference
                recency_score = 0.4 + 0.3 * (72 - hours_old) / 48
                reasons.append("this week")
            elif hours_old <= 168:
                # Week old - linear decay
                recency_score = 0.1 + 0.3 * (168 - hours_old) / 96
            else:
                # Old content - minimal score
                recency_score = 0.05
            
            score += recency_score * 0.20
            
            # 4. ENHANCED User Preference Score (20% weight) - Boosted with recent filter emphasis
            category_weight = user_preferences.get(post.category, 0)
            category_score = category_weight / max_pref_weight if max_pref_weight > 0 else 0.3
            
            # Check for recent category filter interactions for extra boost
            recent_filter_boost = self._get_recent_filter_boost(user, post.category)
            if recent_filter_boost > 0:
                category_score *= (1 + recent_filter_boost)
                if recent_filter_boost >= 2.0:
                    reasons.append(f"recently filtered {post.category}")
                elif recent_filter_boost >= 1.0:
                    reasons.append(f"matches recent {post.category} interest")
            
            score += category_score * 0.20  # Increased from 0.15 to 0.20
            
            if category_score > 0.8:
                reasons.append(f"perfect {post.category} match")
            elif category_score > 0.6:
                reasons.append(f"matches your {post.category} interests")
            elif category_score > 0.3:
                reasons.append(f"{post.category} content")
            
            # 5. ENHANCED Content Quality & Context Bonuses (10% weight)
            quality_bonus = 0
            
            # Live events get massive boost
            if post.status == 'happening':
                quality_bonus += 0.8
                reasons.append("LIVE EVENT")
            
            # Media content bonus
            if post.has_media:
                quality_bonus += 0.3
                reasons.append("has media")
            
            # Verified authors bonus
            if hasattr(post.author, 'is_verified') and post.author.is_verified:
                quality_bonus += 0.4
                reasons.append("verified source")
            
            # Alert/News categories get urgency bonus
            if post.category in ['alert', 'news', 'emergency']:
                quality_bonus += 0.3
                reasons.append("important update")
            
            # Fresh content from new users gets discovery bonus
            if post.id not in user_voted_posts:
                quality_bonus += 0.1
            
            # Long content bonus (more substantial posts)
            if len(post.content) > 200:
                quality_bonus += 0.1
                
            score += min(1.0, quality_bonus) * 0.10
            
            # 6. BONUS: Trending Factor - Posts gaining momentum
            if hasattr(post, 'recent_votes_count'):
                recent_engagement = getattr(post, 'recent_votes_count', 0)
                if recent_engagement > 0:
                    trending_bonus = min(0.1, recent_engagement / 5.0)
                    score += trending_bonus
                    if trending_bonus > 0.05:
                        reasons.append("trending")
            
            # Final score calculation with emphasis on key factors
            # Apply distance boost for very close posts
            if post.distance_km <= 5.0:
                score *= 1.2  # 20% boost for very close posts
            
            # Apply engagement boost for highly engaged posts
            if post.upvotes >= 5:
                score *= 1.15  # 15% boost for popular posts
            
            # Apply recency boost for very fresh posts
            if hours_old <= 6:
                score *= 1.1  # 10% boost for very fresh posts
            
            # Store enhanced score and reasons
            post.recommendation_score = min(1.0, score)  # Cap at 1.0
            post.recommendation_reason = "; ".join(reasons[:3]) if reasons else "local content"
            scored_posts.append(post)
            
            # Debug logging for top posts
            if score > 0.7:
                print(f"🎯 HIGH SCORE POST: '{post.title[:50]}' - Score: {score:.3f}, Distance: {post.distance_km:.1f}km, "
                      f"Upvotes: {post.upvotes}, Hours old: {hours_old:.1f}, Reasons: {post.recommendation_reason}")
        
        # Sort by score descending
        return sorted(scored_posts, key=lambda p: p.recommendation_score, reverse=True)
    
    def _get_recent_filter_boost(self, user, category):
        """Get boost multiplier based on recent category filter interactions"""
        now = timezone.now()
        
        # Look for recent filter interactions for this specific category
        recent_filters = CategoryInteraction.objects.filter(
            user=user,
            category=category,
            interaction_type='filter',
            last_updated__gte=now - timedelta(hours=24)  # Last 24 hours
        ).order_by('-last_updated').first()
        
        if not recent_filters:
            return 0
        
        # Calculate boost based on how recent the filter interaction was
        hours_since_filter = (now - recent_filters.last_updated).total_seconds() / 3600
        
        if hours_since_filter < 1:
            # Filtered within last hour - massive boost
            return 4.0
        elif hours_since_filter < 3:
            # Filtered within last 3 hours - big boost
            return 3.0
        elif hours_since_filter < 6:
            # Filtered within last 6 hours - significant boost
            return 2.0
        elif hours_since_filter < 12:
            # Filtered within last 12 hours - moderate boost
            return 1.5
        elif hours_since_filter < 24:
            # Filtered within last day - small boost
            return 1.0
        else:
            return 0
    
    def _ensure_smart_content_diversity(self, posts, user_preferences, user_has_preferences):
        """Ensure intelligent content diversity based on user behavior"""
        if not posts:
            return posts
        
        if not user_has_preferences:
            # New user: show variety with slight preference for popular categories
            popular_categories = ['news', 'event', 'alert', 'community']
            return self._distribute_posts_by_categories(posts, popular_categories, equal_distribution=True)
        
        # Experienced user: apply sophisticated mixing
        # Get user's top 2 categories
        sorted_prefs = sorted(user_preferences.items(), key=lambda x: x[1], reverse=True)
        top_categories = [cat for cat, weight in sorted_prefs[:2]]
        
        # Categorize posts
        high_pref_posts = [p for p in posts if p.category in top_categories]
        medium_pref_posts = [p for p in posts if p.category not in top_categories and 
                           user_preferences.get(p.category, 0) > 0]
        discovery_posts = [p for p in posts if user_preferences.get(p.category, 0) == 0]
        
        diversified = []
        total_limit = len(posts)
        
        # Distribution strategy: 50% preferred, 30% medium, 20% discovery
        max_high_pref = int(total_limit * 0.5)
        max_medium_pref = int(total_limit * 0.3)
        max_discovery = total_limit - max_high_pref - max_medium_pref
        
        # Add posts with intelligent mixing
        high_idx = medium_idx = discovery_idx = 0
        
        for i in range(total_limit):
            added = False
            
            # Every 5th post should be discovery (if available)
            if (i % 5 == 4 and discovery_idx < len(discovery_posts) and 
                len([p for p in diversified if p.category not in top_categories and 
                    user_preferences.get(p.category, 0) == 0]) < max_discovery):
                diversified.append(discovery_posts[discovery_idx])
                discovery_idx += 1
                added = True
            
            # Every 3rd post should be medium preference (if available)
            elif (i % 3 == 2 and medium_idx < len(medium_pref_posts) and 
                  len([p for p in diversified if p.category not in top_categories and 
                      user_preferences.get(p.category, 0) > 0]) < max_medium_pref):
                diversified.append(medium_pref_posts[medium_idx])
                medium_idx += 1
                added = True
            
            # Otherwise, add high preference posts
            elif (high_idx < len(high_pref_posts) and 
                  len([p for p in diversified if p.category in top_categories]) < max_high_pref):
                diversified.append(high_pref_posts[high_idx])
                high_idx += 1
                added = True
            
            # Fallback: add any remaining posts
            if not added:
                remaining_posts = (high_pref_posts[high_idx:] + 
                                 medium_pref_posts[medium_idx:] + 
                                 discovery_posts[discovery_idx:])
                if remaining_posts:
                    diversified.append(remaining_posts[0])
                    if remaining_posts[0] in high_pref_posts[high_idx:]:
                        high_idx = high_pref_posts.index(remaining_posts[0]) + 1
                    elif remaining_posts[0] in medium_pref_posts[medium_idx:]:
                        medium_idx = medium_pref_posts.index(remaining_posts[0]) + 1
                    else:
                        discovery_idx = discovery_posts.index(remaining_posts[0]) + 1
                else:
                    break
        
        print(f"🎯 DIVERSITY - High pref: {len([p for p in diversified if p.category in top_categories])}, "
              f"Medium: {len([p for p in diversified if p.category not in top_categories and user_preferences.get(p.category, 0) > 0])}, "
              f"Discovery: {len([p for p in diversified if user_preferences.get(p.category, 0) == 0])}")
        
        return diversified
    
    def _distribute_posts_by_categories(self, posts, preferred_categories, equal_distribution=False):
        """Helper to distribute posts across categories"""
        if equal_distribution:
            # For new users, show variety
            posts_by_category = {}
            for post in posts:
                if post.category not in posts_by_category:
                    posts_by_category[post.category] = []
                posts_by_category[post.category].append(post)
            
            # Round-robin through categories
            distributed = []
            max_per_category = max(1, len(posts) // len(posts_by_category))
            category_indices = {cat: 0 for cat in posts_by_category}
            
            for i in range(len(posts)):
                for category in preferred_categories + list(posts_by_category.keys()):
                    if (category in posts_by_category and 
                        category_indices[category] < len(posts_by_category[category]) and
                        len([p for p in distributed if p.category == category]) < max_per_category):
                        distributed.append(posts_by_category[category][category_indices[category]])
                        category_indices[category] += 1
                        break
                else:
                    # Fallback: add any remaining posts
                    remaining = [p for p in posts if p not in distributed]
                    if remaining:
                        distributed.append(remaining[0])
                    else:
                        break
            
            return distributed
        
        return posts
    
    def _check_and_update_event_status(self, queryset):
        """
        Helper method to check and update event status for posts that should be auto-ended
        based on time (24+ hours old)
        """
        from django.utils import timezone
        from datetime import timedelta
        from .models import PostStatus
        
        # Exit early if we know from the request that we've already checked this
        # This prevents multiple checks in the same request
        if hasattr(self.request, '_event_status_checked'):
            return 0
            
        # First, get a count of happening posts to see if we need to do any work
        happening_posts_count = queryset.filter(status=PostStatus.HAPPENING).values('id').count()
        if happening_posts_count == 0:
            # Mark that we've checked this request
            self.request._event_status_checked = True
            return 0
            
        # Get posts that are still marked as happening but are older than 24 hours
        time_threshold = timezone.now() - timedelta(hours=24)
        
        # Use values_list to only fetch the ids for better performance
        old_happening_post_ids = queryset.filter(
            status=PostStatus.HAPPENING,
            created_at__lt=time_threshold
        ).values_list('id', flat=True)
        
        # Only update if there are posts to update
        if not old_happening_post_ids:
            # Mark that we've checked this request
            self.request._event_status_checked = True
            return 0
            
        # Batch update all old posts to ended status using a more efficient query
        updated_count = Post.objects.filter(id__in=old_happening_post_ids).update(
            status=PostStatus.ENDED
        )
        
        if updated_count > 0:
            print(f"🕐 AUTO-END DEBUG - Automatically marked {updated_count} events as ended (24+ hours old)")
        
        # Mark that we've checked this request
        self.request._event_status_checked = True
        return updated_count
