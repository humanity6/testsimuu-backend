from django.test import TestCase
from django.contrib.auth import get_user_model
from .models import Question
from exams.models import Exam

User = get_user_model()

class QuestionTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.exam = Exam.objects.create(
            name='Test Exam',
            slug='test-exam',
            description='Test exam for questions',
            is_active=True,
            display_order=1
        )

    def test_question_creation(self):
        """Test basic question creation"""
        question = Question.objects.create(
            exam=self.exam,
            text='What is 2+2?',
            question_type='OPEN_ENDED',
            difficulty='EASY',
            created_by=self.user
        )
        self.assertEqual(question.text, 'What is 2+2?')
        self.assertEqual(question.question_type, 'OPEN_ENDED')
        self.assertEqual(question.created_by, self.user)
        self.assertEqual(question.exam, self.exam) 