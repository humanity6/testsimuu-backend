from django.db import models
from users.models import User
from questions.models import Topic, Question
from assessment.models import UserAnswer
from exams.models import Exam

class AIContentAlert(models.Model):
    """Model for AI-generated alerts about content that may need updating."""
    ALERT_TYPE_CHOICES = (
        ('TOPIC_UPDATE', 'Topic Update'),
        ('QUESTION_UPDATE_SUGGESTION', 'Question Update Suggestion'),
    )
    PRIORITY_CHOICES = (
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
    )
    STATUS_CHOICES = (
        ('NEW', 'New'),
        ('UNDER_REVIEW', 'Under Review'),
        ('ACTION_TAKEN', 'Action Taken'),
        ('DISMISSED', 'Dismissed'),
    )

    alert_type = models.CharField(max_length=30, choices=ALERT_TYPE_CHOICES, db_index=True)
    related_topic = models.ForeignKey(Topic, null=True, blank=True, on_delete=models.SET_NULL, related_name='ai_alerts')
    related_question = models.ForeignKey(Question, null=True, blank=True, on_delete=models.SET_NULL, related_name='ai_alerts')
    summary_of_potential_change = models.TextField()
    detailed_explanation = models.TextField(null=True, blank=True)
    source_urls = models.JSONField(null=True, blank=True)
    ai_confidence_score = models.FloatField(null=True, blank=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='MEDIUM', db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='NEW', db_index=True)
    admin_notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    reviewed_by_admin = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='reviewed_ai_alerts')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    action_taken = models.TextField(null=True, blank=True)

    class Meta:
        db_table = 'ai_integration_aicontentalert'

    def __str__(self):
        return f"{self.alert_type} - {self.created_at} - {self.priority}"

class AIFeedbackTemplate(models.Model):
    """Model for templates used to generate AI feedback."""
    QUESTION_TYPE_CHOICES = (
        ('OPEN_ENDED', 'Open Ended Question'),
        ('CALCULATION', 'Calculation Question'),
    )

    template_name = models.CharField(max_length=100, unique=True)
    question_type = models.CharField(max_length=20, choices=QUESTION_TYPE_CHOICES)
    template_content = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ai_integration_aifeedbacktemplate'

    def __str__(self):
        return f"{self.template_name} - {self.question_type}"

class AIEvaluationLog(models.Model):
    """Model for logging AI evaluation of user answers."""
    user_answer = models.ForeignKey(UserAnswer, on_delete=models.CASCADE, related_name='ai_evaluation_logs')
    prompt_used = models.TextField()
    ai_response = models.TextField()
    processing_time_ms = models.IntegerField()
    success = models.BooleanField()
    error_message = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'ai_integration_aievaluationlog'

    def __str__(self):
        return f"AI Evaluation for {self.user_answer.user.username} - {self.created_at}"

class ContentUpdateScanConfig(models.Model):
    """Configuration for web content update scanning."""
    FREQUENCY_CHOICES = (
        ('DAILY', 'Daily'),
        ('WEEKLY', 'Weekly'),
        ('MONTHLY', 'Monthly'),
        ('QUARTERLY', 'Quarterly'),
    )
    
    name = models.CharField(max_length=100)
    exams = models.ManyToManyField(Exam, related_name='content_update_configs')
    frequency = models.CharField(max_length=10, choices=FREQUENCY_CHOICES, default='WEEKLY')
    max_questions_per_scan = models.IntegerField(default=20, help_text="Maximum number of questions to check per scan")
    is_active = models.BooleanField(default=True)
    prompt_template = models.TextField(help_text="Template for the AI prompt")
    last_run = models.DateTimeField(null=True, blank=True)
    next_scheduled_run = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='created_scan_configs')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'ai_integration_contentupdatescanconfig'
        verbose_name = "Content Update Scan Configuration"
        verbose_name_plural = "Content Update Scan Configurations"
    
    def __str__(self):
        return f"{self.name} - {self.frequency}"

class ContentUpdateScanLog(models.Model):
    """Log of content update scans."""
    scan_config = models.ForeignKey(ContentUpdateScanConfig, on_delete=models.CASCADE, related_name='scan_logs')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(null=True, blank=True)
    topics_scanned = models.JSONField(null=True, blank=True)
    questions_scanned = models.IntegerField(default=0)
    alerts_generated = models.IntegerField(default=0)
    status = models.CharField(max_length=20, default='PENDING', choices=(
        ('PENDING', 'Pending'),
        ('IN_PROGRESS', 'In Progress'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed'),
    ))
    error_message = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'ai_integration_contentupdatescanlog'
        verbose_name = "Content Update Scan Log"
        verbose_name_plural = "Content Update Scan Logs"
    
    def __str__(self):
        return f"Scan for {self.scan_config.name} - {self.start_time}"

class ChatbotConversation(models.Model):
    """
    Stores a conversation session between a user and the AI chatbot.
    This maintains conversational context across multiple interactions.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='chatbot_conversations')
    title = models.CharField(max_length=200, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'ai_integration_chatbotconversation'
        verbose_name = "Chatbot Conversation"
        verbose_name_plural = "Chatbot Conversations"
    
    def __str__(self):
        return f"Conversation with {self.user.username} - {self.created_at}"

class ChatbotMessage(models.Model):
    """
    Stores individual messages in a chatbot conversation, maintaining conversation history.
    """
    ROLE_CHOICES = (
        ('USER', 'User'),
        ('ASSISTANT', 'Assistant'),
        ('SYSTEM', 'System'),
    )
    
    conversation = models.ForeignKey(ChatbotConversation, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    processing_time_ms = models.IntegerField(null=True, blank=True)
    
    class Meta:
        db_table = 'ai_integration_chatbotmessage'
        verbose_name = "Chatbot Message"
        verbose_name_plural = "Chatbot Messages"
        ordering = ['created_at']
    
    def __str__(self):
        return f"{self.role} message in conversation {self.conversation.id}" 