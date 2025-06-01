from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .admin_views import (
    AdminAffiliateApplicationViewSet,
    AdminAffiliateViewSet,
    AdminAffiliatePlanViewSet,
    AdminAffiliateAnalyticsView
)

# Create a router for admin ViewSets
admin_router = DefaultRouter()
admin_router.register(r'applications', AdminAffiliateApplicationViewSet, basename='admin-affiliate-application')
admin_router.register(r'affiliates', AdminAffiliateViewSet, basename='admin-affiliate')
admin_router.register(r'plans', AdminAffiliatePlanViewSet, basename='admin-affiliate-plan')

urlpatterns = [
    # Admin analytics endpoint
    path('analytics/', AdminAffiliateAnalyticsView.as_view(), name='admin-affiliate-analytics'),
    
    # Include admin router URLs
    path('', include(admin_router.urls)),
] 