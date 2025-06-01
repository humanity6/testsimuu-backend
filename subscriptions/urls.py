from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    PricingPlanListView,
    PricingPlanDetailView,
    UserSubscriptionListCreateView,
    UserSubscriptionCancelView,
    ReferralProgramListView,
    ReferralProgramDetailView,
    ReferralCodeApplyView,
    UserReferralListView,
    UserPaymentListView,
    UserPaymentDetailView,
    SumUpWebhookHandlerView,
    BundleSubscriptionCreateView,
    PaymentVerificationView,
    GetAvailablePaymentMethodsView,
    # Admin views are now in admin_urls.py
)
from . import test_views

# Admin viewsets are now in admin_urls.py

urlpatterns = [
    # Pricing plan endpoints
    path('pricing-plans/', PricingPlanListView.as_view(), name='pricing-plan-list'),
    path('pricing-plans/<str:slug>/', PricingPlanDetailView.as_view(), name='pricing-plan-detail'),
    
    # User subscription endpoints
    path('users/me/subscriptions/', UserSubscriptionListCreateView.as_view(), name='user-subscription-list-create'),
    path('users/me/subscriptions/<int:id>/cancel/', UserSubscriptionCancelView.as_view(), name='user-subscription-cancel'),
    
    # Bundle subscription endpoint
    path('users/me/bundles/', BundleSubscriptionCreateView.as_view(), name='bundle-subscription-create'),
    
    # Referral program endpoints
    path('referral-programs/', ReferralProgramListView.as_view(), name='referral-program-list'),
    path('referral-programs/<int:id>/', ReferralProgramDetailView.as_view(), name='referral-program-detail'),
    path('referrals/apply/', ReferralCodeApplyView.as_view(), name='apply-referral-code'),
    path('users/me/referrals/', UserReferralListView.as_view(), name='user-referrals-list'),
    
    # Payment endpoints
    path('users/me/payments/', UserPaymentListView.as_view(), name='user-payment-list'),
    path('users/me/payments/<int:id>/', UserPaymentDetailView.as_view(), name='user-payment-detail'),
    path('payments/verify/', PaymentVerificationView.as_view(), name='payment-verify'),
    path('payments/methods/', GetAvailablePaymentMethodsView.as_view(), name='payment-methods'),
    
    # SumUp webhook
    path('webhooks/sumup/', SumUpWebhookHandlerView.as_view(), name='sumup-webhook'),
    
    # Test endpoints for development and testing
    path('test/webhook-simulation/', test_views.test_webhook_simulation, name='test-webhook-simulation'),
    path('test/payment-status/<str:transaction_id>/', test_views.test_payment_status, name='test-payment-status'),
    path('test/simulate-payment-flow/', test_views.simulate_payment_flow, name='test-simulate-payment-flow'),
    path('test/configuration-status/', test_views.test_configuration_status, name='test-configuration-status'),
    
    # Admin API is now handled by admin_urls.py
] 