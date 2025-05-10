#!/usr/bin/env python
import os
import sys
import random
import datetime
import uuid
from decimal import Decimal
from pathlib import Path

# Add the project root to path so we can import Django modules
script_path = Path(__file__).resolve()
root_dir = script_path.parent.parent
sys.path.append(str(root_dir))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from accounts.models import Account, UserProfile
from posts.models import Post, Thread, PostCoordinates, PostCategory

# Palestinian cities and locations
PALESTINE_LOCATIONS = [
    {
        "name": "Gaza City",
        "latitude": 31.5016,
        "longitude": 34.4668,
        "address": "Gaza City, Gaza Strip, Palestine"
    },
    {
        "name": "Khan Yunis",
        "latitude": 31.3417,
        "longitude": 34.3063,
        "address": "Khan Yunis, Gaza Strip, Palestine"
    },
    {
        "name": "Rafah",
        "latitude": 31.2977,
        "longitude": 34.2400,
        "address": "Rafah, Gaza Strip, Palestine"
    },
    {
        "name": "Jabalia",
        "latitude": 31.5272,
        "longitude": 34.4800,
        "address": "Jabalia, Gaza Strip, Palestine"
    },
    {
        "name": "Ramallah",
        "latitude": 31.9038,
        "longitude": 35.2034,
        "address": "Ramallah, West Bank, Palestine"
    },
    {
        "name": "Hebron",
        "latitude": 31.5326,
        "longitude": 35.0998,
        "address": "Hebron, West Bank, Palestine"
    },
    {
        "name": "Nablus",
        "latitude": 32.2211,
        "longitude": 35.2544,
        "address": "Nablus, West Bank, Palestine"
    },
    {
        "name": "Bethlehem",
        "latitude": 31.7054,
        "longitude": 35.2024,
        "address": "Bethlehem, West Bank, Palestine"
    },
    {
        "name": "Jenin",
        "latitude": 32.4597,
        "longitude": 35.2963,
        "address": "Jenin, West Bank, Palestine"
    },
    {
        "name": "Jericho",
        "latitude": 31.8614,
        "longitude": 35.4635,
        "address": "Jericho, West Bank, Palestine"
    }
]

# Palestinian news categories and topics
NEWS_TOPICS = [
    {
        "category": PostCategory.NEWS,
        "topics": [
            "Local markets reopen in {location}",
            "New medical center inaugurated in {location}",
            "Educational initiatives launched in {location} schools",
            "Community meeting discusses infrastructure in {location}",
            "Cultural heritage preservation efforts in {location}"
        ]
    },
    {
        "category": PostCategory.ALERT,
        "topics": [
            "Water supply interruption in {location} area",
            "Power outage affecting {location} district",
            "Road closure on main street in {location}",
            "Temporary school closure in {location} due to maintenance",
            "Weather warning issued for {location} region"
        ]
    },
    {
        "category": PostCategory.COMMUNITY,
        "topics": [
            "Volunteer cleanup campaign in {location}",
            "Youth sports tournament starts in {location}",
            "Community garden project in {location} seeks volunteers",
            "Local artists showcase work in {location} exhibition",
            "Neighborhood council meeting scheduled in {location}"
        ]
    },
    {
        "category": PostCategory.TRAFFIC,
        "topics": [
            "Traffic congestion reported near {location} market",
            "Road maintenance work begins on {location} main street",
            "New traffic pattern implemented in {location} center",
            "Public transportation schedule change in {location}",
            "Bridge repair affecting traffic in {location} area"
        ]
    },
    {
        "category": PostCategory.EVENT,
        "topics": [
            "Annual cultural festival coming to {location}",
            "Book fair opens this weekend in {location}",
            "Food distribution event planned in {location}",
            "Children's activities day in {location} park",
            "Health awareness campaign visits {location}"
        ]
    }
]

# Content templates with real context about Palestine
CONTENT_TEMPLATES = [
    "Local residents in {location} are participating in this initiative to improve community resources. Many families have joined together to help with the project.",
    
    "The situation in {location} continues to develop, with community members working together to address local needs. Resources are being distributed to affected areas.",
    
    "Community leaders in {location} have announced plans for infrastructure improvements. The project aims to enhance services for local residents.",
    
    "Volunteers in {location} are organizing support networks to assist families in need. The community response has been encouraging.",
    
    "Health services in {location} are being expanded to meet increased demand. Medical supplies and personnel have been allocated to support the effort.",
    
    "Educational programs in {location} are adapting to current circumstances. Teachers and students are showing remarkable resilience in continuing learning activities.",
    
    "Agricultural initiatives in {location} are helping to maintain food security. Local farmers are working to increase production despite challenges.",
    
    "Cultural heritage preservation efforts in {location} continue despite difficulties. Community members are documenting and protecting historical sites.",
    
    "Water access improvements are underway in {location}. Technical teams are working to repair and enhance distribution systems for residents.",
    
    "Youth engagement programs in {location} are providing important recreational and educational opportunities. Local organizations are coordinating these essential activities."
]

# Tags relevant to Palestine
PALESTINE_TAGS = [
    "community", "support", "local", "resources", "health", "education",
    "infrastructure", "utilities", "transportation", "culture", "heritage",
    "agriculture", "water", "electricity", "youth", "family", "services",
    "development", "solidarity", "resilience", "cooperation", "neighborhood"
]

# Placeholder image URLs (replace these with appropriate images for your app)
IMAGE_URLS = [
    "https://picsum.photos/seed/palestine1/800/600",
    "https://picsum.photos/seed/palestine2/800/600",
    "https://picsum.photos/seed/palestine3/800/600",
    "https://picsum.photos/seed/palestine4/800/600",
    "https://picsum.photos/seed/palestine5/800/600"
]

def create_location(location_data):
    """Create a PostCoordinates object from location data"""
    location, created = PostCoordinates.objects.get_or_create(
        latitude=float(location_data["latitude"]),
        longitude=float(location_data["longitude"]),
        defaults={
            'address': location_data["address"]
        }
    )
    return location

def get_random_time_within_days(days=30):
    """Get a random datetime within the specified number of days"""
    now = datetime.datetime.now()
    random_days = random.randint(0, days)
    random_hours = random.randint(0, 23)
    random_minutes = random.randint(0, 59)
    return now - datetime.timedelta(days=random_days, hours=random_hours, minutes=random_minutes)

def create_post_content(topic, location_name):
    """Create realistic post content based on a topic and location"""
    # Replace placeholder with actual location name
    topic_text = topic.replace("{location}", location_name)
    
    # Choose a content template and replace placeholder
    content = random.choice(CONTENT_TEMPLATES).replace("{location}", location_name)
    
    # Add some additional context
    additional_context = [
        f"Residents in {location_name} are encouraged to participate.",
        f"Updates will be shared with the {location_name} community as they become available.",
        f"For more information, contact the {location_name} community center.",
        f"This initiative aims to support families in {location_name} during these challenging times."
    ]
    
    if random.random() > 0.5:
        content += " " + random.choice(additional_context)
    
    return topic_text, content

def create_palestine_data(num_posts=50, thread_probability=0.3):
    """Create mock data for Palestine with specified parameters"""
    print(f"Creating {num_posts} posts with Palestine data...")
    
    # Ensure we have users to assign posts to
    accounts = list(Account.objects.all())
    if not accounts:
        print("No accounts found. Please create some accounts first.")
        return
    
    # Get profiles for accounts
    profiles = []
    for account in accounts:
        try:
            profile = account.profile
            profiles.append(profile)
        except UserProfile.DoesNotExist:
            print(f"No profile found for account: {account.email}")
    
    if not profiles:
        print("No user profiles found. Please create some users with profiles first.")
        return
    
    # Track created threads to add posts to them
    created_threads = []
    
    for i in range(num_posts):
        # Select random user profile
        profile = random.choice(profiles)
        
        # Select random location
        location_data = random.choice(PALESTINE_LOCATIONS)
        location = create_location(location_data)
        
        # Select random category and topic
        category_data = random.choice(NEWS_TOPICS)
        category_name = category_data["category"]
        topic = random.choice(category_data["topics"])
        
        # Create content
        title, content = create_post_content(topic, location_data["name"])
        
        # Select random tags (2-5)
        num_tags = random.randint(2, 5)
        selected_tags = random.sample(PALESTINE_TAGS, num_tags)
        
        # Determine if part of thread or new thread
        is_part_of_existing_thread = False
        thread = None
        
        if created_threads and random.random() < thread_probability:
            # Use existing thread with matching category or location sometimes
            matching_threads = [
                t for t in created_threads 
                if t.category == category_name or 
                (t.location.latitude == location.latitude and 
                 t.location.longitude == location.longitude)
            ]
            if matching_threads:
                thread = random.choice(matching_threads)
                is_part_of_existing_thread = True
        
        # Create media URLs for some posts
        media_urls = []
        if random.random() > 0.3:
            num_images = random.randint(1, 3)
            for j in range(num_images):
                media_urls.append(random.choice(IMAGE_URLS))
        
        # Create post
        post = Post.objects.create(
            author=profile.user,  # Assuming the author field points to Account, not UserProfile
            title=title,
            content=content,
            category=category_name,
            location=location,
            media_urls=media_urls,
            created_at=get_random_time_within_days(),
            honesty_score=random.randint(60, 100),
            upvotes=random.randint(0, 100),
            downvotes=random.randint(0, 20),
            is_verified_location=random.random() > 0.7,
            taken_within_app=random.random() > 0.5,
            tags=selected_tags,
        )
        
        # Handle thread creation/assignment
        if not is_part_of_existing_thread:
            # Create a new thread sometimes
            if random.random() < 0.4:
                thread = Thread.objects.create(
                    title=f"Discussion: {title}",
                    category=category_name,
                    location=location,
                    created_at=post.created_at,
                    updated_at=post.created_at,
                    honesty_score=post.honesty_score,
                    tags=selected_tags
                )
                created_threads.append(thread)
        
        if thread:
            post.thread = thread
            post.save()
            
            # Update thread updated_at time
            if post.created_at > thread.updated_at:
                thread.updated_at = post.created_at
                thread.save()
        
        print(f"Created post {i+1}/{num_posts}: {title}")
    
    print(f"Created {len(created_threads)} threads")
    print("Palestine data generation completed successfully!")

if __name__ == "__main__":
    # Get number of posts from command line argument or use default
    num_posts = 50
    if len(sys.argv) > 1:
        try:
            num_posts = int(sys.argv[1])
        except ValueError:
            print("Invalid number of posts. Using default of 50.")
    
    create_palestine_data(num_posts)