from django.contrib import admin
from .models import Exam, ExamTranslation

@admin.register(Exam)
class ExamAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent_exam', 'is_active', 'display_order', 'translation_count')
    list_filter = ('is_active', 'parent_exam')
    search_fields = ('name', 'description', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    list_editable = ('is_active', 'display_order')
    ordering = ('parent_exam', 'display_order', 'name')
    autocomplete_fields = ['parent_exam']
    
    def translation_count(self, obj):
        """Display the number of completed translations for this exam."""
        return obj.translations.filter(translation_status='COMPLETED').count()
    translation_count.short_description = 'Translations'


@admin.register(ExamTranslation)
class ExamTranslationAdmin(admin.ModelAdmin):
    list_display = ('exam', 'language_code', 'language_name', 'translation_status', 'translated_at', 'translation_method')
    list_filter = ('translation_status', 'language_code', 'translation_method', 'translated_at')
    search_fields = ('exam__name', 'language_code', 'translated_description')
    readonly_fields = ('translated_at',)
    ordering = ('exam', 'language_code')
    autocomplete_fields = ['exam']
    
    def language_name(self, obj):
        """Display the full language name for the language code."""
        from .services import ExamTranslationService
        return ExamTranslationService.LANGUAGE_NAMES.get(obj.language_code, obj.language_code)
    language_name.short_description = 'Language'
    
    def get_queryset(self, request):
        """Optimize queryset to avoid N+1 queries."""
        return super().get_queryset(request).select_related('exam')
    
    actions = ['trigger_retranslation', 'mark_as_completed']
    
    def trigger_retranslation(self, request, queryset):
        """Action to retrigger translation for selected items."""
        from .services import ExamTranslationService
        count = 0
        for translation in queryset:
            result = ExamTranslationService.translate_exam_description(
                translation.exam, 
                translation.language_code
            )
            if result:
                count += 1
        
        self.message_user(request, f"Triggered retranslation for {count} items.")
    trigger_retranslation.short_description = "Retrigger translation for selected items"
    
    def mark_as_completed(self, request, queryset):
        """Action to mark selected translations as completed."""
        count = queryset.update(translation_status='COMPLETED')
        self.message_user(request, f"Marked {count} translations as completed.")
    mark_as_completed.short_description = "Mark selected translations as completed"
