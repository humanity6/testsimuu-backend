from django.core.management.base import BaseCommand
from ai_integration.models import AIFeedbackTemplate
from ai_integration.services import AIAnswerEvaluationService


class Command(BaseCommand):
    help = 'Create default AI feedback templates for question evaluation'

    def handle(self, *args, **options):
        self.stdout.write('Creating default AI feedback templates...')
        
        # Create Open-Ended template with model answer
        open_ended_template, created = AIFeedbackTemplate.objects.get_or_create(
            template_name='Open-Ended Question Template',
            defaults={
                'question_type': 'OPEN_ENDED',
                'template_content': AIAnswerEvaluationService.OPEN_ENDED_PROMPT,
                'is_active': True
            }
        )
        
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created template: {open_ended_template.template_name}'))
        else:
            self.stdout.write(f'Template already exists: {open_ended_template.template_name}')
        
        # Create Open-Ended template without model answer
        open_ended_no_model_template, created = AIFeedbackTemplate.objects.get_or_create(
            template_name='Open-Ended Question Template (No Model Answer)',
            defaults={
                'question_type': 'OPEN_ENDED',
                'template_content': AIAnswerEvaluationService.OPEN_ENDED_NO_MODEL_PROMPT,
                'is_active': True
            }
        )
        
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created template: {open_ended_no_model_template.template_name}'))
        else:
            self.stdout.write(f'Template already exists: {open_ended_no_model_template.template_name}')
        
        # Create Calculation template
        calc_template, created = AIFeedbackTemplate.objects.get_or_create(
            template_name='Calculation Question Template',
            defaults={
                'question_type': 'CALCULATION',
                'template_content': AIAnswerEvaluationService.CALCULATION_PROMPT,
                'is_active': True
            }
        )
        
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created template: {calc_template.template_name}'))
        else:
            self.stdout.write(f'Template already exists: {calc_template.template_name}')
        
        self.stdout.write(self.style.SUCCESS('Default templates created successfully!')) 