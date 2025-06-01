from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AdminPricingPlanViewSet,
    AdminUserSubscriptionViewSet,
    AdminPaymentViewSet,
    AdminReferralProgramViewSet,
    AdminUserReferralViewSet
)

# Create router for admin viewsets
router = DefaultRouter()
router.register(r'pricing-plans', AdminPricingPlanViewSet, basename='admin-pricing-plan')
router.register(r'subscriptions', AdminUserSubscriptionViewSet, basename='admin-subscription')
router.register(r'payments', AdminPaymentViewSet, basename='admin-payment')
router.register(r'referral-programs', AdminReferralProgramViewSet, basename='admin-referral-program')
router.register(r'user-referrals', AdminUserReferralViewSet, basename='admin-user-referral')

urlpatterns = [
    path('', include(router.urls)),
] 