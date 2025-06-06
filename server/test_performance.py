#!/usr/bin/env python
"""
Script to test performance of the API endpoints for posts.
This will help verify the optimizations made to the serializer and views.
"""

import os
import django
import time
import statistics
import requests
import json
from datetime import datetime

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Import models after Django setup
from django.contrib.auth import get_user_model
from posts.models import Post
from posts.serializers import PostSerializer
from accounts.models import UserProfile
from rest_framework.test import APIClient
from django.test.client import RequestFactory
from django.contrib.auth.models import AnonymousUser

User = get_user_model()

def measure_execution_time(func, *args, **kwargs):
    """Measure execution time of a function"""
    start_time = time.time()
    result = func(*args, **kwargs)
    end_time = time.time()
    return result, end_time - start_time

def test_serializer_performance():
    """Test the performance of the PostSerializer with get_is_saved method"""
    print("\n=== Testing PostSerializer Performance ===")
    
    # Get a user with saved posts
    try:
        user = User.objects.first()
        if not user:
            print("No users found in the database.")
            return
        
        # Get user profile
        profile = UserProfile.objects.get(user=user)
        
        # Get some posts (limit to 50 for testing)
        posts = Post.objects.all()[:50]
        if not posts:
            print("No posts found in the database.")
            return
            
        print(f"Testing with {len(posts)} posts")
        
        # Save some posts for testing
        saved_posts_count = min(10, len(posts))
        for post in posts[:saved_posts_count]:
            profile.saved_posts.add(post)
        
        print(f"User has {saved_posts_count} saved posts")
        
        # Create a request object
        factory = RequestFactory()
        request = factory.get('/')
        request.user = user
        
        # Test serializer without caching
        times_without_cache = []
        for _ in range(3):  # Run multiple times to get an average
            request._cached_saved_post_ids = None  # Clear any cached data
            if hasattr(request, '_cached_saved_post_ids'):
                delattr(request, '_cached_saved_post_ids')
                
            start_time = time.time()
            serializer = PostSerializer(posts, many=True, context={'request': request})
            data = serializer.data  # Force serialization
            end_time = time.time()
            
            times_without_cache.append(end_time - start_time)
        
        avg_time_without_cache = statistics.mean(times_without_cache)
        print(f"Average serialization time without cache: {avg_time_without_cache:.6f} seconds")
        
        # Test serializer with caching
        # Pre-populate the cache
        request._cached_saved_post_ids = set(profile.saved_posts.values_list('id', flat=True))
        
        times_with_cache = []
        for _ in range(3):  # Run multiple times to get an average
            start_time = time.time()
            serializer = PostSerializer(posts, many=True, context={'request': request})
            data = serializer.data  # Force serialization
            end_time = time.time()
            
            times_with_cache.append(end_time - start_time)
        
        avg_time_with_cache = statistics.mean(times_with_cache)
        print(f"Average serialization time with cache: {avg_time_with_cache:.6f} seconds")
        
        improvement = (1 - avg_time_with_cache / avg_time_without_cache) * 100
        print(f"Performance improvement: {improvement:.2f}%")
        
    except Exception as e:
        print(f"Error testing serializer performance: {e}")

def test_api_endpoint_performance():
    """Test the performance of the API endpoints"""
    print("\n=== Testing API Endpoint Performance ===")
    
    # Get a user account for testing
    try:
        user = User.objects.first()
        if not user:
            print("No users found in the database.")
            return
            
        # Create API client and login
        client = APIClient()
        client.force_authenticate(user=user)
        
        # Test endpoints
        endpoints = [
            '/api/posts/',  # Main posts endpoint
            '/api/posts/nearby/?lat=31.5&lng=34.5&radius=10000',  # Nearby posts
            '/api/posts/saved/?user_id=' + str(user.id),  # Saved posts
            '/api/posts/upvoted/?user_id=' + str(user.id),  # Upvoted posts
            '/api/posts/following/',  # Following posts
        ]
        
        for endpoint in endpoints:
            times = []
            for _ in range(3):  # Run multiple times to get an average
                start_time = time.time()
                response = client.get(endpoint)
                end_time = time.time()
                
                times.append(end_time - start_time)
                
            avg_time = statistics.mean(times)
            print(f"Endpoint {endpoint}: Average response time: {avg_time:.6f} seconds")
            
    except Exception as e:
        print(f"Error testing API endpoint performance: {e}")

def main():
    """Main function to run all tests"""
    print(f"Starting performance tests at {datetime.now()}")
    
    test_serializer_performance()
    test_api_endpoint_performance()
    
    print(f"\nPerformance tests completed at {datetime.now()}")

if __name__ == "__main__":
    main()
