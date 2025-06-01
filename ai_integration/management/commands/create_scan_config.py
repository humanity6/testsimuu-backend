from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from ai_integration.models import ContentUpdateScanConfig
from ai_integration.services import ContentUpdateService
from exams.models import Exam

User = get_user_model()

class Command(BaseCommand):
    help = 'Create a default content update scan configuration'

    def add_arguments(self, parser):
        parser.add_argument('--admin-email', type=str, help='Admin user email who will be set as creator')
        parser.add_argument('--frequency', type=str, choices=['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY'], 
                            default='WEEKLY', help='Scan frequency')
        
    def handle(self, *args, **options):
        admin_email = options.get('admin_email')
        frequency = options.get('frequency')
        
        # Find admin user
        admin_user = None
        if admin_email:
            try:
                admin_user = User.objects.get(email__iexact=admin_email, is_staff=True)
            except User.DoesNotExist:
                self.stdout.write(self.style.WARNING(f'Admin user with email {admin_email} not found'))
                
        if not admin_user:
            # Get first admin user
            admin_user = User.objects.filter(is_staff=True).first()
            
        if not admin_user:
            self.stdout.write(self.style.ERROR('No admin users found in the system'))
            return
            
        # Get active exams
        exams = Exam.objects.filter(is_active=True)
        
        if not exams:
            self.stdout.write(self.style.WARNING('No active exams found in the system'))
            return
            
        # Create scan configuration
        config_name = f"Default {frequency.capitalize()} Scan"
        
        # Check if configuration with this name already exists
        if ContentUpdateScanConfig.objects.filter(name=config_name).exists():
            self.stdout.write(self.style.WARNING(f'Scan configuration "{config_name}" already exists'))
            return
            
        # Create new configuration
        scan_config = ContentUpdateScanConfig(
            name=config_name,
            frequency=frequency,
            max_questions_per_scan=20,
            is_active=True,
            prompt_template=ContentUpdateService.DEFAULT_CONTENT_UPDATE_PROMPT,
            created_by=admin_user
        )
        scan_config.save()
        
        # Add exams to configuration
        scan_config.exams.set(exams)
        
        self.stdout.write(self.style.SUCCESS(
            f'Created new scan configuration "{config_name}" with {exams.count()} exams')
        ) 