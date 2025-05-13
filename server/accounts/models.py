from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
import os
import uuid
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken
from firebase_admin import firestore, credentials, initialize_app
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db import transaction
import logging

def user_profile_path(instance, filename):
    # Get the file extension
    ext = filename.split('.')[-1] if '.' in filename else ''
    # Generate unique filename with UUID
    filename = f"{uuid.uuid4()}.{ext}"
    # Return the upload path
    return os.path.join('profile_pics', str(instance.id), filename)

def user_cover_photo_path(instance, filename):
    # Get the file extension
    ext = filename.split('.')[-1] if '.' in filename else ''
    # Generate unique filename with UUID
    filename = f"{uuid.uuid4()}.{ext}"
    # Return the upload path
    return os.path.join('cover_photos', str(instance.user.id), filename)

def sync_user_to_firestore(user, update_online=None):
    """
    Sync a Django Account instance to Firestore 'users' collection.
    If update_online is not None, force isOnline to that value.
    """
    try:
        # Only initialize once
        if not hasattr(sync_user_to_firestore, "_firebase_initialized"):
            cred_path = getattr(settings, 'FIREBASE_CRED_PATH', '/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json')
            if not firestore.client._apps:
                cred = credentials.Certificate(cred_path)
                initialize_app(cred)
            sync_user_to_firestore._firebase_initialized = True

        db = firestore.client()
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'avatarUrl': user.profile_picture.url if user.profile_picture else '',
            'isOnline': update_online if update_online is not None else False,
        }
        # Try to get profile data
        try:
            if hasattr(user, 'profile'):
                user_data.update({
                    'username': user.profile.username,
                    'bio': user.profile.bio,
                    'honesty_score': user.profile.honesty_score,
                })
        except:
            pass
            
        db.collection('users').document(str(user.id)).set(user_data)
    except Exception as e:
        logging.getLogger(__name__).error(f"Failed to sync user to Firestore: {e}")

class AccountManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        
        # Set last_login automatically if not provided
        if 'last_login' not in extra_fields:
            extra_fields['last_login'] = timezone.now()
            
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, first_name, last_name, password):
        user = self.create_user(email, password, first_name=first_name, last_name=last_name, is_verified=True)
        user.is_admin = True
        user.save(using=self._db)
        return user

class Account(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    profile_picture = models.ImageField(upload_to=user_profile_path, blank=True, null=True)
    google_id = models.CharField(max_length=255, blank=True, null=True)  # Google ID field (remove unique=True)
    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)  # Changed from auto_now_add to default
    last_login = models.DateTimeField(default=timezone.now)

    objects = AccountManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    def __str__(self):
        return self.email

    @property
    def is_staff(self):
        return self.is_admin

    def get_tokens(self):
        """Generate JWT tokens for the user"""
        refresh = RefreshToken.for_user(self)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # Sync to Firestore on every save (create/update)
        sync_user_to_firestore(self)

    def set_online(self):
        sync_user_to_firestore(self, update_online=True)

    def set_offline(self):
        sync_user_to_firestore(self, update_online=False)

class VerificationCode(models.Model):
    user = models.ForeignKey(Account, on_delete=models.CASCADE, related_name='verification_codes')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-created_at']

# Activity Status Choices
ACTIVITY_STATUS_CHOICES = [
    ('online', 'Online'),
    ('offline', 'Offline'),
    ('away', 'Away'),
    ('do_not_disturb', 'Do Not Disturb'),
]

class UserProfile(models.Model):
    user = models.OneToOneField(Account, on_delete=models.CASCADE, related_name='profile')
    username = models.CharField(max_length=30, unique=True)
    bio = models.TextField(blank=True, max_length=500)
    location = models.CharField(max_length=100, blank=True)
    website = models.URLField(blank=True)
    honesty_score = models.IntegerField(default=0)  # 0-100 score
    cover_photo = models.ImageField(upload_to=user_cover_photo_path, blank=True, null=True)
    activity_status = models.CharField(max_length=15, choices=ACTIVITY_STATUS_CHOICES, default='offline')
    is_verified = models.BooleanField(default=False)  # Blue check mark verification
    followers = models.ManyToManyField('self', symmetrical=False, related_name='following', blank=True)
    interests = models.JSONField(blank=True, null=True)  # Store interests as a list of strings
    last_active = models.DateTimeField(default=timezone.now)
    saved_posts = models.ManyToManyField('posts.Post', related_name='saved_by_profiles', blank=True)

    def __str__(self):
        return f"{self.user.email} - @{self.username}"
    
    @property
    def followers_count(self):
        return self.followers.count()
    
    @property
    def following_count(self):
        return Account.objects.filter(profile__followers=self).count()
    
    @property
    def posts_count(self):
        # You would implement this based on your Post model
        # For now, returning 0 as a placeholder
        return 0
    
    @property
    def saved_posts_count(self):
        return self.saved_posts.count() if hasattr(self, 'saved_posts') else 0
    
    @property
    def upvoted_posts_count(self):
        # Placeholder for upvoted posts count
        return 0
    
    @property
    def comments_count(self):
        # Placeholder for comments count
        return 0

# Signal to create a UserProfile when a new Account is created
@receiver(post_save, sender=Account)
def create_user_profile(sender, instance, created, **kwargs):
    """Create a user profile when a new account is created."""
    if created:
        # Use a transaction for reliability
        with transaction.atomic():
            try:
                # Check if profile already exists (shouldn't happen, but just in case)
                UserProfile.objects.get(user=instance)
                logging.getLogger(__name__).info(f"Profile already exists for user: {instance.email}")
            except UserProfile.DoesNotExist:
                # Create a default username from the email (remove domain part)
                default_username = instance.email.split('@')[0]
                
                # Ensure username is unique by appending numbers if needed
                username = default_username
                counter = 1
                while UserProfile.objects.filter(username=username).exists():
                    username = f"{default_username}{counter}"
                    counter += 1
                
                # Create the profile with the unique username
                profile = UserProfile.objects.create(
                    user=instance,
                    username=username
                )
                logging.getLogger(__name__).info(f"Created profile for user: {instance.email} with username: {username}")

# Signal to save UserProfile when Account is updated
@receiver(post_save, sender=Account)
def save_user_profile(sender, instance, created, **kwargs):
    """Update user profile when account is updated."""
    if not created:  # Only when updating, not creating
        try:
            if hasattr(instance, 'profile'):
                instance.profile.save()
                logging.getLogger(__name__).debug(f"Updated profile for user: {instance.email}")
            else:
                # If somehow the profile doesn't exist, create it
                logging.getLogger(__name__).warning(f"Profile missing for existing account: {instance.email}. Creating one now.")
                create_user_profile(sender, instance, True, **kwargs)
        except Exception as e:
            logging.getLogger(__name__).error(f"Error saving profile for user {instance.email}: {e}")
