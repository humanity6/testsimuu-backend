from django.contrib import admin
from .models import ExamSession, ExamSessionQuestion, UserAnswer, UserAnswerMCQChoice, LearningMaterial

class ExamSessionQuestionInline(admin.TabularInline):
    model = ExamSessionQuestion
    extra = 0
    readonly_fields = ('question', 'display_order', 'question_weight')

class UserAnswerMCQChoiceInline(admin.TabularInline):
    model = UserAnswerMCQChoice
    extra = 1

@admin.register(ExamSession)
class ExamSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'exam', 'title', 'session_type', 'exam_type', 'evaluation_mode', 'start_time', 'status', 'is_timed', 'passed')
    list_filter = ('session_type', 'exam_type', 'evaluation_mode', 'status', 'is_timed', 'passed', 'exam')
    search_fields = ('user__username', 'user__email', 'title')
    date_hierarchy = 'start_time'
    inlines = [ExamSessionQuestionInline]
    autocomplete_fields = ['user', 'exam']
    readonly_fields = ('created_at', 'actual_end_time', 'total_score_achieved', 'passed')

    fieldsets = (
        ('Basic Information', {
            'fields': ('user', 'exam', 'title', 'session_type', 'exam_type')
        }),
        ('Configuration', {
            'fields': ('evaluation_mode', 'is_timed', 'time_limit_seconds', 'topic_ids')
        }),
        ('Timing', {
            'fields': ('start_time', 'end_time_expected', 'actual_end_time')
        }),
        ('Progress & Results', {
            'fields': ('status', 'learning_material_viewed', 'total_score_achieved', 'total_possible_score', 'pass_threshold', 'passed')
        }),
        ('Metadata', {
            'fields': ('metadata', 'created_at'),
            'classes': ('collapse',)
        }),
    )

@admin.register(LearningMaterial)
class LearningMaterialAdmin(admin.ModelAdmin):
    list_display = ('title', 'exam', 'topic', 'material_type', 'duration_minutes', 'display_order', 'is_active')
    list_filter = ('material_type', 'is_active', 'exam', 'topic')
    search_fields = ('title', 'description', 'exam__name', 'topic__name')
    autocomplete_fields = ['exam', 'topic', 'created_by']
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('exam', 'display_order', 'title')

    fieldsets = (
        ('Basic Information', {
            'fields': ('exam', 'topic', 'title', 'description')
        }),
        ('Content', {
            'fields': ('material_type', 'content', 'file_url', 'duration_minutes')
        }),
        ('Display Settings', {
            'fields': ('display_order', 'is_active')
        }),
        ('Metadata', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )

    def save_model(self, request, obj, form, change):
        if not change:  # If creating new object
            obj.created_by = request.user
        super().save_model(request, obj, form, change)

@admin.register(UserAnswer)
class UserAnswerAdmin(admin.ModelAdmin):
    list_display = ('user', 'question_preview', 'exam_session', 'is_correct', 'raw_score', 'evaluation_status', 'submission_time')
    list_filter = ('is_correct', 'evaluation_status', 'question__question_type', 'question__difficulty')
    search_fields = ('user__username', 'user__email', 'question__text')
    date_hierarchy = 'submission_time'
    inlines = [UserAnswerMCQChoiceInline]
    
    def question_preview(self, obj):
        return obj.question.text[:50] + '...' if len(obj.question.text) > 50 else obj.question.text
    question_preview.short_description = 'Question' 