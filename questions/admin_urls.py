from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .admin_views import (
    AdminTopicViewSet, AdminQuestionViewSet, 
    AdminTagViewSet, QuestionTagViewSet,
    QuestionMetricsView, QuestionListView,
    QuestionDetailView, TopicListView,
    TopicDetailView
)

router = DefaultRouter()
router.register(r'topics', AdminTopicViewSet, basename='admin-topic')
router.register(r'questions', AdminQuestionViewSet, basename='admin-question')
router.register(r'tags', AdminTagViewSet, basename='admin-tag')
router.register(r'question-tags', QuestionTagViewSet, basename='admin-question-tag')

urlpatterns = [
    path('', include(router.urls)),
    # Metrics endpoint is now available as /api/v1/admin/questions/questions/metrics/ via ViewSet action
    # Remove these conflicting URL patterns since they duplicate the ViewSet routes
    # path('questions/', QuestionListView.as_view(), name='admin-question-list'),
    # path('questions/<int:pk>/', QuestionDetailView.as_view(), name='admin-question-detail'),
    # path('topics/', TopicListView.as_view(), name='admin-topic-list'),
    # path('topics/<int:pk>/', TopicDetailView.as_view(), name='admin-topic-detail'),
] 