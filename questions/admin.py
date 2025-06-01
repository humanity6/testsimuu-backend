from django.contrib import admin
from .models import Topic, Question, MCQChoice, Tag, QuestionTag

class MCQChoiceInline(admin.TabularInline):
    model = MCQChoice
    extra = 4

class QuestionTagInline(admin.TabularInline):
    model = QuestionTag
    extra = 1

@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent_topic', 'display_order', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'description')
    prepopulated_fields = {'slug': ('name',)}

@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    list_display = ('text_preview', 'exam', 'topic', 'question_type', 'difficulty', 'points', 'is_active')
    list_filter = ('exam', 'topic', 'question_type', 'difficulty', 'is_active')
    search_fields = ('text',)
    inlines = [MCQChoiceInline, QuestionTagInline]
    autocomplete_fields = ['exam', 'topic']
    
    def text_preview(self, obj):
        return obj.text[:50] + '...' if len(obj.text) > 50 else obj.text
    text_preview.short_description = 'Question Text'

@admin.register(MCQChoice)
class MCQChoiceAdmin(admin.ModelAdmin):
    list_display = ('choice_text_preview', 'question', 'is_correct', 'display_order')
    list_filter = ('is_correct',)
    search_fields = ('choice_text', 'question__text')
    
    def choice_text_preview(self, obj):
        return obj.choice_text[:50] + '...' if len(obj.choice_text) > 50 else obj.choice_text
    choice_text_preview.short_description = 'Choice Text'

@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ('name', 'description')
    search_fields = ('name', 'description')
    prepopulated_fields = {'slug': ('name',)} 