from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    TriggerUserAnswerEvaluation,
    TriggerBatchEvaluation,
)
from .admin_views import (
    AdminAIFeedbackTemplateViewSet,
    AdminAIEvaluationLogViewSet,
    AdminChatbotConversationViewSet,
    AdminChatbotMessageViewSet,
    AdminAIContentAlertViewSet,
    AdminContentUpdateScanConfigViewSet,
    AdminContentUpdateScanLogViewSet,
)

# Create router for admin viewsets
router = DefaultRouter()

# Content alerts (using dedicated admin viewset)
router.register(r'content-alerts', AdminAIContentAlertViewSet, basename='admin-content-alert')

# Content scan configurations (using dedicated admin viewset)  
router.register(r'content-scan-configs', AdminContentUpdateScanConfigViewSet, basename='admin-scan-config')

# Content scan logs (using dedicated admin viewset)
router.register(r'content-scan-logs', AdminContentUpdateScanLogViewSet, basename='admin-scan-log')

# AI Feedback Templates (admin viewset)
router.register(r'feedback-templates', AdminAIFeedbackTemplateViewSet, basename='admin-feedback-template')

# AI Evaluation Logs (admin viewset)
router.register(r'evaluation-logs', AdminAIEvaluationLogViewSet, basename='admin-evaluation-log')

# Chatbot administration (admin viewsets)
router.register(r'chatbot/conversations', AdminChatbotConversationViewSet, basename='admin-chatbot-conversation')
router.register(r'chatbot/messages', AdminChatbotMessageViewSet, basename='admin-chatbot-message')

urlpatterns = [
    # Include router URLs
    path('', include(router.urls)),
    
    # AI evaluation triggers (already admin-only in main views)
    path('evaluate/answer/', TriggerUserAnswerEvaluation.as_view(), name='admin-ai-evaluate-answer'),
    path('evaluate/batch/', TriggerBatchEvaluation.as_view(), name='admin-ai-evaluate-batch'),
] 