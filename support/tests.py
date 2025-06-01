from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from .models import SupportTicket, TicketReply, FAQItem

User = get_user_model()


class SupportTestCase(TestCase):
    """Basic tests for support models"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
    def test_support_ticket_creation(self):
        """Test basic SupportTicket creation"""
        ticket = SupportTicket.objects.create(
            user=self.user,
            subject='Test Support Ticket',
            description='This is a test support ticket',
            priority='MEDIUM',
            ticket_type='QUESTION'
        )
        self.assertEqual(ticket.user, self.user)
        self.assertEqual(ticket.subject, 'Test Support Ticket')
        self.assertEqual(ticket.status, 'OPEN')
        
    def test_ticket_reply_creation(self):
        """Test basic TicketReply creation"""
        ticket = SupportTicket.objects.create(
            user=self.user,
            subject='Test Support Ticket',
            description='This is a test support ticket',
            priority='MEDIUM',
            ticket_type='QUESTION'
        )
        
        reply = TicketReply.objects.create(
            ticket=ticket,
            user=self.user,
            message='This is a test reply',
            is_staff_reply=False
        )
        self.assertEqual(reply.ticket, ticket)
        self.assertEqual(reply.user, self.user)
        self.assertEqual(reply.message, 'This is a test reply')


class SupportAPITestCase(APITestCase):
    """Basic API tests for support endpoints"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)
        
    def test_support_endpoints_exist(self):
        """Test that support endpoints are accessible"""
        # This is a basic test to ensure endpoints exist
        # Add more specific tests as needed 