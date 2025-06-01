from django.db import models

class Exam(models.Model):
    """
    Exam model for organizing content into subscribable units and categories.
    This model replaces the primary role of the questions_topic model.
    """
    name = models.CharField(max_length=255, unique=True)
    slug = models.SlugField(max_length=255, unique=True, db_index=True)
    description = models.TextField(null=True, blank=True)
    parent_exam = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, 
                                   related_name='sub_exams',
                                   help_text="For creating a hierarchy of exams, categories, or subjects.")
    is_active = models.BooleanField(default=True, db_index=True, 
                                  help_text="Whether this exam or category is currently active and available.")
    display_order = models.IntegerField(default=0, 
                                      help_text="Order in which exams/categories are displayed.")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'exams_exam'
        indexes = [
            models.Index(fields=['parent_exam', 'display_order']),
        ]

    def __str__(self):
        return self.name
    
    def get_translated_description(self, language_code='en'):
        """
        Get the translated description for the given language.
        Falls back to original description if translation doesn't exist.
        """
        if language_code == 'en' or not self.description:
            return self.description
        
        try:
            translation = self.translations.get(language_code=language_code)
            return translation.translated_description or self.description
        except ExamTranslation.DoesNotExist:
            return self.description


class ExamTranslation(models.Model):
    """
    Model to store translations of exam descriptions in different languages.
    """
    exam = models.ForeignKey(Exam, on_delete=models.CASCADE, related_name='translations')
    language_code = models.CharField(max_length=10, help_text="Language code (e.g., 'de', 'fr', 'es')")
    translated_description = models.TextField(help_text="Translated description of the exam")
    translation_status = models.CharField(
        max_length=20,
        choices=[
            ('PENDING', 'Pending Translation'),
            ('COMPLETED', 'Translation Completed'),
            ('ERROR', 'Translation Error'),
        ],
        default='PENDING'
    )
    translated_at = models.DateTimeField(auto_now_add=True)
    translation_method = models.CharField(
        max_length=20,
        choices=[
            ('AI', 'AI Translation'),
            ('MANUAL', 'Manual Translation'),
        ],
        default='AI'
    )
    
    class Meta:
        db_table = 'exams_examtranslation'
        unique_together = ('exam', 'language_code')
        indexes = [
            models.Index(fields=['exam', 'language_code']),
            models.Index(fields=['translation_status']),
        ]
    
    def __str__(self):
        return f"{self.exam.name} - {self.language_code}"
