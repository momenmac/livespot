"""
Django management command to sync all users from your Django Account model to Firestore users collection.
Run with: python manage.py sync_users_to_firestore
"""

from django.core.management.base import BaseCommand
from accounts.models import Account
import firebase_admin
from firebase_admin import credentials, firestore
from django.conf import settings

class Command(BaseCommand):
    help = 'Sync all users from Django Account model to Firestore users collection'

    def handle(self, *args, **options):
        # Use your actual service account path
        FIREBASE_CRED_PATH = getattr(
            settings,
            'FIREBASE_CRED_PATH',
            '/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json'
        )

        # Initialize Firebase app if not already initialized
        if hasattr(firebase_admin, '_apps') and isinstance(firebase_admin._apps, dict):
            if not firebase_admin._apps:
                cred = credentials.Certificate(FIREBASE_CRED_PATH)
                firebase_admin.initialize_app(cred)
        else:
            raise RuntimeError(
                f"firebase_admin._apps is not a dict! Type: {type(getattr(firebase_admin, '_apps', None))}. "
                "Check your imports: do not import firebase_admin.initialize_app as firebase_admin."
            )
        db = firestore.client()

        users_synced = 0
        for user in Account.objects.all():
            user_data = {
                'id': str(user.id),
                'name': f"{user.first_name} {user.last_name}".strip(),
                'email': user.email,
                'avatarUrl': user.profile_picture.url if user.profile_picture else '',
                'isOnline': False,
            }
            db.collection('users').document(str(user.id)).set(user_data)
            users_synced += 1

        self.stdout.write(self.style.SUCCESS(f'Successfully synced {users_synced} users to Firestore.'))
