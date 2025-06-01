from django.contrib.auth.models import AbstractUser, UserManager
from django.db import models
import uuid

class CustomUserManager(UserManager):
    def _create_user(self, username, email, password, **extra_fields):
        """
        Create and save a user with the given username, email, and password.
        Ensures referral_code is unique and email is normalized to lowercase.
        """
        if not username:
            raise ValueError('The given username must be set')
        
        # Normalize email to lowercase for case-insensitive storage
        if email:
            email = self.normalize_email(email).lower()
        
        # If referral_code not provided, generate a unique one
        if 'referral_code' not in extra_fields:
            while True:
                referral_code = str(uuid.uuid4())[:8]
                if not self.model.objects.filter(referral_code=referral_code).exists():
                    extra_fields['referral_code'] = referral_code
                    break
        
        return super()._create_user(username, email, password, **extra_fields)

    def get_by_natural_key(self, username):
        """
        Override to allow case-insensitive email lookup for authentication.
        """
        return self.get(**{self.model.USERNAME_FIELD + '__iexact': username})

class User(AbstractUser):
    """Custom User model extending Django's AbstractUser."""
    email_verified = models.BooleanField(default=False)
    profile_picture_url = models.URLField(null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gdpr_consent_date = models.DateTimeField(null=True, blank=True)
    referral_code = models.CharField(max_length=20, unique=True, db_index=True)
    last_active = models.DateTimeField(null=True, blank=True, db_index=True)
    time_zone = models.CharField(max_length=50, default='UTC')

    objects = CustomUserManager()
    
    def save(self, *args, **kwargs):
        """
        Override save to ensure email is stored in lowercase for case-insensitive operations.
        """
        if self.email:
            self.email = self.email.lower()
        super().save(*args, **kwargs)
    
    class Meta:
        db_table = 'users_user'
        ordering = ['-date_joined']

class UserPreference(models.Model):
    """User preferences model for storing notification and UI settings."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='preferences')
    notification_settings = models.JSONField()
    ui_preferences = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'users_userpreference' 