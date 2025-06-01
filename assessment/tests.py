from django.test import TestCase
from django.contrib.auth import get_user_model
from .models import ExamSession
from exams.models import Exam

User = get_user_model()


class AssessmentTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.exam = Exam.objects.create(
            name='Test Exam',
            slug='test-exam',
            description='Test exam for assessment',
            is_active=True,
            display_order=1
        )

    def test_exam_session_creation(self):
        """Test basic exam session creation"""
        from django.utils import timezone
        from datetime import timedelta
        
        start_time = timezone.now()
        session = ExamSession.objects.create(
            user=self.user,
            exam=self.exam,
            title='Test Session',
            session_type='PRACTICE',
            start_time=start_time,
            end_time_expected=start_time + timedelta(hours=1),
            status='IN_PROGRESS',
            total_possible_score=100,
            pass_threshold=60,
            time_limit_seconds=3600
        )
        self.assertEqual(session.user, self.user)
        self.assertEqual(session.exam, self.exam)
        self.assertEqual(session.title, 'Test Session') 