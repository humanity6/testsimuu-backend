from rest_framework import serializers
from django.utils import timezone
from .models import (
    AIContentAlert, 
    AIEvaluationLog, 
    AIFeedbackTemplate,
    ContentUpdateScanConfig,
    ContentUpdateScanLog,
    ChatbotConversation,
    ChatbotMessage
)
from users.models import User
from assessment.models import UserAnswer
from exams.models import Exam
from questions.models import Topic, Question
from django.core.validators import RegexValidator


class AIContentAlertSerializer(serializers.ModelSerializer):
    reviewed_by_admin_username = serializers.SerializerMethodField()
    related_topic_name = serializers.SerializerMethodField()
    related_question_text = serializers.SerializerMethodField()
    
    class Meta:
        model = AIContentAlert
        fields = [
            'id', 'alert_type', 'related_topic', 'related_topic_name',
            'related_question', 'related_question_text', 'summary_of_potential_change',
            'detailed_explanation', 'source_urls', 'ai_confidence_score', 
            'priority', 'status', 'admin_notes', 'created_at',
            'reviewed_by_admin', 'reviewed_by_admin_username', 'reviewed_at',
            'action_taken'
        ]
        read_only_fields = [
            'id', 'alert_type', 'related_topic', 'related_topic_name',
            'related_question', 'related_question_text', 'summary_of_potential_change',
            'detailed_explanation', 'source_urls', 'ai_confidence_score', 
            'created_at', 'reviewed_by_admin_username'
        ]
    
    def get_reviewed_by_admin_username(self, obj):
        if obj.reviewed_by_admin:
            return obj.reviewed_by_admin.username
        return None
    
    def get_related_topic_name(self, obj):
        if obj.related_topic:
            return obj.related_topic.name
        return None
    
    def get_related_question_text(self, obj):
        if obj.related_question:
            return obj.related_question.text[:100]
        return None


class AIContentAlertCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIContentAlert
        fields = [
            'alert_type', 'related_topic', 'related_question', 
            'summary_of_potential_change', 'detailed_explanation', 
            'source_urls', 'ai_confidence_score', 'priority', 'status'
        ]


class AIContentAlertUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIContentAlert
        fields = ['status', 'admin_notes', 'priority', 'action_taken']
    
    def update(self, instance, validated_data):
        # Set reviewed_by_admin and reviewed_at when status changes
        if 'status' in validated_data and instance.status != validated_data['status']:
            current_user = self.context['request'].user
            validated_data['reviewed_by_admin'] = current_user
            validated_data['reviewed_at'] = timezone.now()
        
        return super().update(instance, validated_data)


class UserAnswerEvaluationSerializer(serializers.Serializer):
    """Serializer for triggering evaluation for a specific user answer."""
    user_answer_id = serializers.IntegerField()

    def validate_user_answer_id(self, value):
        """Validate that the user answer exists and is eligible for AI evaluation."""
        try:
            user_answer = UserAnswer.objects.get(id=value)
        except UserAnswer.DoesNotExist:
            raise serializers.ValidationError("User answer not found.")
        
        # Check if question type is eligible for AI evaluation
        if user_answer.question.question_type not in ['OPEN_ENDED', 'CALCULATION']:
            raise serializers.ValidationError(
                f"Question type '{user_answer.question.question_type}' is not eligible for AI evaluation. "
                "Only OPEN_ENDED and CALCULATION questions can be evaluated by AI."
            )
        
        return value


class AIExplanationRequestSerializer(serializers.Serializer):
    """Serializer for AI explanation request."""
    question_id = serializers.CharField(required=True)
    user_answer = serializers.CharField(required=True)
    question_type = serializers.CharField(required=True, validators=[
        RegexValidator(
            regex='^(MCQ|OPEN_ENDED|CALCULATION)$',
            message='question_type must be one of: MCQ, OPEN_ENDED, CALCULATION'
        )
    ])
    language = serializers.CharField(required=False, default="en")


class AIFeedbackTemplateSerializer(serializers.ModelSerializer):
    """Serializer for AIFeedbackTemplate model."""
    
    class Meta:
        model = AIFeedbackTemplate
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class AIEvaluationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIEvaluationLog
        fields = [
            'id', 'user_answer', 'prompt_used', 'ai_response',
            'processing_time_ms', 'success', 'error_message', 'created_at'
        ]
        read_only_fields = fields


class ExamSerializer(serializers.ModelSerializer):
    """Simple Exam serializer for nested representation."""
    class Meta:
        model = Exam
        fields = ['id', 'name', 'slug']
        read_only_fields = fields


class ContentUpdateScanConfigSerializer(serializers.ModelSerializer):
    """Serializer for ContentUpdateScanConfig model."""
    created_by_username = serializers.SerializerMethodField()
    exams_detail = ExamSerializer(source='exams', many=True, read_only=True)
    
    class Meta:
        model = ContentUpdateScanConfig
        fields = [
            'id', 'name', 'exams', 'exams_detail', 'frequency', 
            'max_questions_per_scan', 'is_active', 'prompt_template',
            'last_run', 'next_scheduled_run', 'created_by', 'created_by_username',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_by', 'created_by_username', 'last_run', 'next_scheduled_run', 'created_at', 'updated_at']
    
    def get_created_by_username(self, obj):
        if obj.created_by:
            return obj.created_by.username
        return None
    
    def validate_prompt_template(self, value):
        """Validate that the prompt template contains required placeholders."""
        required_placeholders = ['{topic_name}', '{questions_data}', '{web_search_results}']
        
        for placeholder in required_placeholders:
            if placeholder not in value:
                raise serializers.ValidationError(
                    f"The prompt template must contain the '{placeholder}' placeholder."
                )
        
        return value


class ContentUpdateScanLogSerializer(serializers.ModelSerializer):
    """Serializer for ContentUpdateScanLog model."""
    scan_config_name = serializers.SerializerMethodField()
    duration_seconds = serializers.SerializerMethodField()
    
    class Meta:
        model = ContentUpdateScanLog
        fields = [
            'id', 'scan_config', 'scan_config_name', 'start_time', 'end_time',
            'duration_seconds', 'topics_scanned', 'questions_scanned',
            'alerts_generated', 'status', 'error_message'
        ]
        read_only_fields = fields
    
    def get_scan_config_name(self, obj):
        return obj.scan_config.name if obj.scan_config else None
    
    def get_duration_seconds(self, obj):
        if obj.start_time and obj.end_time:
            return (obj.end_time - obj.start_time).total_seconds()
        return None


class ChatbotMessageSerializer(serializers.ModelSerializer):
    """Serializer for ChatbotMessage model."""
    
    class Meta:
        model = ChatbotMessage
        fields = ['id', 'role', 'content', 'created_at', 'processing_time_ms']
        read_only_fields = ['id', 'created_at', 'processing_time_ms']


class ChatbotConversationSerializer(serializers.ModelSerializer):
    """Serializer for ChatbotConversation model."""
    messages = ChatbotMessageSerializer(many=True, read_only=True)
    
    class Meta:
        model = ChatbotConversation
        fields = ['id', 'user', 'title', 'created_at', 'updated_at', 'is_active', 'messages']
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']
        
    def to_representation(self, instance):
        """
        Override to_representation to filter out system messages 
        and only include a limited number of recent messages.
        """
        representation = super().to_representation(instance)
        
        # Get limit from context or use default
        limit = self.context.get('message_limit', 20)
        
        # Filter out system messages and limit to the most recent messages
        if 'messages' in representation:
            messages = [
                msg for msg in representation['messages'] 
                if msg['role'] != 'SYSTEM'
            ]
            
            # Sort by created_at and take the most recent 'limit' messages
            messages.sort(key=lambda x: x['created_at'], reverse=True)
            messages = messages[:limit]
            messages.sort(key=lambda x: x['created_at'])  # Sort back to chronological
            
            representation['messages'] = messages
            
        return representation


class ChatbotMessageRequestSerializer(serializers.Serializer):
    """Serializer for chatbot message request."""
    message = serializers.CharField(required=True)
    conversation_id = serializers.IntegerField(required=False)


class ChatbotMessageCreateSerializer(serializers.Serializer):
    """Serializer for creating a new chatbot message with language preference."""
    message = serializers.CharField(required=True)
    language = serializers.CharField(required=False, default="en") 