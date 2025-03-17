from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin

class AccountManager(BaseUserManager):
    def create_user(self, email, first_name, last_name, password=None, google_id=None):
        if not email:
            raise ValueError("Users must have an email address")
        
        user = self.model(
            email=self.normalize_email(email),
            first_name=first_name,
            last_name=last_name,
            google_id=google_id
        )

        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()  # For Google users

        user.save(using=self._db)
        return user

    def create_superuser(self, email, first_name, last_name, password):
        user = self.create_user(email, first_name, last_name, password)
        user.is_admin = True
        user.save(using=self._db)
        return user

class Account(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    profile_picture = models.ImageField(upload_to="profile_pics/", blank=True, null=True)
    google_id = models.CharField(max_length=255, blank=True, null=True, unique=True)  # To track Google users
    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)

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
