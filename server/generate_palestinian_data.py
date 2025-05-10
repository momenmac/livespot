#!/usr/bin/env python
import os
import sys
import json
import random
import datetime
import logging
from django.utils import timezone

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

# Now we can import Django models
from posts.models import Post, PostCategory, Thread
from accounts.models import Account, UserProfile
from django.contrib.auth.models import User

# Configure logging
log_filename = f"palestinian_data_generation_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Palestinian cities with their approximate coordinates
PALESTINIAN_LOCATIONS = [
    {"name": "Gaza City", "latitude": 31.5017, "longitude": 34.4668, 
     "addresses": ["Omar Al-Mukhtar St", "Al-Wehda St", "Al-Remal", "Al-Shati Refugee Camp", "Al-Nasser"]},
    {"name": "Khan Younis", "latitude": 31.3546, "longitude": 34.3088,
     "addresses": ["Al-Balad", "Al-Mawasi", "Bani Suheila", "Abasan Al-Kabira", "Qarara"]},
    {"name": "Rafah", "latitude": 31.2935, "longitude": 34.2506,
     "addresses": ["Al-Salam", "Yibna Camp", "Brazil", "Al-Shaboura", "Tel Al-Sultan"]},
    {"name": "Jabalia", "latitude": 31.5272, "longitude": 34.4853,
     "addresses": ["Jabalia Camp", "Beit Lahia", "Beit Hanoun", "Al-Nazla", "Al-Fakhoura"]},
    {"name": "Deir Al-Balah", "latitude": 31.4202, "longitude": 34.3511,
     "addresses": ["Al-Nuseirat", "Al-Bureij", "Al-Maghazi", "Al-Zawaida", "Al-Musaddar"]},
    {"name": "Nablus", "latitude": 32.2211, "longitude": 35.2544,
     "addresses": ["Old City", "Rafidia", "Al-Makhfiya", "New Askar", "Balata Camp"]},
    {"name": "Hebron", "latitude": 31.5326, "longitude": 35.0998,
     "addresses": ["Old City", "Wadi Al-Hariya", "Ein Sara", "Halhul", "Al-Hawooz"]},
    {"name": "Ramallah", "latitude": 31.9039, "longitude": 35.2042, 
     "addresses": ["Al-Manara Square", "Al-Tireh", "Al-Masyoun", "Birzeit", "Al-Amari Camp"]},
    {"name": "Bethlehem", "latitude": 31.7054, "longitude": 35.2038,
     "addresses": ["Manger Square", "Al-Karkafa", "Beit Sahour", "Beit Jala", "Aida Camp"]},
    {"name": "Jenin", "latitude": 32.4650, "longitude": 35.2956,
     "addresses": ["Jenin Camp", "Al-Marah", "Wadi Burqin", "Al-Basatin", "Al-Zahrawy"]},
    {"name": "Tulkarm", "latitude": 32.3053, "longitude": 35.0283,
     "addresses": ["Tulkarm Camp", "Nur Shams", "Iktaba", "Dannaba", "Zeita"]},
    {"name": "Qalqilya", "latitude": 32.1896, "longitude": 34.9683,
     "addresses": ["City Center", "Eastern Quarter", "Kafr Saba", "Habla", "Azzun"]},
    {"name": "Jericho", "latitude": 31.8566, "longitude": 35.4542,
     "addresses": ["Ein al-Sultan", "Aqabat Jaber", "Al-Duyuk", "Al-Nuweima", "Al-Auja"]},
    {"name": "East Jerusalem", "latitude": 31.7834, "longitude": 35.2695,
     "addresses": ["Old City", "Sheikh Jarrah", "Silwan", "Wadi al-Joz", "Mount of Olives"]}
]

# Palestinian-specific post content
POST_TITLES = [
    "Olive harvest season begins in local village",
    "Traditional dabke performance at community center",
    "Local bakery introduces new za'atar bread",
    "Traffic alert: Road closures near Al-Manara Square",
    "Weather update: Strong winds expected tomorrow",
    "Weekly farmers market opens in city center",
    "Community cleanup initiative this weekend",
    "New art exhibition featuring local artists",
    "Cultural heritage festival announced for next month",
    "Emergency water distribution scheduled tomorrow",
    "Solar panel installation project begins in neighborhood",
    "Historical buildings restoration project update",
    "Internet service disruptions reported in eastern districts",
    "Local school wins national science competition",
    "Medical supplies donation drive at community center",
    "New public transportation routes announced",
    "Breaking: Power outages reported across multiple areas",
    "Food distribution program expanded to new areas",
    "Local craftspeople showcase traditional embroidery",
    "Evening curfew announcement for specific neighborhoods"
]

POST_CONTENTS = [
    "The annual olive harvest has begun in our village. Families are gathering to pick olives from trees that have been in their families for generations. The weather has been perfect this year, promising a good yield. Local olive presses are preparing for the busy season ahead. Anyone interested in volunteering to help elderly residents with their harvest should contact the community center.",
    
    "Our community's infrastructure needs urgent attention. Several water pipes have burst in the past week, leaving many households without regular water supply. Local authorities have promised repairs, but progress has been slow. We need to organize as a community to demand faster action.",
    
    "The children's education center is hosting free after-school programs this month. Activities include traditional music, storytelling, art, and homework assistance. The center is staffed by qualified teachers and volunteers. Registration is open to all children between ages 6-14.",
    
    "There's an urgent need for blood donors at the central hospital. All blood types are needed, but especially O-negative. The hospital has extended its donation hours from 8am to 8pm all week. Please bring identification if you plan to donate.",
    
    "Our neighborhood experienced power outages throughout the day. According to local authorities, this is due to maintenance work on the main electrical grid. Power is expected to be fully restored by evening. Please check on elderly neighbors during this time.",
    
    "A reminder that water distribution will take place tomorrow at the main square from 10am-2pm. Each family is entitled to 20 liters. Please bring your own containers and ID cards. Volunteers are needed to help with distribution.",
    
    "The historical preservation society is documenting old family recipes to preserve our culinary heritage. If you have traditional recipes passed down through generations, please consider sharing them. They will be compiled into a community cookbook.",
    
    "Our local farmers have reported a good citrus harvest this season. Fresh oranges, lemons, and grapefruits are now available at the community market at affordable prices. The market is open daily from 7am-1pm.",
    
    "Several roads in the eastern part of the city will be closed tomorrow for infrastructure repairs. Expect delays and plan alternative routes, especially during morning hours. The work is expected to continue for three days.",
    
    "The community health clinic is offering free vaccinations for children under 5 years old this Tuesday. No appointment is necessary, just bring your child's health records. Services will be available from 9am-4pm.",
    
    "The traditional crafts workshop is seeking apprentices interested in learning embroidery and pottery. This is part of efforts to preserve our cultural heritage and provide skills training to younger generations. Classes will be held twice weekly in the community center.",
    
    "There have been reports of water contamination in the western district. Residents are advised to boil water before consumption until further notice. Authorities are investigating the source of contamination.",
    
    "A community meeting will be held next Thursday to discuss the proposed renovation of the neighborhood playground. All residents are welcome to attend and share their input. The meeting starts at 6pm at the community hall.",
    
    "The local medical clinic is running low on essential medications. Anyone with unused, unexpired medications like antibiotics, blood pressure medication, or diabetes supplies is urged to donate them to the clinic.",
    
    "Our community farm project has produced its first harvest! Vegetables will be distributed to participating families this weekend. The project has successfully transformed unused land into productive gardens.",
    
    "Several families in our neighborhood are still without shelter after recent events. A temporary housing initiative has been set up at the community center. Donations of blankets, mattresses, and cooking supplies are urgently needed.",
    
    "The mobile solar charging station will be at the central square today from 10am-4pm. Residents can charge phones, laptops, and small devices for free. This service will be available every Monday and Thursday.",
    
    "Local fishermen report a good catch today. Fresh fish will be available at reduced prices at the harbor market this afternoon. This is a good opportunity to get nutritious food for your family.",
    
    "A reminder that the community kitchen serves hot meals daily from 12pm-2pm. Anyone in need is welcome. The kitchen also needs volunteers to help with food preparation and serving.",
    
    "The traditional music ensemble will perform tonight at the community center at 7pm. The performance will feature traditional instruments and folk songs. Entry is free and all are welcome."
]

# Palestinian-specific media URLs (these would be on your actual server)
MEDIA_URLS = [
    "https://yourserver.com/media/palestinian/olive_trees.jpg",
    "https://yourserver.com/media/palestinian/market_scene.jpg",
    "https://yourserver.com/media/palestinian/community_gathering.jpg",
    "https://yourserver.com/media/palestinian/traditional_food.jpg",
    "https://yourserver.com/media/palestinian/city_landscape.jpg",
    "https://yourserver.com/media/palestinian/cultural_event.jpg",
    "https://yourserver.com/media/palestinian/historical_building.jpg",
    "https://yourserver.com/media/palestinian/community_service.jpg",
    "https://yourserver.com/media/palestinian/traditional_craft.jpg",
    "https://yourserver.com/media/palestinian/local_market.jpg"
]

# Tags relevant to Palestinian content
TAGS = [
    "community", "tradition", "culture", "local", "support", 
    "heritage", "family", "agriculture", "infrastructure", "education",
    "health", "emergency", "services", "food", "water", 
    "electricity", "transportation", "history", "art", "music"
]

def get_random_location():
    """Get a random Palestinian location with slight coordinate variations"""
    location = random.choice(PALESTINIAN_LOCATIONS)
    # Add small random variations to coordinates for more realistic distribution
    lat_variation = random.uniform(-0.01, 0.01)
    long_variation = random.uniform(-0.01, 0.01)
    
    address = f"{random.choice(location['addresses'])}, {location['name']}, Palestine"
    
    return {
        "latitude": location["latitude"] + lat_variation,
        "longitude": location["longitude"] + long_variation,
        "address": address
    }

def get_random_tags(min_tags=1, max_tags=4):
    """Get a random selection of tags"""
    num_tags = random.randint(min_tags, max_tags)
    return random.sample(TAGS, num_tags)

def create_palestinian_posts(num_posts=50):
    """Create Palestinian-specific posts in the database"""
    logger.info(f"Starting Palestinian data generation, creating {num_posts} posts")
    
    # Get all user accounts - we'll assign posts to random existing users
    accounts = list(Account.objects.all())
    if not accounts:
        logger.error("No accounts found in the database. Please create some accounts first.")
        return
    
    # Get or create Palestinian post category
    categories = list(PostCategory.objects.all())
    
    posts_created = 0
    threads_created = 0
    
    for _ in range(num_posts):
        try:
            # Select random existing account
            account = random.choice(accounts)
            user_profile = account.userprofile
            
            # Get content elements
            title = random.choice(POST_TITLES)
            content = random.choice(POST_CONTENTS)
            category = random.choice(categories)
            location_data = get_random_location()
            
            # Decide if post will have media
            has_media = random.random() > 0.5
            media_urls = []
            if has_media:
                num_media = random.randint(1, 3)
                media_urls = random.sample(MEDIA_URLS, min(num_media, len(MEDIA_URLS)))
            
            # Create the post
            post = Post(
                title=title,
                content=content,
                author=user_profile,
                category=category,
                latitude=location_data["latitude"],
                longitude=location_data["longitude"],
                address=location_data["address"],
                is_verified_location=True,
                taken_within_app=True,
                status='published'
            )
            
            # Add media if any
            if media_urls:
                post.media_urls = media_urls
            
            # Add tags
            tags = get_random_tags()
            post.tags = tags
            
            # Randomly decide if this post should start a new thread
            should_create_thread = random.random() > 0.7  # 30% chance to create a thread
            
            if should_create_thread:
                # Create a thread
                thread = Thread(
                    title=title,
                    category=category,
                    latitude=location_data["latitude"],
                    longitude=location_data["longitude"],
                    address=location_data["address"],
                )
                thread.save()
                post.thread = thread
                threads_created += 1
                logger.info(f"Created new thread: {title}")
            
            post.save()
            posts_created += 1
            
            # Add some interactions: upvotes, downvotes
            upvotes = random.randint(0, 30)
            downvotes = random.randint(0, min(upvotes, 10))  # Less downvotes than upvotes
            post.upvotes = upvotes
            post.downvotes = downvotes
            post.save()
            
            logger.info(f"Created post: {title} at {location_data['address']}")
            
        except Exception as e:
            logger.error(f"Error creating post: {str(e)}")
    
    logger.info(f"Palestinian data generation complete. Created {posts_created} posts and {threads_created} threads.")
    return (posts_created, threads_created)

if __name__ == "__main__":
    # Get number of posts from command line argument or use default
    num_posts = 50
    if len(sys.argv) > 1:
        try:
            num_posts = int(sys.argv[1])
        except ValueError:
            logger.error("Invalid number of posts specified. Using default 50.")
    
    logger.info(f"Starting Palestinian data generation script to create {num_posts} posts")
    created_posts, created_threads = create_palestinian_posts(num_posts)
    logger.info(f"Script completed successfully. Created {created_posts} posts and {created_threads} threads.")