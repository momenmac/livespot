import os
import sys
import django

# Add the parent directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Try common Django project naming patterns
possible_settings_modules = [
    'server.settings',
    'config.settings',
    'myproject.settings',
    'app.settings',
    'settings',
]

# Find the correct settings module
settings_module = None
for module in possible_settings_modules:
    try:
        __import__(module.split('.')[0])
        settings_module = module
        break
    except ImportError:
        continue

if settings_module:
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', settings_module)
else:
    # If nothing is found, use default
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'server.settings')

django.setup()

from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from .models import Account

class AccountAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = reverse('register')
        self.login_url = reverse('login')
        self.google_login_url = reverse('google-login')
        
        # Create test user
        self.test_user = Account.objects.create_user(
            email='test@example.com',
            first_name='Test',
            last_name='User',
            password='testpassword123'
        )

    def test_register_user(self):
        data = {
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            'first_name': 'New',
            'last_name': 'User'
        }
        
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)
        self.assertEqual(Account.objects.count(), 2)
        self.assertTrue(Account.objects.filter(email='newuser@example.com').exists())

    def test_login_user(self):
        data = {
            'email': 'test@example.com',
            'password': 'testpassword123'
        }
        
        response = self.client.post(self.login_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)

    def test_google_login(self):
        data = {
            'google_id': '123456789',
            'email': 'googleuser@example.com',
            'first_name': 'Google',
            'last_name': 'User',
            'profile_picture': 'https://example.com/pic.jpg'
        }
        
        response = self.client.post(self.google_login_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)
        self.assertIn('user', response.data)
        self.assertTrue(Account.objects.filter(email='googleuser@example.com').exists())
