from django.shortcuts import render
from django.db.models import Q, Count
from django.contrib.postgres.search import SearchVector
from django.http import JsonResponse
from rest_framework import viewsets, status, permissions, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import datetime, timedelta
import math  # Adding missing math import
from .models import Post, PostVote, EventStatusVote
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
