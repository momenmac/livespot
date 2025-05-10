#!/usr/bin/env python
import os
import sys
import random
import datetime
import uuid
import string
import requests
import io
from decimal import Decimal
from pathlib import Path

# Add the project root to path so we can import Django modules
script_path = Path(__file__).resolve()
root_dir = script_path.parent.parent
sys.path.append(str(root_dir))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
from django.core.files.base import ContentFile
django.setup()

from django.contrib.auth.hashers import make_password
from accounts.models import Account, UserProfile
from posts.models import Post, Thread, PostCoordinates, PostCategory

# Palestinian and Israeli cities and their base coordinates
PALESTINE_CITIES = [
    {
        "name": "Gaza City",
        "base_latitude": 31.5016,
        "base_longitude": 34.4668,
        "neighborhoods": [
            "Al Rimal", "Al Shati", "Al Daraj", "Al Tuffah", "Al Sabra", 
            "Al Zeitoun", "Tel al-Hawa", "Sheikh Ijlin", "Sheikh Radwan"
        ]
    },
    {
        "name": "Khan Yunis",
        "base_latitude": 31.3417,
        "base_longitude": 34.3063,
        "neighborhoods": [
            "Al Mawasi", "Bani Suhaila", "Abasan", "Al Qarara", "Khuzaa"
        ]
    },
    {
        "name": "Rafah",
        "base_latitude": 31.2977,
        "base_longitude": 34.2400,
        "neighborhoods": [
            "Tal al-Sultan", "Yibna", "Al-Brazil", "Al-Salam", "Al-Jnina"
        ]
    },
    {
        "name": "Jabalia",
        "base_latitude": 31.5272,
        "base_longitude": 34.4800,
        "neighborhoods": [
            "Jabalia Camp", "Beit Lahia", "Beit Hanoun", "Um Al Nasser", "Al Atatra"
        ]
    },
    {
        "name": "Ramallah",
        "base_latitude": 31.9038,
        "base_longitude": 35.2034,
        "neighborhoods": [
            "Al-Tireh", "Ein Munjid", "Al-Masyoun", "Al-Bireh", "Umm al-Sharayet"
        ]
    },
    {
        "name": "Hebron",
        "base_latitude": 31.5326,
        "base_longitude": 35.0998,
        "neighborhoods": [
            "Old City", "Wadi Al-Harya", "Al-Hawooz", "Ein Sara", "Al-Salam"
        ]
    },
    {
        "name": "Nablus",
        "base_latitude": 32.2211,
        "base_longitude": 35.2544,
        "neighborhoods": [
            "Old City", "Rafidia", "Al-Makhfiya", "Balata Camp", "Askar Camp"
        ]
    },
    {
        "name": "Bethlehem",
        "base_latitude": 31.7054,
        "base_longitude": 35.2024,
        "neighborhoods": [
            "Beit Jala", "Beit Sahour", "Al-Doha", "Al-Khader", "Dheisheh Camp"
        ]
    },
    {
        "name": "Jenin",
        "base_latitude": 32.4597,
        "base_longitude": 35.2963,
        "neighborhoods": [
            "Jenin Camp", "Al-Basateen", "Al-Marah", "Wadi Burqin", "Al-Jabriyat"
        ]
    },
    {
        "name": "Jericho",
        "base_latitude": 31.8614,
        "base_longitude": 35.4635,
        "neighborhoods": [
            "Ein al-Sultan Camp", "Aqabat Jabr", "Al-Maghtas", "Al-Auja", "Al-Nuweima"
        ]
    },
    {
        "name": "Tulkarm",
        "base_latitude": 32.3100,
        "base_longitude": 35.0286,
        "neighborhoods": [
            "Shuweika", "Dhinnaba", "Iktaba", "Bal'a", "Attil"
        ]
    },
    {
        "name": "Qalqilya",
        "base_latitude": 32.1897,
        "base_longitude": 34.9706,
        "neighborhoods": [
            "Al-Naqqar", "Habla", "Azzun", "Jayyous", "Kafr Saba"
        ]
    },
    {
        "name": "Salfit",
        "base_latitude": 32.0849,
        "base_longitude": 35.1800,
        "neighborhoods": [
            "Marda", "Kifl Haris", "Biddya", "Deir Istiya", "Haris"
        ]
    },
    {
        "name": "Tel Aviv",
        "base_latitude": 32.0853,
        "base_longitude": 34.7818,
        "neighborhoods": [
            "Jaffa", "Florentin", "Neve Tzedek", "Ramat Aviv", "Kerem HaTeimanim"
        ]
    },
    {
        "name": "Ashkelon",
        "base_latitude": 31.6693,
        "base_longitude": 34.5715,
        "neighborhoods": [
            "Barnea", "Afridar", "Neve Ilan", "Migdal", "Neve Dekalim"
        ]
    },
    {
        "name": "Sderot",
        "base_latitude": 31.5272,
        "base_longitude": 34.5953,
        "neighborhoods": [
            "Neve Eshkol", "Neve Oz", "Neve Shalom", "Neve Dekalim", "Neve Yam"
        ]
    },
    {
        "name": "Beersheba",
        "base_latitude": 31.2518,
        "base_longitude": 34.7913,
        "neighborhoods": [
            "Ramot", "Neve Ze'ev", "Nahal Ashan", "Old City", "Alef"
        ]
    },
    {
        "name": "Haifa",
        "base_latitude": 32.7940,
        "base_longitude": 34.9896,
        "neighborhoods": [
            "Hadar", "Bat Galim", "Carmel Center", "Neve Sha'anan", "Kiryat Eliezer"
        ]
    }
]

# Palestinian names for generating realistic users
PALESTINIAN_FIRST_NAMES = [
    # Male names
    "Mohammad", "Ahmed", "Mahmoud", "Ali", "Omar", "Ibrahim", "Khaled", "Yousef", "Ismail", 
    "Sami", "Nasser", "Jamal", "Kamal", "Fadi", "Rami", "Waleed", "Tamer", "Tareq", "Saeed",
    
    # Female names
    "Fatima", "Aisha", "Maryam", "Amina", "Layla", "Leila", "Huda", "Noor", "Sara", "Rania",
    "Dalia", "Hanan", "Samira", "Ghada", "Najla", "Yasmin", "Zahra", "Rana", "Farrah"
]

PALESTINIAN_LAST_NAMES = [
    "Abbas", "Abu-Eid", "Abu-Hassan", "Abu-Khalaf", "Al-Masri", "Barghouthi", "Darwish", 
    "Hamdan", "Hassan", "Hussein", "Jabari", "Kanaan", "Khatib", "Mansour", "Nassar", 
    "Qasem", "Shaheen", "Suleiman", "Tamimi", "Zidan", "Zoabi", "Awad", "Haddad", "Saleh"
]

# Palestinian news categories and topics
NEWS_TOPICS = [
    {
        "category": PostCategory.NEWS,
        "topics": [
            "Local markets reopen in {neighborhood}, {city}",
            "New medical center inaugurated in {neighborhood}, {city}",
            "Educational initiatives launched in {neighborhood} schools",
            "Community meeting discusses infrastructure in {neighborhood}",
            "Cultural heritage preservation efforts in {neighborhood}",
            "New water distribution point opened in {neighborhood}",
            "Local council announces development plans for {neighborhood}",
            "Healthcare services expand in {city}'s {neighborhood} area",
            "Farmers market to open weekly in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.ALERT,
        "topics": [
            "Water supply interruption in {neighborhood} area",
            "Power outage affecting {neighborhood} district",
            "Road closure on main street in {neighborhood}",
            "Temporary school closure in {neighborhood} due to maintenance",
            "Weather warning issued for {neighborhood} region",
            "Medical supplies needed in {neighborhood} clinic",
            "Traffic diversion implemented near {neighborhood} junction",
            "Scheduled maintenance affecting services in {neighborhood}",
            "Emergency response teams deployed to {neighborhood}"
        ]
    },
    {
        "category": PostCategory.COMMUNITY,
        "topics": [
            "Volunteer cleanup campaign in {neighborhood}",
            "Youth sports tournament starts in {neighborhood}",
            "Community garden project in {neighborhood} seeks volunteers",
            "Local artists showcase work in {neighborhood} exhibition",
            "Neighborhood council meeting scheduled in {neighborhood}",
            "Children's play area renovated in {neighborhood}",
            "Community cooking initiative brings neighbors together in {neighborhood}",
            "Elderly support network formed in {neighborhood}",
            "Weekend workshops planned for {neighborhood} community center"
        ]
    },
    {
        "category": PostCategory.TRAFFIC,
        "topics": [
            "Traffic congestion reported near {neighborhood} market",
            "Road maintenance work begins on {neighborhood} main street",
            "New traffic pattern implemented in {neighborhood} center",
            "Public transportation schedule change in {neighborhood}",
            "Bridge repair affecting traffic in {neighborhood} area",
            "School zone traffic monitoring increased in {neighborhood}",
            "New pedestrian crossing installed in {neighborhood}",
            "Alternative routes suggested during {neighborhood} roadworks",
            "Delivery vehicles causing congestion in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.EVENT,
        "topics": [
            "Annual cultural festival coming to {neighborhood}",
            "Book fair opens this weekend in {neighborhood}",
            "Food distribution event planned in {neighborhood}",
            "Children's activities day in {neighborhood} park",
            "Health awareness campaign visits {neighborhood}",
            "Tech workshop for youth scheduled in {neighborhood} center",
            "Traditional crafts exhibition opening in {neighborhood}",
            "Community celebration marks important date in {neighborhood}",
            "Local talent showcase to be held in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.WEATHER,
        "topics": [
            "Unexpected rain affecting {neighborhood} streets today",
            "Strong winds reported in {neighborhood} - secure loose items",
            "Temperature drop expected tonight in {neighborhood}",
            "Dust storm approaching {neighborhood} - health precautions advised",
            "Heat wave continues to impact {neighborhood}",
            "Flash flood warning issued for {neighborhood} valley area",
            "Winter preparations underway in {neighborhood}",
            "Mild weather brings relief to {neighborhood} residents",
            "Weather station installed in {neighborhood} for local forecasting"
        ]
    },
    {
        "category": PostCategory.CRIME,
        "topics": [
            "Community watch program starting in {neighborhood}",
            "Report suspicious activity near {neighborhood} school",
            "Bicycle thefts increasing in {neighborhood}",
            "Safety measures enhanced around {neighborhood} market",
            "Lost child reunited with family in {neighborhood}",
            "Community meeting to discuss safety in {neighborhood}",
            "Authorities warn of scams targeting {neighborhood} residents",
            "Street lighting improved in {neighborhood} for better security",
            "Neighborhood patrol volunteers needed in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.MILITARY,
        "topics": [
            "Military checkpoint established near {neighborhood}",
            "Security forces deployed to {neighborhood} area",
            "Increased security presence in {neighborhood} district",
            "Military vehicles spotted in {neighborhood}",
            "Security alert issued for {neighborhood}",
            "Checkpoint operations affecting traffic in {neighborhood}",
            "Security personnel conducting patrols in {neighborhood}",
            "Military equipment transporters seen in {neighborhood}",
            "Security forces conducting exercises near {neighborhood}"
        ]
    },
    {
        "category": PostCategory.CASUALTIES,
        "topics": [
            "Medical teams deployed to {neighborhood} following incident",
            "Emergency services responding to situation in {neighborhood}",
            "Ambulances dispatched to {neighborhood} area",
            "Medical assistance needed in {neighborhood}",
            "Field hospital established in {neighborhood}",
            "Medical evacuation ongoing in {neighborhood}",
            "Healthcare workers responding to emergency in {neighborhood}",
            "Blood donation drive organized for {neighborhood} casualties",
            "Emergency medical supplies needed in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.EXPLOSION,
        "topics": [
            "Loud explosion heard in {neighborhood} area",
            "Emergency services responding to blast in {neighborhood}",
            "Explosion reported near {neighborhood} market",
            "Residents report hearing explosion in {neighborhood}",
            "Windows shattered from blast in {neighborhood}",
            "Authorities investigating explosion in {neighborhood} district",
            "Blast damage reported in {neighborhood}",
            "Evacuation ordered following explosion in {neighborhood}",
            "Safety assessment underway after blast in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.POLITICS,
        "topics": [
            "Political delegation visits {neighborhood}",
            "Local leaders meet with residents in {neighborhood}",
            "Policy discussion held in {neighborhood} community center",
            "Government representatives tour {neighborhood} facilities",
            "Political rally scheduled in {neighborhood}",
            "Community members voice concerns to officials in {neighborhood}",
            "New policies affecting {neighborhood} announced",
            "Political candidates campaign in {neighborhood}",
            "Town hall meeting in {neighborhood} addresses local issues"
        ]
    },
    {
        "category": PostCategory.SPORTS,
        "topics": [
            "Local soccer tournament kicks off in {neighborhood}",
            "Sports facilities reopening in {neighborhood}",
            "Youth athletics program launched in {neighborhood}",
            "School sports competition in {neighborhood} draws crowds",
            "Basketball courts renovated in {neighborhood}",
            "Athletes from {neighborhood} qualify for regional competition",
            "Sports day planned for {neighborhood} community",
            "Running club established in {neighborhood}",
            "Sports equipment donation drive for {neighborhood} youth"
        ]
    },
    {
        "category": PostCategory.HEALTH,
        "topics": [
            "Health clinic opens in {neighborhood}",
            "Vaccination campaign reaches {neighborhood}",
            "Health awareness session in {neighborhood} community center",
            "Medical outreach team visits {neighborhood}",
            "Mental health services now available in {neighborhood}",
            "Health screening program in {neighborhood} school",
            "Mobile medical unit stationed in {neighborhood} this week",
            "Nutrition workshop held for {neighborhood} residents",
            "Dental care services offered in {neighborhood} health center"
        ]
    },
    {
        "category": PostCategory.DISASTER,
        "topics": [
            "Disaster response team deployed to {neighborhood}",
            "Emergency shelters opened in {neighborhood}",
            "Relief supplies arriving in {neighborhood}",
            "Evacuation routes established for {neighborhood}",
            "Disaster assessment underway in {neighborhood}",
            "Recovery efforts begin in {neighborhood}",
            "Emergency protocols activated for {neighborhood}",
            "Temporary housing set up in {neighborhood}",
            "Disaster drill scheduled for {neighborhood}"
        ]
    },
    {
        "category": PostCategory.ENVIRONMENT,
        "topics": [
            "Environmental cleanup initiative in {neighborhood}",
            "Tree planting project starts in {neighborhood}",
            "Water quality testing in {neighborhood} area",
            "Solar power installation begins in {neighborhood}",
            "Environmental impact assessment for {neighborhood} development",
            "Green spaces expanding in {neighborhood}",
            "Recycling program launched in {neighborhood}",
            "Community garden established in {neighborhood}",
            "Environmental education workshop in {neighborhood} school"
        ]
    },
    {
        "category": PostCategory.EDUCATION,
        "topics": [
            "New school year begins in {neighborhood} schools",
            "Educational resources distributed in {neighborhood}",
            "Teacher training program in {neighborhood}",
            "Afterschool programs expand in {neighborhood}",
            "Adult education classes offered in {neighborhood} center",
            "School renovation project in {neighborhood}",
            "Educational technology introduced in {neighborhood} classrooms",
            "Scholarship opportunities announced for {neighborhood} students",
            "Reading program launches in {neighborhood} library"
        ]
    },
    {
        "category": PostCategory.FIRE,
        "topics": [
            "Fire reported in {neighborhood} building",
            "Firefighters responding to blaze in {neighborhood}",
            "Fire safety training held in {neighborhood}",
            "Homes evacuated due to fire in {neighborhood}",
            "Fire department conducts drill in {neighborhood}",
            "Fire containment efforts in {neighborhood} area",
            "Fire safety equipment distributed in {neighborhood}",
            "Fire risk assessment conducted in {neighborhood}",
            "Community briefed on fire prevention in {neighborhood}"
        ]
    },
    {
        "category": PostCategory.OTHER,
        "topics": [
            "Unusual activity reported in {neighborhood}",
            "Special announcement for {neighborhood} residents",
            "Unclassified situation developing in {neighborhood}",
            "General notice for {neighborhood} community",
            "Updates pending for {neighborhood} situation",
            "Residents of {neighborhood} requested to check notifications",
            "Information forthcoming about {neighborhood} incident",
            "Special bulletin for {neighborhood} area",
            "Miscellaneous alert for {neighborhood} district"
        ]
    },
    {
        "category": PostCategory.MILITARY,
        "topics": [
            "Rocket sirens sound in {city}",
            "Residents report explosions in {neighborhood}, {city}",
            "Israeli drones spotted over {city}",
            "Heavy clashes reported in {neighborhood}, {city}",
            "Military curfew imposed in {city}",
            "Border crossing closed near {city}",
            "Israeli forces conduct raids in {neighborhood}, {city}",
            "Palestinian resistance groups claim responsibility for attack in {city}",
            "International journalists arrive in {city} to cover conflict"
        ]
    }
]

# Add special Israeli operation announcements and political events
ISRAELI_OPERATIONS = [
    {
        "category": PostCategory.MILITARY,
        "topics": [
            "Israel announces new military operation near {city}",
            "IDF mobilizes forces near {city} border",
            "Military operation underway in areas adjacent to {neighborhood}",
            "Israeli forces announce expansion of security zone near {city}",
            "Military spokesperson confirms operation near {city} border",
            "Increased military activity reported around {city}",
            "Security forces announce targeted operations near {neighborhood}",
            "Military convoy spotted moving towards {city}",
            "Israel Defense Forces establish new checkpoints around {city}",
            "IDF launches airstrikes on {city}",
            "Israeli government issues evacuation order for {city}",
            "Iron Dome intercepts rockets over {city}",
            "Israeli tanks mobilize near {city}",
            "Israeli jets fly over {city} airspace"
        ],
        "content_templates": [
            "Israeli military spokesperson announced a new operation targeting areas near {neighborhood}, {city}. Residents are advised to follow safety protocols and stay indoors.",
            "Military officials confirmed increased activity in areas near {neighborhood}. This comes after recent security incidents reported in the region.",
            "Defense forces announced they will be conducting operations near {city} following intelligence reports. The operations are expected to last several days.",
            "A significant military buildup has been observed near {city} with multiple armored vehicles and troops being deployed. Officials cited security concerns as the reason.",
            "The Israeli military has launched a series of airstrikes targeting locations in and around {city}. Residents are urged to seek shelter.",
            "Authorities have issued an evacuation order for parts of {city} due to escalating hostilities.",
            "Iron Dome defense system intercepted several rockets over {city} last night.",
            "Israeli tanks and armored vehicles have been seen mobilizing near {city}, raising concerns among local residents.",
            "Israeli Air Force jets conducted low-altitude flights over {city} as part of ongoing military operations."
        ]
    },
    {
        "category": PostCategory.EXPLOSION,
        "topics": [
            "Multiple explosions reported near {neighborhood}, {city}",
            "Airstrikes target areas near {neighborhood}",
            "Bombing reported in outskirts of {city}",
            "Artillery strikes hit near {neighborhood} area",
            "Missile impacts reported near {city}"
        ],
        "content_templates": [
            "Multiple explosions have been heard in and around {neighborhood}, {city}. Emergency services are responding to the scene. Residents are advised to seek shelter immediately.",
            "Reports of airstrikes targeting infrastructure near {neighborhood}. Several buildings have been damaged and emergency teams are assessing the situation.",
            "Series of explosions occurred near {city} in the early hours of the morning. Initial reports suggest multiple sites were targeted."
        ]
    },
    {
        "category": PostCategory.CASUALTIES,
        "topics": [
            "Medical centers in {city} report multiple casualties",
            "Hospitals in {city} call for blood donations following incident",
            "Emergency response teams deployed to {neighborhood} after attack",
            "Medical teams overwhelmed in {city} following recent events"
        ],
        "content_templates": [
            "Local hospitals in {city} are reporting an influx of injured people following recent events in {neighborhood}. Medical supplies are urgently needed.",
            "Healthcare facilities in {city} are operating at maximum capacity. Additional medical teams are being sent to {neighborhood} to assist.",
            "Emergency services report multiple casualties in {neighborhood} and surrounding areas. Blood donation centers have been set up."
        ]
    },
    {
        "category": PostCategory.POLITICS,
        "topics": [
            "UN Security Council calls emergency meeting regarding situation in {city}",
            "International organizations express concern over escalation in {city}",
            "World leaders call for immediate ceasefire in {city} region",
            "Political delegations arrive to assess humanitarian situation in {city}",
            "Diplomatic efforts intensify following recent events in {city}"
        ],
        "content_templates": [
            "The United Nations has called an emergency Security Council meeting regarding the deteriorating situation in {city}. Several countries have expressed deep concern.",
            "International humanitarian organizations are demanding immediate access to affected areas in {neighborhood}, {city} to provide essential aid.",
            "World leaders have issued joint statements calling for restraint and protection of civilians in {city} and surrounding regions."
        ]
    }
]

# Content templates with real context about Palestine
CONTENT_TEMPLATES = [
    "Local residents in {neighborhood}, {city} are participating in this initiative to improve community resources. Many families have joined together to help with the project.",
    
    "The situation in {neighborhood}, {city} continues to develop, with community members working together to address local needs. Resources are being distributed to affected areas.",
    
    "Community leaders in {neighborhood} have announced plans for infrastructure improvements. The project aims to enhance services for local residents in {city}.",
    
    "Volunteers in {neighborhood} of {city} are organizing support networks to assist families in need. The community response has been encouraging.",
    
    "Health services in {neighborhood}, {city} are being expanded to meet increased demand. Medical supplies and personnel have been allocated to support the effort.",
    
    "Educational programs in {neighborhood} are adapting to current circumstances. Teachers and students are showing remarkable resilience in continuing learning activities despite challenges.",
    
    "Agricultural initiatives in {neighborhood} are helping to maintain food security. Local farmers in {city} are working to increase production despite challenges.",
    
    "Cultural heritage preservation efforts in {neighborhood} continue despite difficulties. Community members are documenting and protecting historical sites important to {city}'s history.",
    
    "Water access improvements are underway in {neighborhood}. Technical teams are working to repair and enhance distribution systems for residents throughout {city}.",
    
    "Youth engagement programs in {neighborhood}, {city} are providing important recreational and educational opportunities. Local organizations are coordinating these essential activities.",
    
    "Temporary housing solutions are being implemented in {neighborhood} to address urgent needs. Families in {city} are receiving assistance with shelter and basic necessities.",
    
    "Women-led initiatives in {neighborhood} are creating economic opportunities through craft cooperatives. These projects support sustainable livelihoods for families in {city}.",
    
    "Solar power installations in {neighborhood} are helping to provide reliable electricity. This renewable energy solution is especially important for critical facilities in {city}.",
    
    "Mobile health clinics are visiting {neighborhood} weekly, offering preventive care and treatments. Healthcare workers are committed to serving all areas of {city}, especially those with limited access.",
    
    "Digital literacy workshops in {neighborhood} are helping residents stay connected. These skills are increasingly important for education and communication throughout {city}."
]

# Tags relevant to Palestine
PALESTINE_TAGS = [
    "community", "support", "local", "resources", "health", "education",
    "infrastructure", "utilities", "transportation", "culture", "heritage",
    "agriculture", "water", "electricity", "youth", "family", "services",
    "development", "solidarity", "resilience", "cooperation", "neighborhood",
    "women", "children", "elderly", "sustainable", "renewable", "digital",
    "communication", "emergency", "relief", "rebuilding", "renovation",
    "safety", "security", "environment", "technology", "innovation"
]

# Profile picture URLs for male and female users
PROFILE_PICS = {
    "male": [
        "https://randomuser.me/api/portraits/men/1.jpg",
        "https://randomuser.me/api/portraits/men/2.jpg",
        "https://randomuser.me/api/portraits/men/3.jpg",
        "https://randomuser.me/api/portraits/men/4.jpg",
        "https://randomuser.me/api/portraits/men/5.jpg",
        "https://randomuser.me/api/portraits/men/6.jpg",
        "https://randomuser.me/api/portraits/men/7.jpg",
        "https://randomuser.me/api/portraits/men/8.jpg",
        "https://randomuser.me/api/portraits/men/9.jpg",
        "https://randomuser.me/api/portraits/men/10.jpg"
    ],
    "female": [
        "https://randomuser.me/api/portraits/women/1.jpg",
        "https://randomuser.me/api/portraits/women/2.jpg",
        "https://randomuser.me/api/portraits/women/3.jpg",
        "https://randomuser.me/api/portraits/women/4.jpg",
        "https://randomuser.me/api/portraits/women/5.jpg",
        "https://randomuser.me/api/portraits/women/6.jpg",
        "https://randomuser.me/api/portraits/women/7.jpg",
        "https://randomuser.me/api/portraits/women/8.jpg",
        "https://randomuser.me/api/portraits/women/9.jpg",
        "https://randomuser.me/api/portraits/women/10.jpg"
    ]
}

# Post image URLs (different categories)
IMAGE_URLS = {
    "community": [
        "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800",
        "https://images.unsplash.com/photo-1517486808906-6ca8b3f8e1c1?w=800",
        "https://images.unsplash.com/photo-1503249023995-51b0f3778ccf?w=800",
        "https://images.unsplash.com/photo-1582213782179-e0d53f98f2ca?w=800"
    ],
    "infrastructure": [
        "https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=800",
        "https://images.unsplash.com/photo-1531153271447-d4545595a3c0?w=800",
        "https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=800"
    ],
    "education": [
        "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=800",
        "https://images.unsplash.com/photo-1509062522246-3755977927d7?w=800",
        "https://images.unsplash.com/photo-1542362567-b07e54358753?w=800"
    ],
    "health": [
        "https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?w=800",
        "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=800",
        "https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=800"
    ],
    "market": [
        "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        "https://images.unsplash.com/photo-1533900298318-6b8da08a523e?w=800",
        "https://images.unsplash.com/photo-1513639304702-9847343302974?w=800"
    ],
    "landscape": [
        "https://images.unsplash.com/photo-1477581265664-b1e27c6731a7?w=800",
        "https://images.unsplash.com/photo-1548588681-adf41d474533?w=800",
        "https://images.unsplash.com/photo-1518334939725-075471d51781?w=800"
    ]
}

def generate_varied_location(city_data, existing_locations=None):
    """
    Generate a location with slight variation from base coordinates within a city
    ensuring minimum distance from existing locations
    """
    MIN_DISTANCE_METERS = 100  # Minimum distance in meters between posts
    
    # Convert to approximate degrees (very rough approximation)
    # 0.001 degree is roughly 111 meters at the equator
    MIN_DISTANCE_DEGREES = MIN_DISTANCE_METERS / 111000
    
    max_attempts = 50  # Maximum number of attempts to find a valid location
    attempts = 0
    
    while attempts < max_attempts:
        # Calculate a slight variation in coordinates (within ~2 km)
        lat_variation = random.uniform(-0.015, 0.015)
        lng_variation = random.uniform(-0.015, 0.015)
        
        latitude = city_data["base_latitude"] + lat_variation
        longitude = city_data["base_longitude"] + lng_variation
        
        # Check minimum distance if we have existing locations
        if existing_locations:
            too_close = False
            for loc in existing_locations:
                # Calculate approximate distance using Euclidean distance
                # This is not accurate for long distances but good enough for our purpose
                dist = ((loc["latitude"] - latitude) ** 2 + (loc["longitude"] - longitude) ** 2) ** 0.5
                if dist < MIN_DISTANCE_DEGREES:
                    too_close = True
                    break
            
            if too_close:
                attempts += 1
                continue
        
        # Select a neighborhood
        neighborhood = random.choice(city_data["neighborhoods"])
        
        # Create the address
        address = f"{neighborhood}, {city_data['name']}, Palestine"
        
        location = {
            "neighborhood": neighborhood,
            "city": city_data["name"],
            "latitude": latitude,
            "longitude": longitude,
            "address": address
        }
        
        return location
    
    # If we've tried max attempts and couldn't find a valid location,
    # just return a location without checking the minimum distance
    lat_variation = random.uniform(-0.015, 0.015)
    lng_variation = random.uniform(-0.015, 0.015)
    latitude = city_data["base_latitude"] + lat_variation
    longitude = city_data["base_longitude"] + lng_variation
    neighborhood = random.choice(city_data["neighborhoods"])
    address = f"{neighborhood}, {city_data['name']}, Palestine"
    
    return {
        "neighborhood": neighborhood,
        "city": city_data["name"],
        "latitude": latitude,
        "longitude": longitude,
        "address": address
    }

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

def get_random_time_for_recent_days():
    """Get a random datetime within May 8-10, 2025"""
    # Define dates for May 8, 9, 10, 2025
    start_date = datetime.datetime(2025, 5, 8)
    
    # Select a random date (May 8, 9, or 10)
    day_offset = random.randint(0, 2)
    chosen_date = start_date + datetime.timedelta(days=day_offset)
    
    # Add random hours and minutes
    random_hours = random.randint(0, 23)
    random_minutes = random.randint(0, 59)
    
    return chosen_date + datetime.timedelta(hours=random_hours, minutes=random_minutes)

def create_post_content(topic, location_data):
    """Create realistic post content based on a topic and location"""
    # Replace placeholders with actual location data
    topic_text = topic.replace("{neighborhood}", location_data["neighborhood"]).replace("{city}", location_data["city"])
    
    # Choose a content template and replace placeholders
    content = random.choice(CONTENT_TEMPLATES).replace("{neighborhood}", location_data["neighborhood"]).replace("{city}", location_data["city"])
    
    # Add some additional context based on category sometimes
    additional_contexts = [
        f"Residents in {location_data['neighborhood']} are encouraged to participate.",
        f"Updates will be shared with the {location_data['city']} community as they become available.",
        f"For more information, contact the {location_data['neighborhood']} community center.",
        f"This initiative aims to support families in {location_data['neighborhood']} during these challenging times.",
        f"Multiple organizations are coordinating efforts in {location_data['neighborhood']} to maximize impact.",
        f"Volunteers from neighboring areas are also contributing to the work in {location_data['neighborhood']}.",
        f"Local expertise is being utilized to ensure solutions are appropriate for {location_data['city']}'s specific needs."
    ]
    
    if random.random() > 0.5:
        content += " " + random.choice(additional_contexts)
    
    return topic_text, content

def download_profile_pic(url):
    """Download profile picture from URL and return as ContentFile"""
    try:
        response = requests.get(url)
        if response.status_code == 200:
            return ContentFile(response.content)
        else:
            print(f"Failed to download image from {url}. Status code: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error downloading profile picture: {e}")
        return None

def create_user_with_profile(first_name, last_name, gender):
    """Create a user account and profile with default password '1234'"""
    # Generate a unique email
    username_base = f"{first_name.lower()}.{last_name.lower()}"
    email = f"{username_base}@example.com"
    
    # Check if email exists, if so, append a random number
    while Account.objects.filter(email=email).exists():
        random_num = random.randint(1, 999)
        email = f"{username_base}{random_num}@example.com"
    
    # Create the user
    user = Account.objects.create(
        email=email,
        first_name=first_name,
        last_name=last_name,
        password=make_password('1234'),  # All users have password '1234'
        is_verified=True
    )
    
    # Download and set profile picture
    if gender == "male" or gender == "female":
        profile_pic_url = random.choice(PROFILE_PICS[gender])
        image_content = download_profile_pic(profile_pic_url)
        
        if image_content:
            # Generate a unique filename
            ext = profile_pic_url.split('.')[-1]
            filename = f"{uuid.uuid4()}.{ext}"
            
            # Save the image to user's profile_picture field
            user.profile_picture.save(filename, image_content, save=True)
    
    # UserProfile should be created automatically via signals
    
    # Add some realistic user profile data
    try:
        profile = user.profile
        profile.honesty_score = random.randint(70, 100)
        profile.bio = random.choice([
            f"Resident of {random.choice([city['name'] for city in PALESTINE_CITIES])}",
            "Community volunteer and advocate",
            "Interested in local development and sustainability",
            "Working to support community initiatives",
            f"Teacher and education advocate in Palestine",
            "Healthcare worker serving local communities",
            "Environmental sustainability advocate",
            "Tech enthusiast working on digital literacy programs",
            "Artist and cultural heritage preservationist"
        ])
        
        # Set some interests as tags
        interests = random.sample(PALESTINE_TAGS, k=random.randint(3, 6))
        profile.interests = interests
        
        profile.save()
    except Exception as e:
        print(f"Error updating profile for user {email}: {e}")
    
    return user

def select_image_for_post(category_name):
    """Select an appropriate image URL for a post based on its category"""
    category_mapping = {
        PostCategory.NEWS: random.choice(["infrastructure", "community", "landscape"]),
        PostCategory.ALERT: random.choice(["infrastructure", "health"]),
        PostCategory.COMMUNITY: "community",
        PostCategory.TRAFFIC: "infrastructure",
        PostCategory.EVENT: "community",
        PostCategory.WEATHER: "landscape",
        PostCategory.CRIME: "community",
        PostCategory.MILITARY: random.choice(["infrastructure", "landscape"]),
        PostCategory.CASUALTIES: "health",
        PostCategory.EXPLOSION: random.choice(["infrastructure", "landscape"]),
        PostCategory.POLITICS: random.choice(["community", "infrastructure"]),
        PostCategory.SPORTS: "community",
        PostCategory.HEALTH: "health",
        PostCategory.DISASTER: random.choice(["landscape", "infrastructure"]),
        PostCategory.ENVIRONMENT: "landscape",
        PostCategory.EDUCATION: "education",
        PostCategory.FIRE: random.choice(["infrastructure", "landscape"]),
        PostCategory.OTHER: random.choice(list(IMAGE_URLS.keys()))
    }
    
    image_category = category_mapping.get(category_name, "landscape")
    return random.choice(IMAGE_URLS[image_category])

def create_palestine_data(num_users=20, num_posts=100, thread_probability=0.3):
    """Create mock data for Palestine/Israel with specified parameters"""
    print("Deleting all existing data...")
    # Delete all data in correct order (posts, threads, coordinates, users, profiles)
    from posts.models import Post, Thread, PostCoordinates
    from accounts.models import Account, UserProfile
    from django.db import transaction

    with transaction.atomic():
        Post.objects.all().delete()
        Thread.objects.all().delete()
        PostCoordinates.objects.all().delete()
        UserProfile.objects.all().delete()
        Account.objects.all().delete()

    print("All data deleted. Generating new data...")

    print(f"Creating {num_users} users and {num_posts} posts with Palestine/Israel data...")
    
    # Create users
    users = []
    for i in range(num_users):
        # Randomly choose gender
        gender = random.choice(["male", "female"])
        
        # Select appropriate name based on gender
        if gender == "male":
            first_name = random.choice([name for name in PALESTINIAN_FIRST_NAMES if name not in ["Fatima", "Aisha", "Maryam", "Amina", "Layla", "Leila", "Huda", "Noor", "Sara", "Rania", "Dalia", "Hanan", "Samira", "Ghada", "Najla", "Yasmin", "Zahra", "Rana", "Farrah"]])
        else:
            first_name = random.choice(["Fatima", "Aisha", "Maryam", "Amina", "Layla", "Leila", "Huda", "Noor", "Sara", "Rania", "Dalia", "Hanan", "Samira", "Ghada", "Najla", "Yasmin", "Zahra", "Rana", "Farrah"])
            
        last_name = random.choice(PALESTINIAN_LAST_NAMES)
        
        user = create_user_with_profile(first_name, last_name, gender)
        users.append(user)
        print(f"Created user {i+1}/{num_users}: {user.first_name} {user.last_name}")
    
    if not users:
        print("Failed to create users. Exiting.")
        return
    
    # Randomly make users follow each other
    print("Randomly assigning followers...")
    for user in users:
        # Each user follows 1-5 other users (not themselves)
        possible_follows = [u for u in users if u != user]
        to_follow = random.sample(possible_follows, k=random.randint(1, min(5, len(possible_follows))))
        for followee in to_follow:
            try:
                user.profile.followers.add(followee.profile)
            except Exception as e:
                print(f"Error making {user.email} follow {followee.email}: {e}")

    # Track created threads to add posts to them
    created_threads = []
    existing_locations = []
    
    # Randomize city selection for each post
    all_city_indices = list(range(len(PALESTINE_CITIES)))
    # Assign posts to random cities, not just a fixed distribution
    posts_per_city = {i: 0 for i in all_city_indices}
    for _ in range(num_posts):
        idx = random.choice(all_city_indices)
        posts_per_city[idx] += 1

    # Add Israeli operations (40% of posts)
    israeli_ops_count = int(num_posts * 0.4)
    
    # Process for post creation
    post_count = 0
    for city_idx, city_post_count in posts_per_city.items():
        if city_post_count == 0:
            continue
        city_data = PALESTINE_CITIES[city_idx]
        print(f"\nGenerating {city_post_count} posts for {city_data['name']}...")
        
        city_locations = []
        
        for _ in range(city_post_count):
            # Select random user
            user = random.choice(users)
            
            # Generate a varied location within this city
            location_data = generate_varied_location(city_data, city_locations)
            city_locations.append(location_data)
            existing_locations.append(location_data)
            location = create_location(location_data)
            
            # Determine if this should be an Israeli operation post
            is_israeli_op = post_count < israeli_ops_count
            
            # Select random category and topic
            if is_israeli_op:
                category_data = random.choice(ISRAELI_OPERATIONS)
                content_source = category_data["content_templates"]
            else:
                category_data = random.choice(NEWS_TOPICS)
                content_source = CONTENT_TEMPLATES
            
            category_name = category_data["category"]
            topic = random.choice(category_data["topics"])
            
            # Create content
            title = topic.replace("{neighborhood}", location_data["neighborhood"]).replace("{city}", location_data["city"])
            
            # For Israeli operations, use their specific content templates
            if is_israeli_op:
                content = random.choice(content_source).replace("{neighborhood}", location_data["neighborhood"]).replace("{city}", location_data["city"])
            else:
                # Regular content creation
                content = random.choice(content_source).replace("{neighborhood}", location_data["neighborhood"]).replace("{city}", location_data["city"])
                
                # Add some additional context based on category sometimes
                additional_contexts = [
                    f"Residents in {location_data['neighborhood']} are encouraged to participate.",
                    f"Updates will be shared with the {location_data['city']} community as they become available.",
                    f"For more information, contact the {location_data['neighborhood']} community center.",
                    f"This initiative aims to support families in {location_data['neighborhood']} during these challenging times.",
                    f"Multiple organizations are coordinating efforts in {location_data['neighborhood']} to maximize impact.",
                ]
                
                if random.random() > 0.5:
                    content += " " + random.choice(additional_contexts)
            
            # Select random tags (2-5)
            num_tags = random.randint(2, 5)
            selected_tags = random.sample(PALESTINE_TAGS, num_tags)
            
            # For Israeli ops, add some specific tags
            if is_israeli_op:
                op_tags = ["military", "conflict", "security", "emergency", "alert", "operation"]
                selected_tags.extend(random.sample(op_tags, min(2, len(op_tags))))
            
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
                    media_urls.append(select_image_for_post(category_name))
            
            # Randomize post date: May 8, 9, or 10
            day = random.choice([8, 9, 10])
            post_date = datetime.datetime(2025, 5, day, 
                                          hour=random.randint(0, 23),
                                          minute=random.randint(0, 59))
            
            # Create post with randomized metrics
            post = Post.objects.create(
                author=user,
                title=title,
                content=content,
                category=category_name,
                location=location,
                media_urls=media_urls,
                created_at=post_date,
                honesty_score=random.randint(60, 100),
                upvotes=random.randint(0, 100),
                downvotes=random.randint(0, 20),
                is_verified_location=random.random() > 0.2,
                taken_within_app=random.random() > 0.3,
                tags=selected_tags,
                is_anonymous=is_israeli_op or random.random() < 0.15,  # More anonymous posts for Israeli ops
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
            
            post_count += 1
            print(f"Created post {post_count}/{num_posts} (May {day}): {title}")
    
    print(f"Created {len(created_threads)} threads")
    print(f"Created {len(users)} users with profile pictures and random followers")
    print("Palestine/Israel data generation completed successfully!")

if __name__ == "__main__":
    # Get number of users and posts from command line argument or use default
    num_users = 20
    num_posts = 100
    
    if len(sys.argv) > 1:
        try:
            num_posts = int(sys.argv[1])
        except ValueError:
            print("Invalid number of posts. Using default of 100.")
    
    if len(sys.argv) > 2:
        try:
            num_users = int(sys.argv[2])
        except ValueError:
            print("Invalid number of users. Using default of 20.")
    
    create_palestine_data(num_users, num_posts)