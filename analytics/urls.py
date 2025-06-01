from django.urls import path
from .views import (
    PerformanceSummaryView,
    PerformanceByTopicView,
    PerformanceByDifficultyView,
    PerformanceTrendsView,
    ProgressByTopicView
)

urlpatterns = [
    # Performance endpoints
    path('users/me/performance/summary/', PerformanceSummaryView.as_view(), name='performance-summary'),
    path('users/me/performance/by-topic/', PerformanceByTopicView.as_view(), name='performance-by-topic'),
    path('users/me/performance/by-difficulty/', PerformanceByDifficultyView.as_view(), name='performance-by-difficulty'),
    path('users/me/performance/trends/', PerformanceTrendsView.as_view(), name='performance-trends'),
    
    # Progress endpoints
    path('users/me/progress/by-topic/', ProgressByTopicView.as_view(), name='progress-by-topic'),
] 