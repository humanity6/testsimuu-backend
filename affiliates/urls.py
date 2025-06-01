from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    AffiliateProfileView,
    AffiliateLinkViewSet,
    VoucherCodeViewSet,
    ConversionViewSet,
    AffiliatePaymentViewSet,
    AffiliateStatisticsView,
    TrackClickView,
    ApplyVoucherView,
    AffiliatePlansViewSet,
    AffiliateApplicationViewSet,
    AffiliateOpportunitiesView,
    UserAffiliateStatusView
)

# Create a router for ViewSets
router = DefaultRouter()
router.register(r'links', AffiliateLinkViewSet, basename='affiliate-link')
router.register(r'voucher-codes', VoucherCodeViewSet, basename='voucher-code')
router.register(r'conversions', ConversionViewSet, basename='conversion')
router.register(r'payments', AffiliatePaymentViewSet, basename='affiliate-payment')

# Public router for affiliate plans
public_router = DefaultRouter()
public_router.register(r'plans', AffiliatePlansViewSet, basename='affiliate-plan')

# Application router
app_router = DefaultRouter()
app_router.register(r'applications', AffiliateApplicationViewSet, basename='affiliate-application')

urlpatterns = [
    # Affiliate profile endpoints
    path('me/', AffiliateProfileView.as_view(), name='affiliate-profile'),
    path('me/statistics/', AffiliateStatisticsView.as_view(), name='affiliate-statistics'),
    
    # Include router URLs with the 'me/' prefix
    path('me/', include(router.urls)),
    
    # Public endpoints
    path('track-click/', TrackClickView.as_view(), name='track-click'),
    path('apply-voucher/', ApplyVoucherView.as_view(), name='apply-voucher'),
    
    # Public affiliate plans
    path('', include(public_router.urls)),
    
    # Affiliate opportunities and status
    path('opportunities/', AffiliateOpportunitiesView.as_view(), name='affiliate-opportunities'),
    path('status/', UserAffiliateStatusView.as_view(), name='user-affiliate-status'),
    
    # Affiliate applications
    path('', include(app_router.urls)),
] 