#!/usr/bin/env python
# Script to find user info by username in Django

import os
import sys
import django

# Set up Django environment
sys.path.append('/Users/momen_mac/Desktop/flutter_application/server')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Import models after Django setup
from accounts.models import Account

def find_user_by_username(username):
    """Find user info by username (case insensitive)"""
    try:
        # Try exact match first
        user = Account.objects.filter(username__iexact=username).first()
        
        # If not found, try contains match
        if not user:
            users = Account.objects.filter(username__icontains=username)
            if users.exists():
                user = users.first()
            else:
                # Try matching on first_name
                users = Account.objects.filter(first_name__iexact=username)
                if users.exists():
                    user = users.first()
                else:
                    print(f"No user found with username containing '{username}'")
                    return None
        
        # User found, print details
        print("\n=== USER FOUND ===")
        print(f"ID: {user.id}")
        print(f"Username: {user.username}")
        print(f"Name: {user.first_name} {user.last_name}")
        print(f"Email: {user.email}")
        print(f"Profile Picture: {user.profile_picture}")
        
        if user.profile_picture:
            print(f"Profile URL: {user.profile_picture.url}")
            print(f"Profile Path: {user.profile_picture.path}")
        else:
            print("No profile picture set")
            
        return user
    except Exception as e:
        print(f"Error finding user: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) > 1:
        username = sys.argv[1]
        find_user_by_username(username)
    else:
        print("Usage: python find_user.py <username>")
