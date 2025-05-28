import os
import logging
from django.conf import settings
import firebase_admin
from firebase_admin import credentials, storage

logger = logging.getLogger(__name__)

class FirebaseManager:
    """
    Singleton Firebase manager for proper initialization in Django context
    """
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FirebaseManager, cls).__new__(cls)
        return cls._instance
    
    def initialize(self):
        """Initialize Firebase Admin SDK if not already initialized"""
        if self._initialized:
            return True
            
        try:
            # Check if any Firebase app is already initialized
            try:
                firebase_admin.get_app()
                self._initialized = True
                logger.info("Firebase app already initialized")
                return True
            except ValueError:
                # No app exists, need to initialize
                pass
            
            # Get Firebase credentials path
            cred_path = getattr(
                settings, 
                'FIREBASE_CRED_PATH', 
                '/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json'
            )
            
            if not os.path.exists(cred_path):
                logger.error(f"Firebase credentials file not found: {cred_path}")
                return False
            
            # Initialize Firebase
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'livespot-b1eb4.appspot.com'
            })
            
            self._initialized = True
            logger.info("Firebase initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")
            return False
    
    def get_storage_bucket(self):
        """Get Firebase storage bucket"""
        if not self.initialize():
            return None
            
        try:
            return storage.bucket()
        except Exception as e:
            logger.error(f"Error getting storage bucket: {e}")
            return None
    
    def is_initialized(self):
        """Check if Firebase is initialized"""
        return self._initialized

# Global instance
firebase_manager = FirebaseManager()
