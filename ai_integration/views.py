from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from exam_prep_platform.permissions import IsAdminUser
from django_filters.rest_framework import DjangoFilterBackend
from django.shortcuts import get_object_or_404
from django.utils import timezone
from .models import (
    AIContentAlert, 
    ContentUpdateScanConfig, 
    ContentUpdateScanLog,
    AIFeedbackTemplate,
    AIEvaluationLog,
    ChatbotConversation,
    ChatbotMessage
)
from assessment.models import UserAnswer
from questions.models import Question
from .tasks import (
    evaluate_user_answer, 
    evaluate_user_answers_batch, 
    run_content_update_scan
)
from .serializers import (
    AIContentAlertSerializer, 
    AIContentAlertCreateSerializer,
    AIContentAlertUpdateSerializer,
    UserAnswerEvaluationSerializer,
    AIExplanationRequestSerializer,
    ContentUpdateScanConfigSerializer,
    ContentUpdateScanLogSerializer,
    AIFeedbackTemplateSerializer,
    ChatbotConversationSerializer,
    ChatbotMessageSerializer,
    ChatbotMessageRequestSerializer,
    ChatbotMessageCreateSerializer
)
from .services import AIAnswerEvaluationService, ContentUpdateService, ChatbotService


class AIContentAlertViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing AI content alerts by admin users.
    """
    queryset = AIContentAlert.objects.all().order_by('-created_at')
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['alert_type', 'status', 'priority']
    lookup_field = 'id'
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AIContentAlertCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return AIContentAlertUpdateSerializer
        return AIContentAlertSerializer
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Additional filtering options
        related_topic_id = self.request.query_params.get('related_topic_id')
        if related_topic_id:
            queryset = queryset.filter(related_topic_id=related_topic_id)
            
        related_question_id = self.request.query_params.get('related_question_id')
        if related_question_id:
            queryset = queryset.filter(related_question_id=related_question_id)
            
        # Date range filtering
        created_after = self.request.query_params.get('created_after')
        if created_after:
            queryset = queryset.filter(created_at__gte=created_after)
            
        created_before = self.request.query_params.get('created_before')
        if created_before:
            queryset = queryset.filter(created_at__lte=created_before)
            
        return queryset 


class TriggerUserAnswerEvaluation(APIView):
    """
    API endpoint to manually trigger the evaluation of a specific user answer.
    This is primarily for testing and administrative purposes.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]
    
    def post(self, request, *args, **kwargs):
        serializer = UserAnswerEvaluationSerializer(data=request.data)
        
        if serializer.is_valid():
            user_answer_id = serializer.validated_data['user_answer_id']
            
            # Get the user answer to ensure it exists
            user_answer = get_object_or_404(UserAnswer, id=user_answer_id)
            
            # Reset the evaluation status to PENDING if it was previously evaluated
            if user_answer.evaluation_status in ['EVALUATED', 'ERROR']:
                user_answer.evaluation_status = 'PENDING'
                user_answer.ai_feedback = None
                user_answer.save()
            
            # Queue the evaluation task
            evaluate_user_answer.delay(user_answer_id)
            
            return Response(
                {"detail": f"Evaluation of user answer {user_answer_id} has been queued."},
                status=status.HTTP_202_ACCEPTED
            )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TriggerBatchEvaluation(APIView):
    """
    API endpoint to trigger evaluation for a batch of unevaluated user answers.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]
    
    def post(self, request, *args, **kwargs):
        # Get pending user answers for eligible question types
        pending_answers = UserAnswer.objects.filter(
            evaluation_status='PENDING',
            question__question_type__in=['OPEN_ENDED', 'CALCULATION']
        ).values_list('id', flat=True)[:100]  # Limit to 100 answers per batch
        
        if not pending_answers:
            return Response(
                {"detail": "No pending user answers found for evaluation."},
                status=status.HTTP_200_OK
            )
        
        # Queue the batch evaluation task
        evaluate_user_answers_batch.delay(list(pending_answers))
        
        return Response(
            {
                "detail": f"Evaluation of {len(pending_answers)} user answers has been queued.",
                "count": len(pending_answers)
            },
            status=status.HTTP_202_ACCEPTED
        )


class ContentUpdateScanConfigViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing content update scan configurations.
    """
    queryset = ContentUpdateScanConfig.objects.all().order_by('-created_at')
    serializer_class = ContentUpdateScanConfigSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['frequency', 'is_active']
    
    def perform_create(self, serializer):
        # Set created_by to current user
        serializer.save(created_by=self.request.user)
    
    @action(detail=True, methods=['post'])
    def run_scan(self, request, pk=None):
        """Trigger a content update scan for this configuration."""
        scan_config = self.get_object()
        
        # Queue the scan task
        task = run_content_update_scan.delay(scan_config.id)
        
        # Update last_run time
        scan_config.last_run = timezone.now()
        scan_config.save(update_fields=['last_run'])
        
        return Response(
            {
                "detail": f"Content update scan has been queued for '{scan_config.name}'.",
                "task_id": task.id
            },
            status=status.HTTP_202_ACCEPTED
        )


class ContentUpdateScanLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing content update scan logs.
    """
    queryset = ContentUpdateScanLog.objects.all().order_by('-start_time')
    serializer_class = ContentUpdateScanLogSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status', 'scan_config']


class ChatbotViewSet(viewsets.ModelViewSet):
    """ViewSet for chatbot interactions."""
    queryset = ChatbotConversation.objects.all()
    serializer_class = ChatbotConversationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Filter conversations to only show user's own conversations."""
        return ChatbotConversation.objects.filter(user=self.request.user).order_by('-updated_at')
    
    def perform_create(self, serializer):
        """Set the user when creating a conversation."""
        serializer.save(user=self.request.user)
    
    @action(detail=False, methods=['post'])
    def send_message(self, request, conversation_id=None):
        """Send a message to the chatbot and get a response."""
        serializer = ChatbotMessageCreateSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(
                {"error": "Invalid message data"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        message = serializer.validated_data.get("message", "")
        
        if not message.strip():
            return Response(
                {"error": "Message cannot be empty"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get language preference from request data
        language = serializer.validated_data.get("language", "en")
        
        # Send the message to the chatbot service with language parameter
        response = ChatbotService.send_message(request.user, message, language=language)
        
        if "error" in response:
            return Response(
                {"error": response["error"]}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response(response, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'])
    def conversations(self, request):
        """Get a list of the user's conversations."""
        conversations = ChatbotService.list_user_conversations(request.user)
        
        if isinstance(conversations, dict) and "error" in conversations:
            return Response(
                {"error": conversations["error"]}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response(conversations, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['get'])
    def conversation_history(self, request, pk=None):
        """Get the message history for a specific conversation."""
        history = ChatbotService.get_conversation_history(request.user, conversation_id=pk)
        
        if isinstance(history, dict) and "error" in history:
            return Response(
                {"error": history["error"]}, 
                status=status.HTTP_404_NOT_FOUND if "not found" in history["error"].lower() 
                else status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response(history, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def end_conversation(self, request, pk=None):
        """End a conversation."""
        result = ChatbotService.end_conversation(request.user, pk)
        
        if "error" in result:
            return Response(
                {"error": result["error"]}, 
                status=status.HTTP_404_NOT_FOUND if "not found" in result["error"].lower() 
                else status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response(result, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['delete'])
    def clear_history(self, request, pk=None):
        """Clear all messages in a conversation."""
        try:
            # Get the conversation
            conversation = get_object_or_404(
                ChatbotConversation, 
                id=pk, 
                user=request.user
            )
            
            # Delete all messages in the conversation
            ChatbotMessage.objects.filter(conversation=conversation).delete()
            
            # Update the conversation's updated_at timestamp
            conversation.updated_at = timezone.now()
            conversation.save(update_fields=['updated_at'])
            
            return Response(
                {"message": "Chat history cleared successfully"}, 
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {"error": f"Failed to clear chat history: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['get'])
    def active_conversation(self, request):
        """Get the active conversation or create a new one."""
        conversation = ChatbotService.get_active_conversation(request.user)
        
        if not conversation:
            return Response(
                {"error": "Could not create conversation"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Serialize the conversation with messages
        serializer = self.get_serializer(conversation)
        return Response(serializer.data, status=status.HTTP_200_OK)


class GetAIExplanation(APIView):
    """
    API endpoint for getting AI-generated explanations for user answers.
    This takes a user's answer to a question and generates an AI explanation.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, *args, **kwargs):
        serializer = AIExplanationRequestSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(
                serializer.errors,
                status=status.HTTP_400_BAD_REQUEST
            )
            
        question_id = serializer.validated_data['question_id']
        user_answer = serializer.validated_data['user_answer']
        question_type = serializer.validated_data['question_type']
        language = serializer.validated_data.get('language', 'en')
        
        try:
            # Get the question
            question = Question.objects.filter(id=question_id).first()
            
            if not question:
                return Response(
                    {"error": f"Question with ID {question_id} not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Call the OpenAI API for evaluation
            ai_response, processing_time, error = AIAnswerEvaluationService.evaluate_answer(
                question=question,
                user_answer=user_answer,
                question_type=question_type,
                language=language,
            )
            
            if error:
                # Create evaluation log to track the error (but without user_answer since this is not a formal evaluation)
                try:
                    # For explanation requests, we'll create a minimal log using a temporary UserAnswer object
                    temp_user_answer = UserAnswer.objects.create(
                        user=request.user,
                        question=question,
                        submitted_answer_text=user_answer if question_type in ['OPEN_ENDED'] else None,
                        submitted_calculation_input={'user_input': user_answer} if question_type == 'CALCULATION' else None,
                        max_possible_score=question.points,
                        evaluation_status='ERROR',
                        submission_time=timezone.now(),
                        exam_session=None  # This is just for explanation, not a formal exam
                    )
                    
                    evaluation_log = AIEvaluationLog.objects.create(
                        user_answer=temp_user_answer,
                        prompt_used="AI Explanation Request",
                        ai_response=ai_response or "",
                        processing_time_ms=processing_time or 0,
                        success=False,
                        error_message=error
                    )
                    
                    # Clean up the temporary user answer since this was just for logging
                    temp_user_answer.delete()
                except Exception as log_error:
                    # If logging fails, just continue - don't fail the entire request
                    pass
                
                return Response(
                    {"error": f"AI evaluation failed: {error}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            # Parse the AI response
            feedback, raw_score, is_correct, metadata = AIAnswerEvaluationService.parse_ai_response(
                ai_response, question_type
            )
            
            if feedback is None:
                return Response(
                    {"error": "Failed to parse AI response"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            # Log successful evaluation for monitoring (optional)
            try:
                # Create a temporary UserAnswer for logging purposes
                temp_user_answer = UserAnswer.objects.create(
                    user=request.user,
                    question=question,
                    submitted_answer_text=user_answer if question_type in ['OPEN_ENDED'] else None,
                    submitted_calculation_input={'user_input': user_answer} if question_type == 'CALCULATION' else None,
                    max_possible_score=question.points,
                    evaluation_status='EVALUATED',
                    submission_time=timezone.now(),
                    exam_session=None  # This is just for explanation, not a formal exam
                )
                
                evaluation_log = AIEvaluationLog.objects.create(
                    user_answer=temp_user_answer,
                    prompt_used="AI Explanation Request - Success",
                    ai_response=ai_response,
                    processing_time_ms=processing_time,
                    success=True,
                    error_message=None
                )
                
                # Clean up the temporary user answer since this was just for logging
                temp_user_answer.delete()
            except Exception as log_error:
                # If logging fails, just continue - don't fail the entire request
                pass
            
            return Response({
                "ai_feedback": feedback,
                "score": raw_score,
                "is_correct": is_correct,
                "processing_time_ms": processing_time,
                "metadata": metadata
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response(
                {"error": f"Failed to get AI explanation: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            ) 