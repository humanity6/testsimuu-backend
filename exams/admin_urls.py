from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .admin_views import AdminExamViewSet

router = DefaultRouter()
router.register(r'exams', AdminExamViewSet, basename='admin-exam')

urlpatterns = [
    path('', include(router.urls)),
] 