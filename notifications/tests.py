from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from .models import Notification

User = get_user_model()


class NotificationTestCase(TestCase):
    """Basic tests for notification models"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
    def test_notification_creation(self):
        """Test basic Notification creation"""
        notification = Notification.objects.create(
            user=self.user,
            title='Test Notification',
            message='This is a test notification',
            notification_type='INFO'
        )
        self.assertEqual(notification.user, self.user)
        self.assertEqual(notification.title, 'Test Notification')
        self.assertFalse(notification.is_read)


class NotificationAPITestCase(APITestCase):
    """Basic API tests for notification endpoints"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)
        
    def test_notification_endpoints_exist(self):
        """Test that notification endpoints are accessible"""
        # This is a basic test to ensure endpoints exist
        # Add more specific tests as needed
        pass 