from django.urls import path
from .views import (
    TopicListView,
    TopicDetailView,
    QuestionListView,
    QuestionDetailView,
    debug_mcq_choices,
    debug_mcq_choice
)

urlpatterns = [
    # Topic endpoints
    path('topics/', TopicListView.as_view(), name='topic-list'),
    path('topics/<str:slug>/', TopicDetailView.as_view(), name='topic-detail'),
    
    # Question endpoints
    path('questions/', QuestionListView.as_view(), name='question-list'),
    path('questions/<int:id>/', QuestionDetailView.as_view(), name='question-detail'),
    path('debug-mcq/<int:question_id>/', debug_mcq_choices, name='debug-mcq-choices'),
    path('debug-mcq-choice/<int:choice_id>/', debug_mcq_choice, name='debug-mcq-choice'),
] 