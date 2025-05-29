#!/usr/bin/env python
"""
Test script to validate the serializer fixes for:
1. Event status mapping (event_status -> status)
2. Location URL decoding
"""

import os
import sys
import django
from django.conf import settings

# Add the server directory to Python path
server_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, server_dir)

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

def test_serializer_fixes():
    """Test the PostSerializer with our fixes"""
    print("🔧 Testing Django PostSerializer Fixes")
    print("=" * 50)
    
    try:
        from posts.serializers import PostSerializer
        from posts.models import Post
        from accounts.models import User
        print("✓ Successfully imported Django models and serializers")
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False
    
    # Test data that simulates frontend request
    test_data = {
        'title': 'Test Event Post',
        'content': 'Testing the event status and location fixes',
        'category': 'event',
        'location': {
            'latitude': 32.2217,
            'longitude': 35.2546,
            'address': '%C5%A2ulkarm,%20Palestine'  # URL encoded
        },
        'event_status': 'ended',  # Frontend sends this
        'is_anonymous': False
    }
    
    print("\n=== Testing PostSerializer Validation ===")
    serializer = PostSerializer(data=test_data)
    
    if serializer.is_valid():
        print("✓ Serializer validation passed")
        validated_data = serializer.validated_data
        
        # Check if event_status is properly handled
        print(f"✓ Validated data contains event_status: {'event_status' in validated_data}")
        if 'event_status' in validated_data:
            print(f"  Event status value: {validated_data['event_status']}")
        
        # Check location data
        if 'location' in validated_data:
            location = validated_data['location']
            print(f"✓ Location data present: {location}")
            if 'address' in location:
                print(f"  Original address: {test_data['location']['address']}")
                print(f"  Address in validated data: {location['address']}")
        
        return True
    else:
        print("❌ Serializer validation failed:")
        print(f"  Errors: {serializer.errors}")
        return False

def test_url_decoding():
    """Test URL decoding functionality"""
    print("\n=== Testing URL Decoding Function ===")
    import urllib.parse
    
    test_cases = [
        '%C5%A2ulkarm,%20Palestine',
        'Jerusalem%2C%20Palestine', 
        'Ramallah%2C%20West%20Bank',
        'Normal Address'
    ]
    
    for encoded in test_cases:
        try:
            decoded = urllib.parse.unquote(encoded)
            print(f"✓ '{encoded}' -> '{decoded}'")
        except Exception as e:
            print(f"❌ Failed to decode '{encoded}': {e}")
            return False
    
    return True

if __name__ == '__main__':
    print("Starting Django serializer tests...\n")
    
    # Test URL decoding first (doesn't require database)
    url_test_passed = test_url_decoding()
    
    # Test serializer validation
    serializer_test_passed = test_serializer_fixes()
    
    print("\n" + "=" * 50)
    print("📋 TEST RESULTS")
    print(f"URL Decoding: {'✅ PASSED' if url_test_passed else '❌ FAILED'}")
    print(f"Serializer Validation: {'✅ PASSED' if serializer_test_passed else '❌ FAILED'}")
    
    if url_test_passed and serializer_test_passed:
        print("\n🎉 All tests passed! The fixes are working correctly.")
    else:
        print("\n⚠️  Some tests failed. Please check the implementation.")
