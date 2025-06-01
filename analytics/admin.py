from django.contrib import admin
from .models import UserPerformanceRecord, UserProgress, StudySession

@admin.register(UserPerformanceRecord)
class UserPerformanceRecordAdmin(admin.ModelAdmin):
    list_display = ('user', 'topic', 'question_type', 'difficulty', 'date_recorded', 'questions_answered', 'accuracy')
    list_filter = ('question_type', 'difficulty', 'date_recorded')
    search_fields = ('user__username', 'user__email', 'topic__name')
    date_hierarchy = 'date_recorded'

@admin.register(UserProgress)
class UserProgressAdmin(admin.ModelAdmin):
    list_display = ('user', 'topic', 'proficiency_level', 'questions_attempted', 'questions_mastered', 'last_activity_date')
    list_filter = ('proficiency_level',)
    search_fields = ('user__username', 'user__email', 'topic__name')
    date_hierarchy = 'last_activity_date'

@admin.register(StudySession)
class StudySessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'start_time', 'end_time', 'questions_answered', 'correct_answers', 'session_source')
    list_filter = ('session_source',)
    search_fields = ('user__username', 'user__email', 'device_info')
    date_hierarchy = 'start_time' 