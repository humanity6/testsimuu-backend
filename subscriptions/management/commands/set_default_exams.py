from django.core.management.base import BaseCommand
from subscriptions.models import PricingPlan
from exams.models import Exam

class Command(BaseCommand):
    help = 'Sets default exam for existing pricing plans'

    def handle(self, *args, **options):
        # Get or create a default exam
        default_exam, created = Exam.objects.get_or_create(
            name='Default Exam Category',
            slug='default-exam-category',
            defaults={
                'description': 'Default category for existing pricing plans',
                'is_active': True,
                'display_order': 0
            }
        )
        
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created default exam: {default_exam.name}'))
        
        # Count existing pricing plans with no exam
        plans_without_exam = PricingPlan.objects.filter(exam__isnull=True).count()
        
        if plans_without_exam > 0:
            # Update all existing pricing plans without an exam
            updated = PricingPlan.objects.filter(exam__isnull=True).update(exam=default_exam)
            self.stdout.write(self.style.SUCCESS(f'Updated {updated} pricing plans with default exam'))
        else:
            self.stdout.write(self.style.SUCCESS('No pricing plans needed to be updated'))
        
        # Display total count of pricing plans
        total_plans = PricingPlan.objects.count()
        self.stdout.write(self.style.SUCCESS(f'Total pricing plans: {total_plans}')) 