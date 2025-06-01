from django.urls import path
from .views import (
    ExamListView,
    ExamDetailView,
    ExamTranslationView,
    BatchTranslationView,
    supported_languages,
    exam_with_translation
)

urlpatterns = [
    # Exam endpoints
    path('exams/', ExamListView.as_view(), name='exam-list'),
    path('exams/<str:slug>/', ExamDetailView.as_view(), name='exam-detail'),
    
    # Translation endpoints
    path('exams/<int:exam_id>/translate/', ExamTranslationView.as_view(), name='exam-translate'),
    path('exams/translate/batch/', BatchTranslationView.as_view(), name='exam-batch-translate'),
    path('exams/supported-languages/', supported_languages, name='supported-languages'),
    path('exams/<str:exam_slug>/with-translation/', exam_with_translation, name='exam-with-translation'),
] 