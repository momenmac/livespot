from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
import os
import uuid
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

def user_profile_path(instance, filename):
    # Get the file extension
    ext = filename.split('.')[-1] if '.' in filename else ''
    # Generate unique filename with UUID
    filename = f"{uuid.uuid4()}.{ext}"
    # Return the upload path
    return os.path.join('profile_pics', str(instance.id), filename)

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

    objects = AccountManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    # Remove the custom related_names for the ManyToMany fields
    # This avoids conflicts with the PermissionsMixin implementation

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

class VerificationCode(models.Model):
    user = models.ForeignKey(Account, on_delete=models.CASCADE, related_name='verification_codes')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-created_at']
