from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .admin_views import (
    UserListView,
    UserDetailView,
    UserMetricsView,
    UserAdminViewSet,
    SystemSettingsView,
    FAQCategoriesView
)

# Create a router and register the ViewSet
router = DefaultRouter()
router.register(r'users', UserAdminViewSet, basename='admin-user')

urlpatterns = [
    # Include the router URLs
    path('', include(router.urls)),
    
    # Keep legacy endpoints for backward compatibility
    path('users/metrics/', UserMetricsView.as_view(), name='admin-user-metrics-legacy'),
    
    # System settings endpoints
    path('settings/system/', SystemSettingsView.as_view(), name='admin-system-settings'),
    
    # FAQ categories endpoint
    path('support/faq-categories/', FAQCategoriesView.as_view(), name='admin-faq-categories'),
] 