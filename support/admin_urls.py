from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .admin_views import (
    AdminFAQItemViewSet,
    AdminSupportTicketViewSet
)

router = DefaultRouter()
router.register(r'faq-items', AdminFAQItemViewSet)
router.register(r'tickets', AdminSupportTicketViewSet)

urlpatterns = [
    path('', include(router.urls)),
] 