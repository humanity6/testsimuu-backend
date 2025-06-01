from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    UserRegistrationView,
    UserLoginView,
    UserLogoutView,
    UserProfileView
)
from .preference_views import UserPreferenceView
from rest_framework.routers import DefaultRouter

urlpatterns = [
    # Authentication endpoints
    path('auth/register/', UserRegistrationView.as_view(), name='register'),
    path('auth/login/', UserLoginView.as_view(), name='login'),
    path('auth/logout/', UserLogoutView.as_view(), name='logout'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # User profile endpoints - GET for retrieve, PUT/PATCH for update
    path('users/me/', UserProfileView.as_view(), name='user_profile'),
    
    # User preferences endpoint
    path('users/me/preferences/', UserPreferenceView.as_view(), name='user_preferences'),
] 