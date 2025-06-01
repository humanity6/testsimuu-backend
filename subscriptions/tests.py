from django.test import TestCase
from django.contrib.auth import get_user_model
from .models import PricingPlan
from exams.models import Exam

User = get_user_model()


class SubscriptionTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.exam = Exam.objects.create(
            name='Test Exam',
            slug='test-exam',
            description='Test exam for subscriptions',
            is_active=True,
            display_order=1
        )

    def test_pricing_plan_creation(self):
        """Test basic pricing plan creation"""
        plan = PricingPlan.objects.create(
            name='Test Plan',
            slug='test-plan',
            exam=self.exam,
            price=9.99,
            billing_cycle='MONTHLY',
            features_list=['Feature 1', 'Feature 2'],
            is_active=True
        )
        self.assertEqual(plan.name, 'Test Plan')
        self.assertEqual(plan.slug, 'test-plan')
        self.assertEqual(float(plan.price), 9.99)
        self.assertEqual(plan.exam, self.exam) 