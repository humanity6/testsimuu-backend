from django.core.management.base import BaseCommand
from django.db import transaction
from users.models import User
from affiliates.models import Affiliate
from affiliates.services import AffiliateTrackingService


class Command(BaseCommand):
    help = 'Create affiliate profiles for users'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--email',
            type=str,
            help='User email to create affiliate profile for',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Create affiliate profiles for all users without one',
        )
        parser.add_argument(
            '--commission-rate',
            type=float,
            default=10.0,
            help='Default commission rate in percentage (default: 10.0)',
        )
    
    def handle(self, *args, **options):
        email = options.get('email')
        all_users = options.get('all')
        commission_rate = options.get('commission_rate')
        
        tracking_service = AffiliateTrackingService()
        
        if email:
            try:
                user = User.objects.get(email__iexact=email)
                self._create_affiliate_for_user(user, commission_rate, tracking_service)
                self.stdout.write(self.style.SUCCESS(f'Successfully created affiliate profile for {user.email}'))
            except User.DoesNotExist:
                self.stdout.write(self.style.ERROR(f'User with email {email} does not exist'))
                
        elif all_users:
            # Get all users without affiliate profiles
            users_without_profiles = User.objects.filter(affiliate_profile__isnull=True)
            count = 0
            
            for user in users_without_profiles:
                created = self._create_affiliate_for_user(user, commission_rate, tracking_service)
                if created:
                    count += 1
                    
            self.stdout.write(self.style.SUCCESS(f'Successfully created {count} affiliate profiles'))
            
        else:
            self.stdout.write(self.style.ERROR('Please provide --email or --all argument'))
    
    def _create_affiliate_for_user(self, user, commission_rate, tracking_service):
        try:
            with transaction.atomic():
                # Check if user already has an affiliate profile
                if hasattr(user, 'affiliate_profile'):
                    self.stdout.write(self.style.WARNING(f'User {user.email} already has an affiliate profile'))
                    return False
                
                # Generate tracking code
                tracking_code = tracking_service.generate_tracking_code()
                
                # Create affiliate profile
                affiliate = Affiliate.objects.create(
                    user=user,
                    name=f"{user.first_name} {user.last_name}".strip() or user.username,
                    email=user.email,
                    commission_model='PURE_AFFILIATE',
                    commission_rate=commission_rate,
                    tracking_code=tracking_code
                )
                
                # Create initial affiliate link (homepage)
                tracking_service.create_affiliate_link(
                    affiliate=affiliate,
                    target_url='https://testsimu.com',
                    name='Homepage',
                    link_type='GENERAL'
                )
                
                # Create initial voucher code
                tracking_service.create_voucher_code(
                    affiliate=affiliate,
                    code_type='PERCENTAGE',
                    discount_value=10,
                    description='10% discount for new users',
                    max_uses=50
                )
                
                return True
                
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error creating affiliate profile for {user.email}: {str(e)}'))
            return False 