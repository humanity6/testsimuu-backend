import time
import json
import logging
import requests
from django.conf import settings
from django.utils import timezone
from .models import Exam, ExamTranslation

logger = logging.getLogger(__name__)


class ExamTranslationService:
    """
    Service for translating exam descriptions using OpenAI API.
    """
    
    # Language name mapping for clear AI instructions
    LANGUAGE_NAMES = {
        'de': 'German',
        'fr': 'French',
        'es': 'Spanish',
        'it': 'Italian',
        'pt': 'Portuguese',
        'nl': 'Dutch',
        'ru': 'Russian',
        'pl': 'Polish',
        'tr': 'Turkish',
        'zh': 'Chinese',
        'ja': 'Japanese',
        'ko': 'Korean',
        'ar': 'Arabic',
    }
    
    @classmethod
    def get_or_create_translation(cls, exam, language_code):
        """
        Get existing translation or create a new one for the exam.
        """
        try:
            translation, created = ExamTranslation.objects.get_or_create(
                exam=exam,
                language_code=language_code,
                defaults={
                    'translated_description': '',
                    'translation_status': 'PENDING',
                    'translation_method': 'AI'
                }
            )
            
            # If translation exists but failed before, reset to pending
            if not created and translation.translation_status == 'ERROR':
                translation.translation_status = 'PENDING'
                translation.save()
            
            return translation
        except Exception as e:
            logger.error(f"Error creating translation for exam {exam.id}: {str(e)}")
            return None
    
    @classmethod
    def translate_exam_description(cls, exam, language_code):
        """
        Translate exam description to the specified language.
        Returns the translation object.
        """
        # Check if exam has a description to translate
        if not exam.description or not exam.description.strip():
            logger.warning(f"Exam {exam.id} has no description to translate")
            return None
        
        # Check if language is supported
        if language_code not in cls.LANGUAGE_NAMES:
            logger.error(f"Unsupported language code: {language_code}")
            return None
        
        # Get or create translation record
        translation = cls.get_or_create_translation(exam, language_code)
        if not translation:
            return None
        
        # If translation already completed, return it
        if translation.translation_status == 'COMPLETED' and translation.translated_description:
            return translation
        
        # Perform the translation
        try:
            start_time = time.time()
            
            # Prepare the translation prompt
            target_language = cls.LANGUAGE_NAMES[language_code]
            prompt = cls._create_translation_prompt(exam, target_language)
            
            # Call OpenAI API
            ai_response, processing_time, error = cls._call_openai_api(prompt)
            
            if error:
                translation.translation_status = 'ERROR'
                translation.translated_description = f"Translation error: {error}"
                translation.save()
                logger.error(f"Translation failed for exam {exam.id} to {language_code}: {error}")
                return translation
            
            # Parse the AI response
            translated_text = cls._parse_translation_response(ai_response)
            
            if translated_text:
                translation.translated_description = translated_text
                translation.translation_status = 'COMPLETED'
                translation.save()
                logger.info(f"Successfully translated exam {exam.id} to {language_code}")
            else:
                translation.translation_status = 'ERROR'
                translation.translated_description = "Failed to parse translation response"
                translation.save()
                logger.error(f"Failed to parse translation response for exam {exam.id}")
            
            return translation
            
        except Exception as e:
            translation.translation_status = 'ERROR'
            translation.translated_description = f"Translation error: {str(e)}"
            translation.save()
            logger.error(f"Exception during translation for exam {exam.id}: {str(e)}")
            return translation
    
    @classmethod
    def _create_translation_prompt(cls, exam, target_language):
        """
        Create a prompt for translating exam description.
        """
        return f"""You are a professional translator specializing in educational content. 
        
Your task is to translate an exam description from English to {target_language}.

EXAM INFORMATION:
- Exam Name: {exam.name}
- Original Description (English): {exam.description}

TRANSLATION REQUIREMENTS:
1. Translate the description to {target_language}
2. Maintain the professional and educational tone
3. Keep technical terms and acronyms where appropriate
4. Ensure the translation is clear and accurate
5. Preserve the structure and formatting of the original text

Please provide ONLY the translated description in {target_language}, without any additional comments, explanations, or formatting markers."""
    
    @classmethod
    def _call_openai_api(cls, prompt):
        """
        Call OpenAI API for translation.
        """
        start_time = time.time()
        
        try:
            # Check if OpenAI is configured
            if not hasattr(settings, 'OPENAI_API_KEY') or not settings.OPENAI_API_KEY:
                return None, 0, "OpenAI API not configured"
            
            headers = {
                'Authorization': f"Bearer {settings.OPENAI_API_KEY}",
                'Content-Type': 'application/json'
            }
            
            # Prepare the request
            data = {
                'model': getattr(settings, 'OPENAI_MODEL', 'gpt-3.5-turbo'),
                'messages': [
                    {
                        'role': 'system',
                        'content': 'You are a professional translator. Provide only the translation without any additional text, explanations, or formatting.'
                    },
                    {
                        'role': 'user',
                        'content': prompt
                    }
                ],
                'temperature': 0.3,  # Lower temperature for more consistent translations
                'max_tokens': 1000
            }
            
            response = requests.post(
                'https://api.openai.com/v1/chat/completions',
                headers=headers,
                json=data,
                timeout=30
            )
            
            processing_time = int((time.time() - start_time) * 1000)
            
            if response.status_code != 200:
                error_msg = f"OpenAI API error: {response.status_code} - {response.text}"
                return None, processing_time, error_msg
            
            result = response.json()
            ai_response = result['choices'][0]['message']['content'].strip()
            
            return ai_response, processing_time, None
            
        except requests.exceptions.Timeout:
            error_msg = "OpenAI API request timed out"
            processing_time = int((time.time() - start_time) * 1000)
            return None, processing_time, error_msg
        except Exception as e:
            error_msg = f"Error calling OpenAI API: {str(e)}"
            processing_time = int((time.time() - start_time) * 1000)
            return None, processing_time, error_msg
    
    @classmethod
    def _parse_translation_response(cls, ai_response):
        """
        Parse the AI response to extract the translated text.
        """
        if not ai_response:
            return None
        
        # Clean up the response - remove any extra whitespace or formatting
        translated_text = ai_response.strip()
        
        # Remove any quotes if the AI wrapped the translation in them
        if (translated_text.startswith('"') and translated_text.endswith('"')) or \
           (translated_text.startswith("'") and translated_text.endswith("'")):
            translated_text = translated_text[1:-1]
        
        return translated_text if translated_text else None
    
    @classmethod
    def translate_multiple_exams(cls, exam_ids, language_codes):
        """
        Translate multiple exams to multiple languages.
        Useful for batch processing.
        """
        results = {}
        
        for exam_id in exam_ids:
            try:
                exam = Exam.objects.get(id=exam_id, is_active=True)
                results[exam_id] = {}
                
                for language_code in language_codes:
                    translation = cls.translate_exam_description(exam, language_code)
                    results[exam_id][language_code] = {
                        'status': translation.translation_status if translation else 'ERROR',
                        'description': translation.translated_description if translation else None
                    }
                    
            except Exam.DoesNotExist:
                results[exam_id] = {'error': 'Exam not found'}
            except Exception as e:
                results[exam_id] = {'error': str(e)}
        
        return results
    
    @classmethod
    def get_supported_languages(cls):
        """
        Get list of supported language codes and names.
        """
        return {code: name for code, name in cls.LANGUAGE_NAMES.items()} 