#!/usr/bin/env python
"""
Test script to verify post combination validation works correctly.
This script tests that posts with different dates or categories cannot be combined.
"""

import os
import django
import sys
from datetime import datetime, timedelta
from django.utils import timezone

# Add the server directory to the Python path
sys.path.append('/Users/momen_mac/Desktop/flutter_application/server')

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

from django.contrib.auth import get_user_model
from posts.models import Post, PostCoordinates
from posts.serializers import PostSerializer

User = get_user_model()

def test_post_combination_validation():
    """Test that post combination respects date and category constraints"""
    
    print("🧪 Testing Post Combination Validation")
    print("=" * 50)
    
    # Get or create a test user
    try:
        user = User.objects.get(email='test@example.com')
    except User.DoesNotExist:
        user = User.objects.create_user(
            email='test@example.com',
            password='testpass123',
            first_name='Test',
            last_name='User'
        )
    
    # Create a test location
    location = PostCoordinates.objects.create(
        latitude=31.5017,  # Jerusalem coordinates
        longitude=35.2137,
        address='Test Location, Jerusalem'
    )
    
    # Test 1: Create a main post with "event" category
    print("\n1️⃣ Creating main post with 'event' category...")
    main_post = Post.objects.create(
        title="Test Event in Jerusalem",
        content="This is a test event happening in Jerusalem",
        category="event",
        author=user,
        location=location,
        created_at=timezone.now() - timedelta(hours=2)  # 2 hours old
    )
    print(f"✅ Created main post: ID {main_post.id}, category: {main_post.category}")
    
    # Test 2: Try to create a related post with SAME category and RECENT date (should combine)
    print("\n2️⃣ Testing post with SAME category and RECENT date (should combine)...")
    
    class MockRequest:
        def __init__(self, user):
            self.user = user
    
    serializer = PostSerializer(context={'request': MockRequest(user)})
    
    new_post_same_category = Post(
        title="Another Event in Jerusalem",
        content="This is another event happening in the same area",
        category="event",  # Same category
        author=user,
        location=location,
        created_at=timezone.now()  # Recent
    )
    
    similar_post = serializer.find_similar_post(new_post_same_category)
    if similar_post:
        print(f"✅ Found similar post to combine with: ID {similar_post.id}")
    else:
        print("❌ No similar post found (unexpected)")
    
    # Test 3: Try to create a post with DIFFERENT category (should NOT combine)
    print("\n3️⃣ Testing post with DIFFERENT category (should NOT combine)...")
    
    new_post_diff_category = Post(
        title="Traffic Update in Jerusalem",
        content="This is a traffic update happening in the same area",
        category="traffic",  # Different category
        author=user,
        location=location,
        created_at=timezone.now()  # Recent
    )
    
    similar_post = serializer.find_similar_post(new_post_diff_category)
    if similar_post:
        print(f"❌ Found similar post (unexpected): ID {similar_post.id}")
    else:
        print("✅ No similar post found (expected - different category)")
    
    # Test 4: Try to create a post with OLD date (should NOT combine)
    print("\n4️⃣ Testing post with OLD date (should NOT combine)...")
    
    new_post_old_date = Post(
        title="Old Event in Jerusalem",
        content="This is an old event that happened in Jerusalem",
        category="event",  # Same category
        author=user,
        location=location,
        created_at=timezone.now() - timedelta(hours=25)  # 25 hours old (older than 24h limit)
    )
    
    similar_post = serializer.find_similar_post(new_post_old_date)
    if similar_post:
        print(f"❌ Found similar post (unexpected): ID {similar_post.id}")
    else:
        print("✅ No similar post found (expected - post too old)")
    
    print("\n" + "=" * 50)
    print("🧪 Test completed!")
    
    # Clean up test data
    print("\n🧹 Cleaning up test data...")
    Post.objects.filter(author=user).delete()
    PostCoordinates.objects.filter(id=location.id).delete()
    print("✅ Test data cleaned up")

if __name__ == "__main__":
    test_post_combination_validation()
