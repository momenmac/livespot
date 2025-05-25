from django.shortcuts import render
from django.db.models import Q, Count
from django.contrib.postgres.search import SearchVector
from rest_framework import viewsets, status, permissions, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import datetime, timedelta
import math  # Adding missing math import
from .models import Post, PostVote
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
    
    def perform_create(self, serializer):
        serializer.save()
    
    def get_queryset(self):
        """
        Get the list of posts based on various filter criteria.
        By default, return only main posts (where related_post is null).
        """
        queryset = Post.objects.all().order_by('-created_at')
        
        # Annotate with related posts count (sons count for fathers)
        from django.db.models import Case, When, IntegerField
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
                filter_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                
                # Create datetime objects for the start and end of the day
                start_datetime = datetime.combine(filter_date, datetime.min.time())
                end_datetime = datetime.combine(filter_date, datetime.max.time())
                
                # Apply timezone awareness if using timezone-aware datetimes in Django
                if timezone.is_aware(queryset.first().created_at if queryset.exists() else timezone.now()):
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
                    )
                else:
                    # This is a related post, get the main post and all related posts
                    queryset = Post.objects.filter(
                        Q(id=main_post.related_post.id) | Q(related_post_id=main_post.related_post.id)
                    )
            except (ValueError, Post.DoesNotExist):
                pass
                
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
                    'comments': 0,  # Thread functionality removed
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
    
    @action(detail=True, methods=['get'])
    def related(self, request, pk=None):
        """Get all posts related to this post"""
        try:
            print(f"DEBUG: Related endpoint called with pk={pk}")
            print(f"DEBUG: Full URL path: {request.path}")
            
            # Use base queryset to avoid filtering issues
            post = Post.objects.get(pk=pk)
            print(f"DEBUG: Getting related posts for post {pk}")
            print(f"DEBUG: Post {pk} related_post field: {post.related_post}")
            print(f"DEBUG: Post {pk} is_main_post: {post.is_main_post}")
            
            # If this is a main post (father), get all its related posts (sons)
            if post.related_post is None:
                related_posts = Post.objects.filter(related_post=post)
                print(f"DEBUG: This is a main post, found {related_posts.count()} related posts")
            else:
                # This is a related post (son), get all other posts related to the same main post
                main_post = post.related_post
                related_posts = Post.objects.filter(
                    Q(related_post=main_post) | Q(id=main_post.id)
                ).exclude(id=post.id)
                print(f"DEBUG: This is a related post, found {related_posts.count()} related posts")
            
            # Ensure proper UTF-8 encoding for Arabic content
            serializer = self.get_serializer(related_posts, many=True)
            response_data = serializer.data
            
            # Debug Arabic content
            for item in response_data:
                if item.get('title'):
                    print(f"DEBUG: Title: {item['title']} (type: {type(item['title'])})")
                if item.get('content'):
                    print(f"DEBUG: Content: {item['content']} (type: {type(item['content'])})")
            
            print(f"DEBUG: Serialized {len(response_data)} posts for response")
            
            # Ensure the response is properly encoded for Arabic
            from django.http import JsonResponse
            import json
            
            # Return JsonResponse with ensure_ascii=False to properly handle Arabic
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
