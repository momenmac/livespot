#!/usr/bin/env python3
import requests
import json

# Get auth token
print("🔑 Getting authentication token...")
login_response = requests.post('http://127.0.0.1:8000/api/accounts/login/', json={
    'email': 'leila.awad@example.com',
    'password': '1234'
})

if login_response.status_code == 200:
    token = login_response.json()['tokens']['access']
    print("✅ Login successful")
    
    # Test recommendations endpoint
    print("\n🎯 Testing recommendations endpoint...")
    headers = {'Authorization': f'Bearer {token}'}
    
    params = {
        'latitude': 31.9073,
        'longitude': 35.2044,
        'radius': 50,
        'limit': 10
    }
    
    response = requests.get('http://127.0.0.1:8000/api/posts/recommended/', 
                          params=params, headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Success: {data.get('success', False)}")
        if data.get('success'):
            rec_data = data['data']
            print(f"✅ Total posts returned: {len(rec_data['posts'])}")
            print(f"📊 Recommendation info: {rec_data['recommendation_info']}")
            print(f"📍 User location: {rec_data['user_location']}")
            print(f"🔍 Search radius: {rec_data['radius_km']}km")
            print(f"🗓️ Date filter: {rec_data['date_filter']}")
            print("\n🎯 RECOMMENDATIONS ENDPOINT WORKING! 🎯")
        else:
            print("❌ Response not successful")
    else:
        print(f"❌ Error: {response.text}")
else:
    print(f"❌ Login failed: {login_response.text}")
