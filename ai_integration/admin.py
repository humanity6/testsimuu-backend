from django.contrib import admin
from django.utils.html import format_html
from .models import (
    AIContentAlert, 
    AIFeedbackTemplate, 
    AIEvaluationLog,
    ContentUpdateScanConfig,
    ContentUpdateScanLog,
    ChatbotConversation,
    ChatbotMessage
)

@admin.register(AIContentAlert)
class AIContentAlertAdmin(admin.ModelAdmin):
    list_display = ('alert_type', 'related_topic', 'related_question', 'priority', 'status', 'created_at')
    list_filter = ('alert_type', 'priority', 'status')
    search_fields = ('summary_of_potential_change', 'detailed_explanation')
    readonly_fields = ('created_at',)
    fieldsets = (
        ('Alert Information', {
            'fields': ('alert_type', 'summary_of_potential_change', 'detailed_explanation', 'source_urls', 'ai_confidence_score')
        }),
        ('Related Content', {
            'fields': ('related_topic', 'related_question')
        }),
        ('Status', {
            'fields': ('priority', 'status', 'admin_notes', 'action_taken')
        }),
        ('Review Details', {
            'fields': ('reviewed_by_admin', 'reviewed_at')
        }),
    )

@admin.register(AIFeedbackTemplate)
class AIFeedbackTemplateAdmin(admin.ModelAdmin):
    list_display = ('template_name', 'question_type', 'is_active', 'updated_at')
    list_filter = ('question_type', 'is_active')
    search_fields = ('template_name', 'template_content')
    readonly_fields = ('created_at', 'updated_at')
    fieldsets = (
        ('Template Information', {
            'fields': ('template_name', 'question_type', 'is_active')
        }),
        ('Content', {
            'fields': ('template_content',),
            'classes': ('wide',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )

@admin.register(AIEvaluationLog)
class AIEvaluationLogAdmin(admin.ModelAdmin):
    list_display = ('user_answer', 'processing_time_ms', 'success', 'created_at')
    list_filter = ('success', 'created_at')
    search_fields = ('prompt_used', 'ai_response', 'error_message')
    readonly_fields = ('created_at',)
    fieldsets = (
        ('Evaluation Information', {
            'fields': ('user_answer', 'processing_time_ms', 'success', 'created_at')
        }),
        ('Prompt', {
            'fields': ('prompt_used',),
            'classes': ('wide',)
        }),
        ('Response', {
            'fields': ('ai_response',),
            'classes': ('wide',)
        }),
        ('Error Details', {
            'fields': ('error_message',),
            'classes': ('collapse',)
        }),
    )

@admin.register(ContentUpdateScanConfig)
class ContentUpdateScanConfigAdmin(admin.ModelAdmin):
    list_display = ('name', 'frequency', 'is_active', 'display_exams', 'last_run', 'next_scheduled_run')
    list_filter = ('frequency', 'is_active')
    search_fields = ('name',)
    readonly_fields = ('created_at', 'updated_at', 'last_run', 'next_scheduled_run')
    filter_horizontal = ('exams',)
    fieldsets = (
        ('Configuration', {
            'fields': ('name', 'frequency', 'max_questions_per_scan', 'is_active')
        }),
        ('Exams', {
            'fields': ('exams',),
        }),
        ('Prompt Template', {
            'fields': ('prompt_template',),
            'classes': ('wide',)
        }),
        ('Schedule Information', {
            'fields': ('last_run', 'next_scheduled_run'),
        }),
        ('Metadata', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def display_exams(self, obj):
        """Display exams as a comma-separated list"""
        return format_html(", ".join([f"{exam.name}" for exam in obj.exams.all()[:5]]) + 
                          (" ..." if obj.exams.count() > 5 else ""))
    display_exams.short_description = "Exams"
    
    def save_model(self, request, obj, form, change):
        """Set created_by to current user if not already set"""
        if not change and not obj.created_by:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)

@admin.register(ContentUpdateScanLog)
class ContentUpdateScanLogAdmin(admin.ModelAdmin):
    list_display = ('scan_config', 'start_time', 'end_time', 'status', 'questions_scanned', 'alerts_generated')
    list_filter = ('status', 'start_time')
    search_fields = ('scan_config__name', 'error_message')
    readonly_fields = ('scan_config', 'start_time', 'end_time', 'topics_scanned', 
                      'questions_scanned', 'alerts_generated', 'status', 'error_message')
    fieldsets = (
        ('Scan Information', {
            'fields': ('scan_config', 'start_time', 'end_time', 'status')
        }),
        ('Results', {
            'fields': ('questions_scanned', 'alerts_generated')
        }),
        ('Topics Scanned', {
            'fields': ('topics_scanned',),
            'classes': ('wide',)
        }),
        ('Error Information', {
            'fields': ('error_message',),
            'classes': ('collapse',)
        }),
    )
    
    def has_add_permission(self, request):
        """Disable add permission as logs are created programmatically"""
        return False
    
    def has_change_permission(self, request, obj=None):
        """Disable change permission as logs should not be modified"""
        return False

class ChatbotMessageInline(admin.TabularInline):
    model = ChatbotMessage
    fields = ['role', 'content', 'created_at', 'processing_time_ms']
    readonly_fields = ['created_at', 'processing_time_ms']
    extra = 0
    can_delete = False
    
    def has_add_permission(self, request, obj=None):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False

@admin.register(ChatbotConversation)
class ChatbotConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'title', 'created_at', 'updated_at', 'is_active', 'message_count']
    list_filter = ['is_active', 'created_at', 'updated_at']
    search_fields = ['user__username', 'user__email', 'title']
    readonly_fields = ['created_at', 'updated_at']
    inlines = [ChatbotMessageInline]
    
    def message_count(self, obj):
        return obj.messages.count()
    message_count.short_description = 'Messages'

@admin.register(ChatbotMessage)
class ChatbotMessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'role', 'content_preview', 'created_at', 'processing_time_ms']
    list_filter = ['role', 'created_at']
    search_fields = ['content', 'conversation__user__username']
    readonly_fields = ['created_at', 'processing_time_ms']
    
    def content_preview(self, obj):
        return obj.content[:50] + '...' if len(obj.content) > 50 else obj.content
    content_preview.short_description = 'Content Preview' 