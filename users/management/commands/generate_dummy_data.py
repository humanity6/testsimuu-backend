import random
import json
from datetime import datetime, timedelta
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.utils.text import slugify
from django.contrib.contenttypes.models import ContentType

# Import all models
try:
    from users.models import User, UserPreference
    from exams.models import Exam
    from questions.models import Topic, Question, MCQChoice, Tag
    from subscriptions.models import PricingPlan, UserSubscription, Payment, ReferralProgram, UserReferral
    from assessment.models import ExamSession, UserAnswer
    from analytics.models import UserPerformanceRecord, UserProgress, StudySession
    from ai_integration.models import (
        AIContentAlert, AIFeedbackTemplate, AIEvaluationLog, ContentUpdateScanConfig,
        ContentUpdateScanLog, ChatbotConversation, ChatbotMessage
    )
    from support.models import FAQItem, SupportTicket, TicketReply
    from notifications.models import Notification
    from affiliates.models import (
        Affiliate, AffiliateLink, VoucherCode, Conversion, AffiliatePayment, ClickEvent
    )
except ImportError as e:
    print(f"Error importing models: {e}")
    print("Please ensure all Django apps are properly configured in INSTALLED_APPS")
    exit(1)

try:
    from faker import Faker
    fake = Faker()
except ImportError:
    print("Please install faker: pip install faker")
    exit(1)

User = get_user_model()

class Command(BaseCommand):
    help = 'Generate dummy data for testing purposes'

    def add_arguments(self, parser):
        parser.add_argument(
            '--users',
            type=int,
            default=50,
            help='Number of users to create'
        )
        parser.add_argument(
            '--complete-user',
            action='store_true',
            help='Create one user with all possible data'
        )
        parser.add_argument(
            '--clear-data',
            action='store_true',
            help='Clear existing data before generating new data'
        )

    def handle(self, *args, **options):
        self.stdout.write('Starting dummy data generation...')
        
        # Disable signals during dummy data generation to avoid Celery issues
        from django.db.models.signals import post_save
        from assessment.models import UserAnswer
        from ai_integration.signals import queue_user_answer_evaluation
        
        # Disconnect the signal temporarily
        post_save.disconnect(queue_user_answer_evaluation, sender=UserAnswer)
        
        try:
            # Check if database tables exist
            if not self.check_database_ready():
                return
            
            # Clear existing data if requested
            if options['clear_data']:
                self.clear_existing_data()
            
            # Create basic data structure
            self.create_exams()
            self.create_topics()
            self.create_tags()
            self.create_pricing_plans()
            self.create_referral_programs()
            self.create_ai_feedback_templates()
            self.create_faq_items()
            self.create_scan_configs()
            
            # Create users and related data
            self.create_users(options['users'])
            
            # Create complete user if requested
            if options['complete_user']:
                self.create_complete_user()
            
            # Create questions after topics and exams
            self.create_questions()
            
            # Create user-related data
            self.create_subscriptions()
            self.create_exam_sessions()
            self.create_user_answers()
            self.create_analytics_data()
            self.create_support_tickets()
            self.create_notifications()
            self.create_affiliate_data()
            self.create_ai_integration_data()
            
            # Create comprehensive data for complete user after all other data exists
            if options['complete_user']:
                self.create_complete_user_data()
            
            self.stdout.write(
                self.style.SUCCESS('Successfully generated dummy data!')
            )
        finally:
            # Reconnect the signal after dummy data generation
            post_save.connect(queue_user_answer_evaluation, sender=UserAnswer)

    def check_database_ready(self):
        """Check if database tables exist and migrations have been run"""
        from django.db import connection, OperationalError
        
        try:
            # Try to access a simple table to check if migrations have been run
            with connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM django_migrations")
                migrations_count = cursor.fetchone()[0]
                
                if migrations_count == 0:
                    self.stdout.write(
                        self.style.ERROR('No migrations found in database!')
                    )
                    self.stdout.write('Please run migrations first:')
                    self.stdout.write('python manage.py makemigrations')
                    self.stdout.write('python manage.py migrate')
                    return False
                
                # Check if our app tables exist by trying to query one
                try:
                    cursor.execute("SELECT 1 FROM exams_exam LIMIT 1")
                except OperationalError:
                    self.stdout.write(
                        self.style.ERROR('Application tables not found!')
                    )
                    self.stdout.write('Please run migrations first:')
                    self.stdout.write('python manage.py makemigrations')
                    self.stdout.write('python manage.py migrate')
                    return False
                    
        except OperationalError as e:
            self.stdout.write(
                self.style.ERROR(f'Database error: {e}')
            )
            self.stdout.write('Please ensure your database is set up and run:')
            self.stdout.write('python manage.py makemigrations')
            self.stdout.write('python manage.py migrate')
            return False
        
        return True

    def clear_existing_data(self):
        """Clear existing dummy data"""
        self.stdout.write('Clearing existing data...')
        
        # Clear in reverse order of dependencies
        try:
            from django.db import transaction
            with transaction.atomic():
                # Clear data in reverse dependency order
                UserAnswer.objects.all().delete()
                ExamSession.objects.all().delete()
                UserSubscription.objects.all().delete()
                Payment.objects.all().delete()
                UserReferral.objects.all().delete()
                Conversion.objects.all().delete()
                ClickEvent.objects.all().delete()
                AffiliatePayment.objects.all().delete()
                VoucherCode.objects.all().delete()
                AffiliateLink.objects.all().delete()
                Affiliate.objects.all().delete()
                Notification.objects.all().delete()
                TicketReply.objects.all().delete()
                SupportTicket.objects.all().delete()
                StudySession.objects.all().delete()
                UserProgress.objects.all().delete()
                UserPerformanceRecord.objects.all().delete()
                ChatbotMessage.objects.all().delete()
                ChatbotConversation.objects.all().delete()
                ContentUpdateScanLog.objects.all().delete()
                AIEvaluationLog.objects.all().delete()
                AIContentAlert.objects.all().delete()
                MCQChoice.objects.all().delete()
                Question.objects.all().delete()
                UserPreference.objects.all().delete()
                User.objects.filter(is_superuser=False).delete()  # Keep superusers
                ContentUpdateScanConfig.objects.all().delete()
                FAQItem.objects.all().delete()
                AIFeedbackTemplate.objects.all().delete()
                ReferralProgram.objects.all().delete()
                PricingPlan.objects.all().delete()
                Tag.objects.all().delete()
                Topic.objects.all().delete()
                Exam.objects.all().delete()
                
                self.stdout.write('Existing data cleared successfully.')
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error clearing data: {e}')
            )

    def create_exams(self):
        """Create exam categories and sub-exams"""
        self.stdout.write('Creating exams...')
        
        # Check if exams already exist, if so, load them
        if Exam.objects.exists():
            self.stdout.write('Exams already exist, loading existing data...')
            self.exams = list(Exam.objects.all())
            return
        
        # Main exam categories
        main_exams = [
            {'name': 'Medical Entrance Exams', 'description': 'Medical college entrance examinations'},
            {'name': 'Engineering Entrance', 'description': 'Engineering college entrance tests'},
            {'name': 'Business School Admissions', 'description': 'MBA and business school tests'},
            {'name': 'Language Proficiency', 'description': 'English and other language tests'},
            {'name': 'Government Jobs', 'description': 'Civil service and government job exams'},
        ]
        
        self.exams = []
        for exam_data in main_exams:
            exam = Exam.objects.create(
                name=exam_data['name'],
                slug=slugify(exam_data['name']),
                description=exam_data['description'],
                is_active=True,
                display_order=len(self.exams)
            )
            self.exams.append(exam)
        
        # Create sub-exams
        sub_exams = [
            {'name': 'NEET', 'parent': self.exams[0], 'description': 'National Eligibility cum Entrance Test'},
            {'name': 'MCAT', 'parent': self.exams[0], 'description': 'Medical College Admission Test'},
            {'name': 'JEE Main', 'parent': self.exams[1], 'description': 'Joint Entrance Examination Main'},
            {'name': 'JEE Advanced', 'parent': self.exams[1], 'description': 'Joint Entrance Examination Advanced'},
            {'name': 'GMAT', 'parent': self.exams[2], 'description': 'Graduate Management Admission Test'},
            {'name': 'GRE', 'parent': self.exams[2], 'description': 'Graduate Record Examinations'},
            {'name': 'IELTS', 'parent': self.exams[3], 'description': 'International English Language Testing System'},
            {'name': 'TOEFL', 'parent': self.exams[3], 'description': 'Test of English as a Foreign Language'},
        ]
        
        for sub_exam_data in sub_exams:
            exam = Exam.objects.create(
                name=sub_exam_data['name'],
                slug=slugify(sub_exam_data['name']),
                description=sub_exam_data['description'],
                parent_exam=sub_exam_data['parent'],
                is_active=True,
                display_order=random.randint(1, 10)
            )
            self.exams.append(exam)

    def create_topics(self):
        """Create topics for questions"""
        self.stdout.write('Creating topics...')
        
        # Check if topics already exist, if so, load them
        if Topic.objects.exists():
            self.stdout.write('Topics already exist, loading existing data...')
            self.topics = list(Topic.objects.all())
            return
        
        topics_data = [
            # Medical topics
            {'name': 'Biology', 'description': 'Basic biology concepts'},
            {'name': 'Chemistry', 'description': 'Organic and inorganic chemistry'},
            {'name': 'Physics', 'description': 'Physics fundamentals'},
            {'name': 'Anatomy', 'description': 'Human anatomy'},
            
            # Engineering topics
            {'name': 'Mathematics', 'description': 'Advanced mathematics'},
            {'name': 'Mechanics', 'description': 'Classical mechanics'},
            {'name': 'Thermodynamics', 'description': 'Heat and energy'},
            {'name': 'Electronics', 'description': 'Electronic circuits'},
            
            # Business topics
            {'name': 'Quantitative Aptitude', 'description': 'Mathematical reasoning'},
            {'name': 'Verbal Reasoning', 'description': 'Language and logic'},
            {'name': 'Data Interpretation', 'description': 'Chart and graph analysis'},
            {'name': 'General Awareness', 'description': 'Current affairs and GK'},
            
            # Language topics
            {'name': 'Reading Comprehension', 'description': 'Text understanding'},
            {'name': 'Grammar', 'description': 'Language rules'},
            {'name': 'Vocabulary', 'description': 'Word knowledge'},
            {'name': 'Writing', 'description': 'Essay and writing skills'},
        ]
        
        self.topics = []
        for topic_data in topics_data:
            topic = Topic.objects.create(
                name=topic_data['name'],
                slug=slugify(topic_data['name']),
                description=topic_data['description'],
                is_active=True,
                display_order=len(self.topics)
            )
            self.topics.append(topic)
        
        # Create some sub-topics
        sub_topics = [
            {'name': 'Cell Biology', 'parent': self.topics[0]},
            {'name': 'Organic Chemistry', 'parent': self.topics[1]},
            {'name': 'Calculus', 'parent': self.topics[4]},
            {'name': 'Algebra', 'parent': self.topics[4]},
        ]
        
        for sub_topic_data in sub_topics:
            topic = Topic.objects.create(
                name=sub_topic_data['name'],
                slug=slugify(sub_topic_data['name']),
                description=f"Sub-topic of {sub_topic_data['parent'].name}",
                parent_topic=sub_topic_data['parent'],
                is_active=True,
                display_order=random.randint(1, 10)
            )
            self.topics.append(topic)

    def create_tags(self):
        """Create tags for questions"""
        self.stdout.write('Creating tags...')
        
        # Check if tags already exist, if so, load them
        if Tag.objects.exists():
            self.stdout.write('Tags already exist, loading existing data...')
            self.tags = list(Tag.objects.all())
            return
        
        tag_names = [
            'important', 'frequently-asked', 'difficult', 'basic', 'advanced',
            'conceptual', 'numerical', 'theory', 'practical', 'previous-year',
            'mock-test', 'revision', 'formula-based', 'diagram', 'calculation'
        ]
        
        self.tags = []
        for tag_name in tag_names:
            tag = Tag.objects.create(
                name=tag_name,
                slug=slugify(tag_name),
                description=f"Questions tagged as {tag_name}"
            )
            self.tags.append(tag)

    def create_pricing_plans(self):
        """Create pricing plans"""
        self.stdout.write('Creating pricing plans...')
        
        # Check if pricing plans already exist, if so, load them
        if PricingPlan.objects.exists():
            self.stdout.write('Pricing plans already exist, loading existing data...')
            self.pricing_plans = list(PricingPlan.objects.all())
            return
        
        self.pricing_plans = []
        for exam in self.exams[:8]:  # Create plans for first 8 exams
            plans = [
                {
                    'name': f'{exam.name} - Basic',
                    'price': Decimal('19.99'),
                    'billing_cycle': 'MONTHLY',
                    'features': ['Basic question bank', 'Mock tests', 'Performance analytics']
                },
                {
                    'name': f'{exam.name} - Premium',
                    'price': Decimal('39.99'),
                    'billing_cycle': 'MONTHLY',
                    'features': ['Full question bank', 'AI explanations', 'Detailed analytics', 'Priority support']
                },
                {
                    'name': f'{exam.name} - Annual',
                    'price': Decimal('299.99'),
                    'billing_cycle': 'YEARLY',
                    'features': ['All premium features', '12 months access', 'Exam strategies', 'Study plans']
                }
            ]
            
            for plan_data in plans:
                plan = PricingPlan.objects.create(
                    name=plan_data['name'],
                    slug=slugify(plan_data['name']),
                    description=f"Comprehensive preparation for {exam.name}",
                    exam=exam,
                    price=plan_data['price'],
                    billing_cycle=plan_data['billing_cycle'],
                    features_list=plan_data['features'],
                    is_active=True,
                    display_order=len(self.pricing_plans),
                    trial_days=7
                )
                self.pricing_plans.append(plan)

    def create_referral_programs(self):
        """Create referral programs"""
        self.stdout.write('Creating referral programs...')
        
        # Check if referral programs already exist, if so, load them
        if ReferralProgram.objects.exists():
            self.stdout.write('Referral programs already exist, loading existing data...')
            self.referral_programs = list(ReferralProgram.objects.all())
            return
        
        programs = [
            {
                'name': 'Student Referral Program',
                'reward_type': 'DISCOUNT_PERCENTAGE',
                'reward_value': Decimal('20.00'),
                'referrer_reward_type': 'EXTEND_SUBSCRIPTION_DAYS',
                'referrer_reward_value': Decimal('30')
            },
            {
                'name': 'Friend Referral Bonus',
                'reward_type': 'DISCOUNT_FIXED',
                'reward_value': Decimal('10.00'),
                'referrer_reward_type': 'CREDIT',
                'referrer_reward_value': Decimal('15.00')
            }
        ]
        
        self.referral_programs = []
        for program_data in programs:
            program = ReferralProgram.objects.create(
                name=program_data['name'],
                description=f"Referral rewards for {program_data['name']}",
                reward_type=program_data['reward_type'],
                reward_value=program_data['reward_value'],
                referrer_reward_type=program_data['referrer_reward_type'],
                referrer_reward_value=program_data['referrer_reward_value'],
                is_active=True,
                valid_from=timezone.now().date(),
                valid_until=timezone.now().date() + timedelta(days=365),
                min_purchase_amount=Decimal('5.00')
            )
            self.referral_programs.append(program)

    def create_ai_feedback_templates(self):
        """Create AI feedback templates"""
        self.stdout.write('Creating AI feedback templates...')
        
        # Check if AI feedback templates already exist, if so, load them
        if AIFeedbackTemplate.objects.exists():
            self.stdout.write('AI feedback templates already exist, loading existing data...')
            self.ai_templates = list(AIFeedbackTemplate.objects.all())
            return
        
        templates = [
            {
                'name': 'Open Ended Physics Template',
                'question_type': 'OPEN_ENDED',
                'content': 'Evaluate the student\'s understanding of physics concepts. Check for: 1) Correct formula usage 2) Units and calculations 3) Conceptual understanding 4) Step-by-step approach'
            },
            {
                'name': 'Math Calculation Template',
                'question_type': 'CALCULATION',
                'content': 'Assess the mathematical solution: 1) Correct method selection 2) Accurate calculations 3) Final answer correctness 4) Showing work clearly'
            },
            {
                'name': 'Biology Open Answer Template',
                'question_type': 'OPEN_ENDED',
                'content': 'Review biological concepts: 1) Scientific terminology usage 2) Process understanding 3) Examples and applications 4) Accuracy of facts'
            }
        ]
        
        self.ai_templates = []
        for template_data in templates:
            template = AIFeedbackTemplate.objects.create(
                template_name=template_data['name'],
                question_type=template_data['question_type'],
                template_content=template_data['content'],
                is_active=True
            )
            self.ai_templates.append(template)

    def create_faq_items(self):
        """Create FAQ items"""
        self.stdout.write('Creating FAQ items...')
        
        # Check if FAQ items already exist, if so, load them
        if FAQItem.objects.exists():
            self.stdout.write('FAQ items already exist, loading existing data...')
            self.faq_items = list(FAQItem.objects.all())
            return
        
        faqs = [
            {
                'question': 'How do I reset my password?',
                'answer': 'You can reset your password by clicking on the "Forgot Password" link on the login page and following the instructions sent to your email.',
                'category': 'account'
            },
            {
                'question': 'What payment methods do you accept?',
                'answer': 'We accept all major credit cards, PayPal, and bank transfers. All payments are processed securely.',
                'category': 'billing'
            },
            {
                'question': 'How does the AI evaluation work?',
                'answer': 'Our AI system analyzes your answers using advanced natural language processing to provide detailed feedback and suggestions for improvement.',
                'category': 'features'
            },
            {
                'question': 'Can I cancel my subscription anytime?',
                'answer': 'Yes, you can cancel your subscription at any time from your account settings. You will continue to have access until the end of your billing period.',
                'category': 'billing'
            },
            {
                'question': 'How often are new questions added?',
                'answer': 'We regularly update our question bank with new questions, typically adding 50-100 new questions per week across all subjects.',
                'category': 'content'
            }
        ]
        
        self.faq_items = []
        for faq_data in faqs:
            faq = FAQItem.objects.create(
                question_text=faq_data['question'],
                answer_text=faq_data['answer'],
                category=faq_data['category'],
                is_published=True,
                display_order=len(self.faq_items),
                view_count=random.randint(10, 500)
            )
            self.faq_items.append(faq)

    def create_scan_configs(self):
        """Create content scan configurations"""
        self.stdout.write('Creating scan configurations...')
        
        # Check if scan configs already exist, if so, load them
        if ContentUpdateScanConfig.objects.exists():
            self.stdout.write('Scan configurations already exist, loading existing data...')
            self.scan_configs = list(ContentUpdateScanConfig.objects.all())
            return
        
        self.scan_configs = []
        for i, exam in enumerate(self.exams[:3]):  # Create configs for first 3 exams
            config = ContentUpdateScanConfig.objects.create(
                name=f'Weekly {exam.name} Content Scan',
                frequency='WEEKLY',
                max_questions_per_scan=20,
                is_active=True,
                prompt_template=f'Analyze recent developments in {exam.name} and suggest content updates.',
                next_scheduled_run=timezone.now() + timedelta(days=7)
            )
            config.exams.add(exam)
            self.scan_configs.append(config)

    def create_users(self, count):
        """Create users with preferences"""
        self.stdout.write(f'Creating {count} users...')
        
        # Check if non-superuser users already exist, if so, load them
        existing_users = User.objects.filter(is_superuser=False)
        if existing_users.exists():
            self.stdout.write('Users already exist, loading existing data...')
            self.users = list(existing_users)
            if len(self.users) >= count:
                return
            else:
                # Create additional users if needed
                count = count - len(self.users)
                self.stdout.write(f'Creating {count} additional users...')
        else:
            self.users = []
        for i in range(count):
            user = User.objects.create_user(
                username=fake.user_name(),
                email=fake.email(),
                first_name=fake.first_name(),
                last_name=fake.last_name(),
                password='testpass123',
                is_active=True,
                email_verified=random.choice([True, False]),
                profile_picture_url=fake.image_url() if random.random() > 0.5 else None,
                date_of_birth=fake.date_of_birth(minimum_age=16, maximum_age=35),
                gdpr_consent_date=timezone.now() - timedelta(days=random.randint(1, 365)),
                referral_code=fake.lexify(text='REF??????').upper(),
                last_active=timezone.now() - timedelta(hours=random.randint(1, 720)),
                time_zone=random.choice(['UTC', 'US/Eastern', 'Europe/London', 'Asia/Kolkata'])
            )
            
            # Create user preferences
            UserPreference.objects.create(
                user=user,
                notification_settings={
                    'email_notifications': random.choice([True, False]),
                    'push_notifications': random.choice([True, False]),
                    'reminder_notifications': random.choice([True, False])
                },
                ui_preferences={
                    'theme': random.choice(['light', 'dark']),
                    'language': random.choice(['en', 'es', 'fr']),
                    'timezone_display': random.choice([True, False])
                }
            )
            
            self.users.append(user)

    def create_complete_user(self):
        """Create one user with all possible data"""
        self.stdout.write('Creating complete user with all data...')
        
        # Check if complete user already exists
        try:
            complete_user = User.objects.get(username='complete_test_user')
            self.stdout.write('Complete user already exists, loading existing data...')
            self.complete_user = complete_user
            if complete_user not in self.users:
                self.users.append(complete_user)
            return
        except User.DoesNotExist:
            pass
        
        # Create the complete user
        complete_user = User.objects.create_user(
            username='complete_test_user',
            email='complete@testuser.com',
            first_name='Complete',
            last_name='TestUser',
            password='testpass123',
            is_active=True,
            email_verified=True,
            profile_picture_url='https://example.com/profile.jpg',
            date_of_birth=datetime(1995, 5, 15).date(),
            gdpr_consent_date=timezone.now() - timedelta(days=30),
            referral_code='COMPLETE123',
            last_active=timezone.now(),
            time_zone='UTC'
        )
        
        # Create complete user preferences
        UserPreference.objects.create(
            user=complete_user,
            notification_settings={
                'email_notifications': True,
                'push_notifications': True,
                'reminder_notifications': True,
                'weekly_reports': True,
                'marketing_emails': False
            },
            ui_preferences={
                'theme': 'dark',
                'language': 'en',
                'timezone_display': True,
                'compact_mode': False,
                'animations_enabled': True
            }
        )
        
        self.complete_user = complete_user
        self.users.append(complete_user)

    def create_admin_user(self):
        """Create an admin user for testing admin interface"""
        self.stdout.write('Creating admin user...')
        
        # Check if admin user already exists
        try:
            admin_user = User.objects.get(username='admin_test_user')
            self.stdout.write('Admin user already exists, loading existing data...')
            self.admin_user = admin_user
            if admin_user not in self.users:
                self.users.append(admin_user)
            return
        except User.DoesNotExist:
            pass
        
        # Create the admin user with superuser privileges
        admin_user = User.objects.create_user(
            username='admin_test_user',
            email='admin@testuser.com',
            first_name='Admin',
            last_name='TestUser',
            password='adminpass123',
            is_active=True,
            is_staff=True,
            is_superuser=True,
            email_verified=True,
            profile_picture_url='https://example.com/admin-profile.jpg',
            date_of_birth=datetime(1985, 3, 20).date(),
            gdpr_consent_date=timezone.now() - timedelta(days=60),
            referral_code='ADMIN123',
            last_active=timezone.now(),
            time_zone='UTC'
        )
        
        # Create admin user preferences
        UserPreference.objects.create(
            user=admin_user,
            notification_settings={
                'email_notifications': True,
                'push_notifications': True,
                'reminder_notifications': True,
                'weekly_reports': True,
                'marketing_emails': True,
                'admin_alerts': True
            },
            ui_preferences={
                'theme': 'light',
                'language': 'en',
                'timezone_display': True,
                'compact_mode': True,
                'animations_enabled': True,
                'admin_dashboard_layout': 'full'
            }
        )
        
        self.admin_user = admin_user
        self.users.append(admin_user)
        self.stdout.write(f'Created admin user: {admin_user.username} with superuser privileges')

    def create_complete_user_data(self):
        """Create comprehensive data for the complete user across all related tables"""
        if not hasattr(self, 'complete_user'):
            return
            
        self.stdout.write('Creating comprehensive data for complete user...')
        user = self.complete_user
        
        # Create admin user for testing admin interface
        self.create_admin_user()
        
        # 1. Create subscriptions (multiple plans)
        for i, pricing_plan in enumerate(self.pricing_plans[:3]):  # 3 different subscriptions
            start_date = timezone.now() - timedelta(days=30 * (i + 1))
            subscription = UserSubscription.objects.create(
                user=user,
                pricing_plan=pricing_plan,
                start_date=start_date,
                end_date=start_date + timedelta(days=365),
                status='ACTIVE' if i == 0 else random.choice(['EXPIRED', 'CANCELED']),
                payment_gateway_subscription_id=fake.uuid4(),
                auto_renew=True if i == 0 else False,
                cancelled_at=None if i == 0 else timezone.now() - timedelta(days=random.randint(1, 30))
            )
            
            # Create payment for each subscription
            Payment.objects.create(
                user=user,
                user_subscription=subscription,
                amount=pricing_plan.price,
                currency='USD',
                status='SUCCESSFUL',
                payment_gateway_transaction_id=fake.uuid4(),
                payment_method_details={
                    'method': 'credit_card',
                    'last_four': '1234',
                    'brand': 'visa'
                },
                transaction_time=start_date,
                billing_address={
                    'street': '123 Test Street',
                    'city': 'Test City',
                    'country': 'US'
                },
                invoice_number=f'INV-COMPLETE-{i+1:03d}'
            )
        
        # 2. Create exam sessions (multiple exams)
        for exam in self.exams[:5]:  # Sessions for first 5 exams
            for session_num in range(random.randint(2, 4)):  # 2-4 sessions per exam
                start_time = timezone.now() - timedelta(hours=random.randint(24, 720))
                session = ExamSession.objects.create(
                    user=user,
                    exam=exam,
                    title=f"{exam.name} Complete User Session {session_num + 1}",
                    session_type=random.choice(['PRACTICE', 'TIMED_EXAM', 'ASSESSMENT']),
                    start_time=start_time,
                    end_time_expected=start_time + timedelta(minutes=90),
                    actual_end_time=start_time + timedelta(minutes=random.randint(75, 105)),
                    status='COMPLETED',
                    total_score_achieved=random.uniform(75, 95),
                    total_possible_score=100,
                    pass_threshold=70,
                    passed=True,
                    time_limit_seconds=5400,
                    metadata={'created_for': 'complete_user'}
                )
                
                # Add questions to session and create answers
                exam_questions = [q for q in self.questions if q.exam == exam][:10]  # 10 questions per session
                for i, question in enumerate(exam_questions):
                    session.questions.add(question, through_defaults={
                        'display_order': i,
                        'question_weight': 1.0
                    })
                    
                    # Create user answer
                    answer = UserAnswer.objects.create(
                        user=user,
                        question=question,
                        exam_session=session,
                        submitted_answer_text=fake.text(max_nb_chars=200) if question.question_type != 'MCQ' else None,
                        submitted_calculation_input={'user_input': 'Complete calculation steps'} if question.question_type == 'CALCULATION' else None,
                        raw_score=question.points,
                        weighted_score=question.points,
                        max_possible_score=question.points,
                        is_correct=True,
                        ai_feedback='Excellent answer! Shows deep understanding of the concept.',
                        evaluation_status='EVALUATED',
                        time_spent_seconds=random.randint(120, 240),
                        submission_time=start_time + timedelta(minutes=i * 8),
                        retry_count=0
                    )
                    
                    # Add MCQ choice if applicable
                    if question.question_type == 'MCQ':
                        correct_choice = question.choices.filter(is_correct=True).first()
                        if correct_choice:
                            answer.mcq_choices.add(correct_choice)
        
        # 3. Create analytics data
        for topic in self.topics[:10]:  # Performance records for 10 topics
            for days_ago in range(0, 60, 7):  # Weekly records for 8 weeks
                date_recorded = timezone.now().date() - timedelta(days=days_ago)
                UserPerformanceRecord.objects.create(
                    user=user,
                    topic=topic,
                    question_type=random.choice(['MCQ', 'OPEN_ENDED', 'CALCULATION']),
                    difficulty=random.choice(['EASY', 'MEDIUM', 'HARD']),
                    date_recorded=date_recorded,
                    questions_answered=random.randint(10, 25),
                    correct_answers=random.randint(8, 20),
                    partially_correct_answers=random.randint(1, 3),
                    total_points_earned=random.uniform(40, 50),
                    total_points_possible=50,
                    total_time_spent_seconds=random.randint(1200, 2400),
                    accuracy=random.uniform(0.8, 0.95),
                    average_time_per_question=random.uniform(60, 120)
                )
        
        # User progress for all topics
        for topic in self.topics:
            total_questions = random.randint(30, 80)
            questions_attempted = random.randint(20, total_questions)
            UserProgress.objects.create(
                user=user,
                topic=topic,
                total_questions_in_topic=total_questions,
                questions_attempted=questions_attempted,
                questions_mastered=random.randint(15, questions_attempted),
                proficiency_level=random.choice(['INTERMEDIATE', 'ADVANCED', 'EXPERT']),
                last_activity_date=timezone.now() - timedelta(days=random.randint(0, 7))
            )
        
        # Study sessions
        for _ in range(15):  # 15 study sessions
            start_time = timezone.now() - timedelta(hours=random.randint(1, 720))
            StudySession.objects.create(
                user=user,
                start_time=start_time,
                end_time=start_time + timedelta(minutes=random.randint(45, 180)),
                topics_studied=[topic.id for topic in random.sample(self.topics, random.randint(2, 4))],
                questions_answered=random.randint(10, 30),
                correct_answers=random.randint(8, 25),
                device_info='Complete User Browser',
                session_source='WEB'
            )
        
        # 4. Create support tickets and replies
        for i in range(3):  # 3 support tickets
            ticket = SupportTicket.objects.create(
                user=user,
                subject=f'Complete User Support Request {i+1}',
                description=fake.text(max_nb_chars=400),
                ticket_type=random.choice(['QUESTION', 'BUG', 'FEATURE_REQUEST']),
                status=random.choice(['RESOLVED', 'CLOSED', 'IN_PROGRESS']),
                priority=random.choice(['MEDIUM', 'HIGH']),
                resolved_at=timezone.now() - timedelta(days=random.randint(1, 15)),
                assigned_to=self.users[0] if self.users else None
            )
            
            # Add replies
            for j in range(random.randint(2, 4)):
                TicketReply.objects.create(
                    ticket=ticket,
                    user=user if j % 2 == 0 else self.users[0],
                    message=fake.text(max_nb_chars=200),
                    is_staff_reply=(j % 2 == 1)
                )
        
        # 5. Make complete user an affiliate
        affiliate = Affiliate.objects.create(
            user=user,
            name=f"{user.first_name} {user.last_name}",
            email=user.email,
            website='https://complete-user-site.com',
            description='Complete test user affiliate account with comprehensive data',
            commission_model='PURE_AFFILIATE',
            commission_rate=Decimal('10.00'),
            fixed_fee=Decimal('0.00'),
            payment_method='bank_transfer',
            payment_details={'bank': 'Complete Bank', 'account': 'ACC123456789'},
            tracking_code='COMPLETE123',
            is_active=True
        )
        
        # Create affiliate links
        for i in range(5):
            AffiliateLink.objects.create(
                affiliate=affiliate,
                name=f'Complete User Link {i+1}',
                link_type=random.choice(['GENERAL', 'PRODUCT', 'CAMPAIGN']),
                target_url=f'https://example.com/ref/complete/{i+1}',
                tracking_id=f'TRK-COMPLETE-{i+1:03d}',
                utm_campaign=f'complete-campaign-{i+1}',
                click_count=random.randint(50, 200),
                is_active=True
            )
        
        # Create voucher codes
        for i in range(3):
            VoucherCode.objects.create(
                affiliate=affiliate,
                code=f'COMPLETE{i+1:02d}',
                description=f'Complete user voucher code {i+1}',
                code_type=random.choice(['PERCENTAGE', 'FIXED']),
                discount_value=Decimal(str(random.uniform(10, 25))),
                valid_from=timezone.now(),
                valid_until=timezone.now() + timedelta(days=365),
                max_uses=100,
                current_uses=random.randint(5, 25),
                minimum_purchase=Decimal('5.00'),
                is_active=True
            )
        
        # Create conversions
        for i in range(8):
            Conversion.objects.create(
                affiliate=affiliate,
                user=random.choice(self.users),
                conversion_type=random.choice(['SIGNUP', 'SUBSCRIPTION']),
                conversion_value=Decimal(str(random.uniform(20, 100))),
                commission_amount=Decimal(str(random.uniform(2, 10))),
                ip_address=fake.ipv4(),
                user_agent='Complete User Browser',
                referrer_url='https://complete-user-site.com',
                is_verified=True,
                is_paid=random.choice([True, False]),
                conversion_date=timezone.now() - timedelta(days=random.randint(1, 90))
            )
        
        # 6. Create chatbot conversations
        for i in range(3):
            conversation = ChatbotConversation.objects.create(
                user=user,
                title=f'Complete User Chat {i+1}',
                is_active=i == 0  # Keep one active
            )
            
            # Add messages
            messages = [
                ('USER', 'Hello, I need help with my studies'),
                ('ASSISTANT', 'I\'d be happy to help! What specific topic are you working on?'),
                ('USER', 'I\'m struggling with calculus problems'),
                ('ASSISTANT', 'Let me provide some guidance on calculus concepts...'),
            ]
            
            for j, (role, content) in enumerate(messages):
                ChatbotMessage.objects.create(
                    conversation=conversation,
                    role=role,
                    content=content + f' (Session {i+1})',
                    processing_time_ms=random.randint(500, 1500) if role == 'ASSISTANT' else None
                )

    def create_questions(self):
        """Create questions with choices"""
        self.stdout.write('Creating questions...')
        
        # Check if questions already exist, if so, load them
        if Question.objects.exists():
            self.stdout.write('Questions already exist, loading existing data...')
            self.questions = list(Question.objects.all())
            return
        
        self.questions = []
        question_types = ['MCQ', 'OPEN_ENDED', 'CALCULATION']
        difficulties = ['EASY', 'MEDIUM', 'HARD']
        
        for exam in self.exams:
            for i in range(random.randint(10, 30)):  # 10-30 questions per exam
                question_type = random.choice(question_types)
                topic = random.choice(self.topics)
                
                question = Question.objects.create(
                    exam=exam,
                    topic=topic,
                    text=self.generate_question_text(question_type, topic.name),
                    question_type=question_type,
                    difficulty=random.choice(difficulties),
                    estimated_time_seconds=random.randint(60, 300),
                    points=random.randint(1, 5),
                    model_answer_text=self.generate_model_answer(question_type),
                    model_calculation_logic=self.generate_calculation_logic() if question_type == 'CALCULATION' else None,
                    is_active=True,
                    answer_explanation=fake.text(max_nb_chars=200),
                    created_by=random.choice(self.users) if self.users else None,
                    last_updated_by=random.choice(self.users) if self.users else None
                )
                
                # Add tags to questions
                question_tags = random.sample(self.tags, random.randint(1, 3))
                question.tags.set(question_tags)
                
                # Create MCQ choices if it's an MCQ question
                if question_type == 'MCQ':
                    choices_texts = self.generate_mcq_choices(topic.name)
                    correct_choice = random.randint(0, len(choices_texts) - 1)
                    
                    for j, choice_text in enumerate(choices_texts):
                        MCQChoice.objects.create(
                            question=question,
                            choice_text=choice_text,
                            is_correct=(j == correct_choice),
                            display_order=j,
                            explanation=fake.sentence() if j == correct_choice else None
                        )
                
                self.questions.append(question)

    def generate_question_text(self, question_type, topic):
        """Generate sample question text based on type and topic"""
        if question_type == 'MCQ':
            return f"Which of the following is true about {topic}? {fake.text(max_nb_chars=100)}"
        elif question_type == 'OPEN_ENDED':
            return f"Explain the concept of {topic} and provide examples. {fake.text(max_nb_chars=80)}"
        else:  # CALCULATION
            return f"Calculate the following problem related to {topic}: {fake.text(max_nb_chars=120)}"

    def generate_model_answer(self, question_type):
        """Generate model answer based on question type"""
        if question_type == 'MCQ':
            return None  # MCQ answers are in choices
        elif question_type == 'OPEN_ENDED':
            return fake.text(max_nb_chars=300)
        else:  # CALCULATION
            return f"Step 1: {fake.sentence()}\nStep 2: {fake.sentence()}\nAnswer: {random.randint(1, 100)}"

    def generate_calculation_logic(self):
        """Generate calculation logic JSON"""
        return {
            'steps': [
                {'description': 'Identify given values', 'formula': 'Given: a = 5, b = 3'},
                {'description': 'Apply formula', 'formula': 'c = a + b'},
                {'description': 'Calculate result', 'formula': 'c = 8'}
            ],
            'final_answer': '8'
        }

    def generate_mcq_choices(self, topic):
        """Generate MCQ choices"""
        return [
            f"Option A: {fake.sentence()} about {topic}",
            f"Option B: {fake.sentence()} regarding {topic}",
            f"Option C: {fake.sentence()} concerning {topic}",
            f"Option D: {fake.sentence()} related to {topic}"
        ]

    def create_subscriptions(self):
        """Create user subscriptions"""
        self.stdout.write('Creating subscriptions...')
        
        self.subscriptions = []
        for user in self.users[:30]:  # 30 users get subscriptions
            pricing_plan = random.choice(self.pricing_plans)
            start_date = timezone.now() - timedelta(days=random.randint(1, 90))
            
            subscription = UserSubscription.objects.create(
                user=user,
                pricing_plan=pricing_plan,
                start_date=start_date,
                end_date=start_date + timedelta(days=30) if pricing_plan.billing_cycle == 'MONTHLY' else start_date + timedelta(days=365),
                status=random.choice(['ACTIVE', 'CANCELED', 'EXPIRED']),
                payment_gateway_subscription_id=fake.uuid4(),
                auto_renew=random.choice([True, False]),
                cancelled_at=timezone.now() - timedelta(days=random.randint(1, 30)) if random.random() > 0.7 else None
            )
            self.subscriptions.append(subscription)

    def create_exam_sessions(self):
        """Create exam sessions"""
        self.stdout.write('Creating exam sessions...')
        
        self.exam_sessions = []
        for user in self.users[:25]:  # 25 users take exams
            for _ in range(random.randint(1, 5)):  # 1-5 sessions per user
                exam = random.choice(self.exams)
                start_time = timezone.now() - timedelta(hours=random.randint(1, 168))
                
                session = ExamSession.objects.create(
                    user=user,
                    exam=exam,
                    title=f"{exam.name} Practice Session",
                    session_type=random.choice(['PRACTICE', 'TIMED_EXAM', 'ASSESSMENT']),
                    start_time=start_time,
                    end_time_expected=start_time + timedelta(minutes=90),
                    actual_end_time=start_time + timedelta(minutes=random.randint(60, 120)) if random.random() > 0.3 else None,
                    status=random.choice(['IN_PROGRESS', 'COMPLETED', 'ABANDONED']),
                    total_score_achieved=random.uniform(60, 95) if random.random() > 0.3 else None,
                    total_possible_score=100,
                    pass_threshold=70,
                    passed=None,  # Will be calculated
                    time_limit_seconds=5400,  # 90 minutes
                    metadata={'created_by': 'dummy_data_generator'}
                )
                
                # Add questions to session
                session_questions = random.sample(
                    [q for q in self.questions if q.exam == exam],
                    min(10, len([q for q in self.questions if q.exam == exam]))
                )
                for j, question in enumerate(session_questions):
                    session.questions.add(question, through_defaults={
                        'display_order': j,
                        'question_weight': 1.0
                    })
                
                # Update passed status
                if session.total_score_achieved:
                    session.passed = session.total_score_achieved >= session.pass_threshold
                    session.save()
                
                self.exam_sessions.append(session)

    def create_user_answers(self):
        """Create user answers"""
        self.stdout.write('Creating user answers...')
        
        self.user_answers = []
        for session in self.exam_sessions:
            for question in session.questions.all():
                # 80% chance of answering each question
                if random.random() > 0.2:
                    answer = UserAnswer.objects.create(
                        user=session.user,
                        question=question,
                        exam_session=session,
                        submitted_answer_text=fake.text(max_nb_chars=200) if question.question_type != 'MCQ' else None,
                        submitted_calculation_input={'user_input': 'Step 1: Given values\nStep 2: Applied formula\nAnswer: 42'} if question.question_type == 'CALCULATION' else None,
                        raw_score=random.uniform(0, question.points),
                        weighted_score=random.uniform(0, question.points),
                        max_possible_score=question.points,
                        is_correct=random.choice([True, False]),
                        ai_feedback=fake.text(max_nb_chars=150) if random.random() > 0.5 else None,
                        evaluation_status=random.choice(['PENDING', 'EVALUATED', 'MCQ_SCORED']),
                        time_spent_seconds=random.randint(30, 300),
                        submission_time=timezone.now() - timedelta(minutes=random.randint(1, 60)),
                        retry_count=random.randint(0, 2)
                    )
                    
                    # Add MCQ choices for MCQ questions
                    if question.question_type == 'MCQ':
                        choices = list(question.choices.all())
                        if choices:
                            selected_choices = random.sample(choices, random.randint(1, min(2, len(choices))))
                            answer.mcq_choices.set(selected_choices)
                    
                    self.user_answers.append(answer)

    def create_analytics_data(self):
        """Create analytics and performance data"""
        self.stdout.write('Creating analytics data...')
        
        # User Performance Records
        for user in self.users[:20]:
            for topic in self.topics[:5]:
                for days_ago in range(0, 30, 7):  # Weekly records
                    date_recorded = timezone.now().date() - timedelta(days=days_ago)
                    
                    questions_answered = random.randint(5, 20)
                    correct_answers = random.randint(0, questions_answered)
                    
                    UserPerformanceRecord.objects.create(
                        user=user,
                        topic=topic,
                        question_type=random.choice(['MCQ', 'OPEN_ENDED', 'CALCULATION']),
                        difficulty=random.choice(['EASY', 'MEDIUM', 'HARD']),
                        date_recorded=date_recorded,
                        questions_answered=questions_answered,
                        correct_answers=correct_answers,
                        partially_correct_answers=random.randint(0, questions_answered - correct_answers),
                        total_points_earned=random.uniform(10, 50),
                        total_points_possible=random.uniform(50, 100),
                        total_time_spent_seconds=random.randint(300, 1800),
                        accuracy=correct_answers / questions_answered if questions_answered > 0 else 0,
                        average_time_per_question=random.uniform(30, 180)
                    )
        
        # User Progress
        for user in self.users[:20]:
            for topic in random.sample(self.topics, 3):
                total_questions = random.randint(50, 200)
                questions_attempted = random.randint(10, total_questions)
                
                UserProgress.objects.create(
                    user=user,
                    topic=topic,
                    total_questions_in_topic=total_questions,
                    questions_attempted=questions_attempted,
                    questions_mastered=random.randint(0, questions_attempted),
                    proficiency_level=random.choice(['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT']),
                    last_activity_date=timezone.now() - timedelta(days=random.randint(0, 30))
                )
        
        # Study Sessions
        for user in self.users[:15]:
            for _ in range(random.randint(1, 10)):
                start_time = timezone.now() - timedelta(hours=random.randint(1, 168))
                end_time = start_time + timedelta(minutes=random.randint(30, 180))
                
                StudySession.objects.create(
                    user=user,
                    start_time=start_time,
                    end_time=end_time,
                    topics_studied=[topic.id for topic in random.sample(self.topics, random.randint(1, 3))],
                    questions_answered=random.randint(5, 25),
                    correct_answers=random.randint(0, 20),
                    device_info=random.choice(['Chrome 91.0', 'Safari 14.1', 'Mobile App 2.1']),
                    session_source=random.choice(['WEB', 'ANDROID', 'IOS'])
                )

    def create_support_tickets(self):
        """Create support tickets"""
        self.stdout.write('Creating support tickets...')
        
        self.support_tickets = []
        for user in random.sample(self.users, 15):  # 15 users create tickets
            for _ in range(random.randint(1, 3)):
                ticket = SupportTicket.objects.create(
                    user=user,
                    subject=fake.sentence(),
                    description=fake.text(max_nb_chars=500),
                    ticket_type=random.choice(['QUESTION', 'BUG', 'FEATURE_REQUEST', 'BILLING', 'OTHER']),
                    status=random.choice(['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED']),
                    priority=random.choice(['LOW', 'MEDIUM', 'HIGH', 'URGENT']),
                    resolved_at=timezone.now() - timedelta(days=random.randint(1, 10)) if random.random() > 0.5 else None,
                    assigned_to=random.choice(self.users[:5]) if random.random() > 0.5 else None  # Assign to staff
                )
                
                # Add some replies
                for _ in range(random.randint(0, 3)):
                    TicketReply.objects.create(
                        ticket=ticket,
                        user=random.choice([user, ticket.assigned_to]) if ticket.assigned_to else user,
                        message=fake.text(max_nb_chars=300),
                        is_staff_reply=random.choice([True, False])
                    )
                
                self.support_tickets.append(ticket)

    def create_notifications(self):
        """Create notifications"""
        self.stdout.write('Creating notifications...')
        
        for user in self.users:
            for _ in range(random.randint(0, 10)):
                Notification.objects.create(
                    user=user,
                    title=fake.sentence(),
                    message=fake.text(max_nb_chars=200),
                    notification_type=random.choice(['SYSTEM', 'SUBSCRIPTION', 'LEARNING', 'SUPPORT']),
                    related_object_type='question' if random.random() > 0.5 else None,
                    related_object_id=random.choice(self.questions).id if self.questions and random.random() > 0.5 else None,
                    is_read=random.choice([True, False]),
                    is_sent=True,
                    send_email=random.choice([True, False]),
                    send_push=random.choice([True, False]),
                    scheduled_for=timezone.now() + timedelta(hours=random.randint(1, 48)) if random.random() > 0.7 else None,
                    metadata={'source': 'dummy_generator', 'category': fake.word()}
                )

    def create_affiliate_data(self):
        """Create affiliate program data"""
        self.stdout.write('Creating affiliate data...')
        
        # Create affiliates
        self.affiliates = []
        for user in self.users[:10]:  # 10 users become affiliates
            affiliate = Affiliate.objects.create(
                user=user,
                name=f"{user.first_name} {user.last_name}",
                email=user.email,
                website=fake.url() if random.random() > 0.5 else None,
                description=fake.text(max_nb_chars=200),
                commission_model='PURE_AFFILIATE',
                commission_rate=Decimal(str(random.uniform(5, 15))),
                fixed_fee=Decimal('0.00'),
                payment_method='bank_transfer',
                payment_details={'bank': 'Test Bank', 'account': fake.iban()},
                tracking_code=fake.lexify(text='AFF??????').upper(),
                is_active=True
            )
            self.affiliates.append(affiliate)
        
        # Create affiliate links
        self.affiliate_links = []
        for affiliate in self.affiliates:
            for _ in range(random.randint(1, 5)):
                link = AffiliateLink.objects.create(
                    affiliate=affiliate,
                    name=fake.sentence(nb_words=3),
                    link_type=random.choice(['GENERAL', 'PRODUCT', 'CAMPAIGN']),
                    target_url=fake.url(),
                    tracking_id=fake.lexify(text='TRK???????').upper(),
                    utm_campaign=fake.slug() if random.random() > 0.5 else None,
                    click_count=random.randint(0, 500),
                    is_active=True
                )
                self.affiliate_links.append(link)
        
        # Create voucher codes
        for affiliate in self.affiliates:
            for _ in range(random.randint(0, 3)):
                VoucherCode.objects.create(
                    affiliate=affiliate,
                    code=fake.lexify(text='SAVE????').upper(),
                    description=fake.sentence(),
                    code_type=random.choice(['PERCENTAGE', 'FIXED', 'FREE_TRIAL']),
                    discount_value=Decimal(str(random.uniform(5, 25))),
                    valid_from=timezone.now(),
                    valid_until=timezone.now() + timedelta(days=90),
                    max_uses=random.randint(10, 100),
                    current_uses=random.randint(0, 50),
                    minimum_purchase=Decimal('10.00'),
                    is_active=True
                )
        
        # Create conversions
        self.conversions = []
        for affiliate in self.affiliates:
            for _ in range(random.randint(1, 10)):
                conversion = Conversion.objects.create(
                    affiliate=affiliate,
                    user=random.choice(self.users),
                    affiliate_link=random.choice(self.affiliate_links) if random.random() > 0.5 else None,
                    conversion_type=random.choice(['SIGNUP', 'SUBSCRIPTION']),
                    conversion_value=Decimal(str(random.uniform(10, 100))),
                    commission_amount=Decimal(str(random.uniform(1, 15))),
                    subscription=random.choice(self.subscriptions) if self.subscriptions and random.random() > 0.5 else None,
                    ip_address=fake.ipv4(),
                    user_agent=fake.user_agent(),
                    referrer_url=fake.url(),
                    is_verified=random.choice([True, False]),
                    is_paid=random.choice([True, False]),
                    conversion_date=timezone.now() - timedelta(days=random.randint(0, 90))
                )
                self.conversions.append(conversion)

    def create_ai_integration_data(self):
        """Create AI integration data"""
        self.stdout.write('Creating AI integration data...')
        
        # AI Content Alerts
        for _ in range(20):
            AIContentAlert.objects.create(
                alert_type=random.choice(['TOPIC_UPDATE', 'QUESTION_UPDATE_SUGGESTION']),
                related_topic=random.choice(self.topics) if random.random() > 0.5 else None,
                related_question=random.choice(self.questions) if self.questions and random.random() > 0.5 else None,
                summary_of_potential_change=fake.sentence(),
                detailed_explanation=fake.text(max_nb_chars=500),
                source_urls=[fake.url() for _ in range(random.randint(1, 3))],
                ai_confidence_score=random.uniform(0.6, 0.95),
                priority=random.choice(['LOW', 'MEDIUM', 'HIGH']),
                status=random.choice(['NEW', 'UNDER_REVIEW', 'ACTION_TAKEN', 'DISMISSED']),
                admin_notes=fake.text(max_nb_chars=200) if random.random() > 0.5 else None,
                reviewed_by_admin=random.choice(self.users[:5]) if random.random() > 0.5 else None,
                reviewed_at=timezone.now() - timedelta(days=random.randint(1, 30)) if random.random() > 0.5 else None
            )
        
        # AI Evaluation Logs
        for answer in random.sample(self.user_answers, min(50, len(self.user_answers))):
            AIEvaluationLog.objects.create(
                user_answer=answer,
                prompt_used=f"Evaluate this {answer.question.question_type} answer for {answer.question.topic.name}",
                ai_response=fake.text(max_nb_chars=300),
                processing_time_ms=random.randint(500, 3000),
                success=random.choice([True, False]),
                error_message=fake.sentence() if random.random() > 0.8 else None
            )
        
        # Content Update Scan Logs
        for config in self.scan_configs:
            for _ in range(random.randint(1, 5)):
                start_time = timezone.now() - timedelta(days=random.randint(1, 30))
                ContentUpdateScanLog.objects.create(
                    scan_config=config,
                    start_time=start_time,
                    end_time=start_time + timedelta(minutes=random.randint(10, 60)),
                    topics_scanned=[topic.id for topic in random.sample(self.topics, random.randint(1, 5))],
                    questions_scanned=random.randint(10, 50),
                    alerts_generated=random.randint(0, 5),
                    status=random.choice(['COMPLETED', 'FAILED']),
                    error_message=fake.sentence() if random.random() > 0.8 else None
                )
        
        # Chatbot Conversations
        for user in random.sample(self.users, 20):
            for _ in range(random.randint(1, 3)):
                conversation = ChatbotConversation.objects.create(
                    user=user,
                    title=fake.sentence(nb_words=4),
                    is_active=random.choice([True, False])
                )
                
                # Add messages to conversation
                for i in range(random.randint(2, 10)):
                    role = 'USER' if i % 2 == 0 else 'ASSISTANT'
                    ChatbotMessage.objects.create(
                        conversation=conversation,
                        role=role,
                        content=fake.text(max_nb_chars=200),
                        processing_time_ms=random.randint(200, 2000) if role == 'ASSISTANT' else None
                    )

        # Create payments for subscriptions
        for subscription in self.subscriptions:
            # Most subscriptions have at least one payment
            if random.random() > 0.2:
                Payment.objects.create(
                    user=subscription.user,
                    user_subscription=subscription,
                    amount=subscription.pricing_plan.price,
                    currency='USD',
                    status=random.choice(['SUCCESSFUL', 'PENDING', 'FAILED']),
                    payment_gateway_transaction_id=fake.uuid4(),
                    payment_method_details={
                        'method': 'credit_card',
                        'last_four': fake.credit_card_number()[-4:],
                        'brand': random.choice(['visa', 'mastercard', 'amex'])
                    },
                    transaction_time=subscription.start_date,
                    billing_address={
                        'street': fake.street_address(),
                        'city': fake.city(),
                        'country': fake.country_code()
                    },
                    invoice_number=fake.lexify(text='INV-??????').upper()
                )

        self.stdout.write(
            self.style.SUCCESS('Dummy data generation completed successfully!')
        )
        self.stdout.write(f'Created:')
        self.stdout.write(f'- {len(self.exams)} exams')
        self.stdout.write(f'- {len(self.topics)} topics')
        self.stdout.write(f'- {len(self.questions)} questions')
        self.stdout.write(f'- {len(self.users)} users')
        self.stdout.write(f'- {len(self.subscriptions)} subscriptions')
        self.stdout.write(f'- {len(self.exam_sessions)} exam sessions')
        self.stdout.write(f'- {len(self.user_answers)} user answers')
        if hasattr(self, 'complete_user'):
            self.stdout.write(f'- 1 complete user: {self.complete_user.username}')
        if hasattr(self, 'admin_user'):
            self.stdout.write(f'- 1 admin user: {self.admin_user.username}') 