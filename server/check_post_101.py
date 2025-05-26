#!/usr/bin/env python
import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from posts.models import Post
from django.utils import timezone
from datetime import timedelta

# Get post 101
try:
    post = Post.objects.get(id=101)
    print(f'Post 101: {post.title}')
    print(f'Created: {post.created_at}')
    print(f'Current status: {post.status}')
    
    # Check age
    age = timezone.now() - post.created_at
    print(f'Age: {age.days} days, {age.seconds//3600} hours')
    
    # Check if it should be auto-ended (older than 24 hours)
    time_threshold = timezone.now() - timedelta(hours=24)
    should_end = post.created_at < time_threshold
    print(f'Should be auto-ended: {should_end}')
    
    # Update if needed
    if should_end and post.status == 'happening':
        post.status = 'ended'
        post.save()
        print('✅ Updated post 101 to ended status')
    else:
        print('Post already ended or not old enough')
        
except Post.DoesNotExist:
    print('Post 101 not found')
