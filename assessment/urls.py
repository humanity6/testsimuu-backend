from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ExamSessionViewSet, UserAnswerViewSet

router = DefaultRouter()
router.register(r'exam-sessions', ExamSessionViewSet, basename='exam-session')
router.register(r'user-answers', UserAnswerViewSet, basename='user-answer')

urlpatterns = [
    path('', include(router.urls)),
] 