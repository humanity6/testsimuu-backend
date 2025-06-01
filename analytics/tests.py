from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from exams.models import Exam
from .models import UserPerformanceRecord, UserProgress, StudySession

User = get_user_model()


class AnalyticsTestCase(TestCase):
    """Basic tests for analytics models"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
    def test_user_performance_record_creation(self):
        """Test basic UserPerformanceRecord creation"""
        from django.utils import timezone
        record = UserPerformanceRecord.objects.create(
            user=self.user,
            date_recorded=timezone.now().date(),
            questions_answered=10,
            correct_answers=8,
            total_points_earned=80,
            total_points_possible=100
        )
        self.assertEqual(record.user, self.user)
        self.assertEqual(record.questions_answered, 10)
        self.assertEqual(record.correct_answers, 8)
        
    def test_user_progress_creation(self):
        """Test basic UserProgress creation"""
        from django.utils import timezone
        from questions.models import Topic
        
        # Create a topic if one doesn't exist
        topic, created = Topic.objects.get_or_create(
            name='Test Topic',
            defaults={'slug': 'test-topic', 'description': 'Test topic'}
        )
        
        progress = UserProgress.objects.create(
            user=self.user,
            topic=topic,
            total_questions_in_topic=50,
            questions_attempted=10,
            questions_mastered=5,
            proficiency_level='BEGINNER',
            last_activity_date=timezone.now()
        )
        self.assertEqual(progress.user, self.user)
        self.assertEqual(progress.topic, topic)
        self.assertEqual(progress.proficiency_level, 'BEGINNER')


class AnalyticsAPITestCase(APITestCase):
    """Basic API tests for analytics endpoints"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)
        
    def test_analytics_endpoints_exist(self):
        """Test that analytics endpoints are accessible"""
        # This is a basic test to ensure endpoints exist
        # Add more specific tests as needed
        pass 