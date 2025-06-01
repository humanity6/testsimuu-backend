from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model
from django.db.models import Q

User = get_user_model()


class CaseInsensitiveEmailBackend(ModelBackend):
    """
    Custom authentication backend that allows case-insensitive email authentication.
    """
    
    def authenticate(self, request, username=None, password=None, email=None, **kwargs):
        """
        Authenticate user with case-insensitive email lookup.
        """
        if email is None:
            email = username
            
        if email is None or password is None:
            return None
            
        try:
            # Perform case-insensitive email lookup
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            # Run the default password hasher once to reduce the timing
            # difference between an existing and a non-existing user
            User().set_password(password)
            return None
        except User.MultipleObjectsReturned:
            # If multiple users have the same email (case variations), 
            # get the most recently created one
            user = User.objects.filter(email__iexact=email).order_by('-date_joined').first()
            if not user:
                return None
        
        if user.check_password(password) and self.user_can_authenticate(user):
            return user
        
        return None

    def get_user(self, user_id):
        """
        Get user by ID.
        """
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None 