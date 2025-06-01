from rest_framework import permissions
from django.contrib.auth import get_user_model

User = get_user_model()

class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow admin users to access the view.
    This ensures a fresh database lookup to get the latest is_staff status,
    which is important for JWT authentication.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            print(f"❌ Admin permission denied: User not authenticated")
            return False
            
        # Force a fresh database lookup to ensure we have latest is_staff status
        try:
            fresh_user = User.objects.get(id=request.user.id)
            has_permission = fresh_user.is_staff
            print(f"🔍 Admin permission check: user={fresh_user.email}, is_staff={fresh_user.is_staff}, result={has_permission}")
            return has_permission
        except User.DoesNotExist:
            print(f"❌ Admin permission denied: User not found in database")
            return False 