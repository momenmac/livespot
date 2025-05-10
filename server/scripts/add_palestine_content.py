#!/usr/bin/env python
import os
import sys
import django
import random
import datetime
import pytz
from django.utils import timezone
from django.conf import settings
from pathlib import Path

# Add the project directory to the Python path
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(BASE_DIR))

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Now we can import models
from accounts.models import Account, UserProfile
from posts.models import Post, PostCategory, Thread

def log_message(message):
    print(f"[{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {message}")

def create_palestinian_content():
    log_message("Starting creation of Palestinian content")
    
    # Palestinian cities and locations
    palestinian_locations = [
        {"city": "Gaza City", "lat": 31.5017, "lon": 34.4668},
        {"city": "Khan Yunis", "lat": 31.3403, "lon": 34.3062},
        {"city": "Rafah", "lat": 31.2978, "lon": 34.2461},
        {"city": "Beit Lahia", "lat": 31.5500, "lon": 34.5000},
        {"city": "Jabalia", "lat": 31.5333, "lon": 34.4833},
        {"city": "Ramallah", "lat": 31.9073, "lon": 35.2085},
        {"city": "Hebron", "lat": 31.5326, "lon": 35.0998},
        {"city": "Nablus", "lat": 32.2211, "lon": 35.2544},
        {"city": "Bethlehem", "lat": 31.7054, "lon": 35.2024},
        {"city": "Jenin", "lat": 32.4597, "lon": 35.3026},
        {"city": "Jericho", "lat": 31.8580, "lon": 35.4635},
        {"city": "Tulkarm", "lat": 32.3104, "lon": 35.0287},
        {"city": "Qalqilya", "lat": 32.1900, "lon": 34.9700},
    ]
    
    # Palestinian news topics and content
    news_topics = [
        {"category": PostCategory.NEWS, "title": "New community center opens in {city}", 
         "content": "A new community center has opened in {city} offering services for local residents including education programs, recreation facilities, and meeting spaces for community events."},
        
        {"category": PostCategory.ALERT, "title": "Power outage reported in {city}", 
         "content": "Several neighborhoods in {city} are experiencing power outages. Crews are working to restore power as soon as possible. Stay updated for more information."},
        
        {"category": PostCategory.TRAFFIC, "title": "Traffic congestion on main road in {city}", 
         "content": "Heavy traffic has been reported on the main road into {city}. Drivers are advised to seek alternative routes and allow extra time for their journeys."},
        
        {"category": PostCategory.COMMUNITY, "title": "Community cleanup event this weekend in {city}", 
         "content": "Join us for a community cleanup event in {city} this weekend. Meet at the central square at 9 AM. Bring gloves and water. Together we can make our community cleaner!"},
        
        {"category": PostCategory.EVENT, "title": "Cultural festival coming to {city} next week", 
         "content": "A celebration of Palestinian culture will take place next week in {city}, featuring traditional music, dance, food, and crafts. Don't miss this opportunity to celebrate our heritage!"},
        
        {"category": PostCategory.WEATHER, "title": "Weather alert: Strong winds expected in {city}", 
         "content": "The meteorological department has issued a weather warning for {city}. Strong winds are expected over the next 24 hours. Please secure loose objects and exercise caution when outside."},
        
        {"category": PostCategory.NEWS, "title": "New healthcare clinic opening in {city}", 
         "content": "A new healthcare clinic will open its doors next month in {city}, providing essential medical services to the community. The clinic will offer general healthcare, pediatrics, and women's health services."},
        
        {"category": PostCategory.QUESTION, "title": "Is the weekly market in {city} open tomorrow?", 
         "content": "Does anyone know if the weekly market in {city} will be open tomorrow given the holiday? I need to buy some fresh produce."},
    ]
    
    # Create or get user accounts
    accounts = []
    usernames = ["palestine_updates", "local_news", "community_voice", "city_watch", "daily_updates"]
    
    log_message(f"Creating user accounts: {', '.join(usernames)}")
    
    for username in usernames:
        # Check if account already exists
        account, created = Account.objects.get_or_create(
            username=username,
            defaults={
                'email': f"{username}@example.com",
                'password': 'pbkdf2_sha256$600000$hashed_password_placeholder',
                'is_active': True,
            }
        )
        
        if created:
            # If we created a new account, also create a user profile
            UserProfile.objects.create(
                account=account,
                first_name=username.split('_')[0].capitalize(),
                last_name=username.split('_')[1].capitalize() if len(username.split('_')) > 1 else "User",
                bio=f"Sharing updates about Palestine and {username.replace('_', ' ')}",
                profile_picture=None,  # No profile picture for now
                is_verified=random.choice([True, False, False]),  # 1/3 chance of being verified
            )
            log_message(f"Created new account: {username}")
        else:
            log_message(f"Using existing account: {username}")
        
        accounts.append(account)
    
    # Create threads and posts
    thread_count = 0
    post_count = 0
    
    # Create some initial threads
    log_message("Creating threads and posts")
    
    # Create about 20 posts with realistic Palestinian content
    for _ in range(20):
        # Select random account
        account = random.choice(accounts)
        
        # Select random location
        location = random.choice(palestinian_locations)
        
        # Select random topic
        topic = random.choice(news_topics)
        
        # Format the title and content with the location
        title = topic["title"].format(city=location["city"])
        content = topic["content"].format(city=location["city"])
        
        # Create a thread about 30% of the time
        create_thread = random.random() < 0.3
        
        if create_thread:
            thread = Thread.objects.create(
                title=f"Thread: {title}",
                creator=account,
            )
            thread_count += 1
            log_message(f"Created thread: {thread.title}")
            
            # Create the initial post in the thread
            post = Post.objects.create(
                author=account,
                content=content,
                category=topic["category"],
                thread=thread,
                location_name=f"{location['city']}, Palestine",
                latitude=location["lat"],
                longitude=location["lon"],
                # Add some media URLs sometimes
                media_urls=["https://picsum.photos/seed/palestine{}/800/600".format(random.randint(1, 100))] if random.random() < 0.7 else [],
                is_anonymous=random.random() < 0.1,  # 10% chance of anonymous posts
            )
            post_count += 1
            
            # Add some additional posts to the thread
            for _ in range(random.randint(0, 3)):
                reply_account = random.choice(accounts)
                reply_content = f"This is important information for residents of {location['city']}. Thank you for sharing."
                
                Post.objects.create(
                    author=reply_account,
                    content=reply_content,
                    category=topic["category"],
                    thread=thread,
                    location_name=f"{location['city']}, Palestine",
                    latitude=location["lat"],
                    longitude=location["lon"],
                    is_anonymous=random.random() < 0.1,  # 10% chance of anonymous posts
                )
                post_count += 1
        else:
            # Create standalone post
            post = Post.objects.create(
                author=account,
                content=content,
                category=topic["category"],
                thread=None,
                title=title,
                location_name=f"{location['city']}, Palestine",
                latitude=location["lat"],
                longitude=location["lon"],
                # Add some media URLs sometimes
                media_urls=["https://picsum.photos/seed/palestine{}/800/600".format(random.randint(1, 100))] if random.random() < 0.7 else [],
                is_anonymous=random.random() < 0.1,  # 10% chance of anonymous posts
            )
            post_count += 1
            log_message(f"Created post: {title}")
    
    log_message(f"Created {thread_count} threads and {post_count} posts with Palestinian content")

if __name__ == "__main__":
    log_message("Starting Palestinian content generation script")
    create_palestinian_content()
    log_message("Finished Palestinian content generation")