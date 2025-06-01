from rest_framework import serializers
from .models import Exam, ExamTranslation
from .services import ExamTranslationService

class ExamSerializer(serializers.ModelSerializer):
    translated_description = serializers.SerializerMethodField()
    
    class Meta:
        model = Exam
        fields = ['id', 'name', 'slug', 'description', 'translated_description', 'parent_exam_id', 'display_order']
    
    def get_translated_description(self, obj):
        """
        Get translated description based on request language preference.
        """
        request = self.context.get('request')
        if not request:
            return obj.description
        
        # Get language from request headers, query params, or default to 'en'
        language_code = request.META.get('HTTP_ACCEPT_LANGUAGE', 'en')
        if language_code and '-' in language_code:
            language_code = language_code.split('-')[0].lower()
        
        # Check for explicit language parameter
        lang_param = request.query_params.get('lang')
        if lang_param:
            language_code = lang_param.lower()
        
        # If it's English or no description, return original
        if language_code == 'en' or not obj.description:
            return obj.description
        
        # Get translated description
        translated_desc = obj.get_translated_description(language_code)
        
        # If translation doesn't exist and we have AI service, trigger translation
        if translated_desc == obj.description and language_code in ExamTranslationService.LANGUAGE_NAMES:
            try:
                # Trigger async translation (non-blocking)
                ExamTranslationService.translate_exam_description(obj, language_code)
            except Exception:
                pass  # Fail silently, return original description
        
        return translated_desc

class ExamDetailSerializer(serializers.ModelSerializer):
    parent_exam = serializers.SerializerMethodField()
    sub_exams = ExamSerializer(many=True, read_only=True)
    translated_description = serializers.SerializerMethodField()
    available_translations = serializers.SerializerMethodField()
    
    class Meta:
        model = Exam
        fields = ['id', 'name', 'slug', 'description', 'translated_description', 'parent_exam', 'parent_exam_id',
                 'sub_exams', 'display_order', 'is_active', 'created_at', 'updated_at', 'available_translations']
    
    def get_parent_exam(self, obj):
        if obj.parent_exam:
            return ExamSerializer(obj.parent_exam, context=self.context).data
        return None
    
    def get_translated_description(self, obj):
        """
        Get translated description based on request language preference.
        """
        request = self.context.get('request')
        if not request:
            return obj.description
        
        # Get language from request headers, query params, or default to 'en'
        language_code = request.META.get('HTTP_ACCEPT_LANGUAGE', 'en')
        if language_code and '-' in language_code:
            language_code = language_code.split('-')[0].lower()
        
        # Check for explicit language parameter
        lang_param = request.query_params.get('lang')
        if lang_param:
            language_code = lang_param.lower()
        
        # If it's English or no description, return original
        if language_code == 'en' or not obj.description:
            return obj.description
        
        # Get translated description
        translated_desc = obj.get_translated_description(language_code)
        
        # If translation doesn't exist and we have AI service, trigger translation
        if translated_desc == obj.description and language_code in ExamTranslationService.LANGUAGE_NAMES:
            try:
                # Trigger async translation (non-blocking)
                ExamTranslationService.translate_exam_description(obj, language_code)
            except Exception:
                pass  # Fail silently, return original description
        
        return translated_desc
    
    def get_available_translations(self, obj):
        """
        Get list of available translations for this exam.
        """
        translations = ExamTranslation.objects.filter(
            exam=obj, 
            translation_status='COMPLETED'
        ).values_list('language_code', flat=True)
        
        # Always include English as available
        available = ['en'] + list(translations)
        return list(set(available))  # Remove duplicates


class ExamTranslationSerializer(serializers.ModelSerializer):
    language_name = serializers.SerializerMethodField()
    
    class Meta:
        model = ExamTranslation
        fields = ['id', 'exam', 'language_code', 'language_name', 'translated_description', 
                 'translation_status', 'translated_at', 'translation_method']
        read_only_fields = ['id', 'translated_at']
    
    def get_language_name(self, obj):
        """Get the full language name for the language code."""
        return ExamTranslationService.LANGUAGE_NAMES.get(obj.language_code, obj.language_code) 