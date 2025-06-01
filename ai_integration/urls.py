from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AIContentAlertViewSet,
    TriggerUserAnswerEvaluation,
    TriggerBatchEvaluation,
    GetAIExplanation,
    ContentUpdateScanConfigViewSet,
    ContentUpdateScanLogViewSet,
    ChatbotViewSet
)

# Setup the router for viewsets
router = DefaultRouter()
router.register(r'content-alerts', AIContentAlertViewSet)
router.register(r'content-scan-configs', ContentUpdateScanConfigViewSet)
router.register(r'content-scan-logs', ContentUpdateScanLogViewSet, basename='content-scan-logs')
router.register(r'chatbot/conversations', ChatbotViewSet, basename='chatbot-conversation')

urlpatterns = [
    path('', include(router.urls)),
    path('evaluate/answer/', TriggerUserAnswerEvaluation.as_view(), name='evaluate-user-answer'),
    path('evaluate/batch/', TriggerBatchEvaluation.as_view(), name='evaluate-batch'),
    path('explain/', GetAIExplanation.as_view(), name='get-ai-explanation'),
    path('chatbot/conversations/<int:conversation_id>/messages/', ChatbotViewSet.as_view({'post': 'send_message'}), name='chatbot-message-create'),
] 