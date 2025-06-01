from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from decimal import Decimal
import json

from users.models import User
from .models import Affiliate, AffiliateLink, VoucherCode, Conversion, ClickEvent
from .services import AffiliateTrackingService


class AffiliateModelTestCase(TestCase):
    def setUp(self):
        # Create a test user
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpassword"
        )
        
        # Create an affiliate profile
        self.tracking_service = AffiliateTrackingService()
        self.tracking_code = self.tracking_service.generate_tracking_code()
        
        self.affiliate = Affiliate.objects.create(
            user=self.user,
            name="Test Affiliate",
            email="test@example.com",
            commission_model="PURE_AFFILIATE",
            commission_rate=10.00,
            tracking_code=self.tracking_code
        )
    
    def test_affiliate_creation(self):
        """Test that the affiliate was created correctly."""
        self.assertEqual(self.affiliate.user, self.user)
        self.assertEqual(self.affiliate.name, "Test Affiliate")
        self.assertEqual(self.affiliate.commission_rate, 10.00)
        self.assertTrue(self.affiliate.is_active)
    
    def test_total_earnings_method(self):
        """Test the total_earnings method."""
        # Initially should be 0
        self.assertEqual(self.affiliate.total_earnings(), 0)


class AffiliateLinkTestCase(TestCase):
    def setUp(self):
        # Create a test user and affiliate
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpassword"
        )
        
        self.tracking_service = AffiliateTrackingService()
        self.tracking_code = self.tracking_service.generate_tracking_code()
        
        self.affiliate = Affiliate.objects.create(
            user=self.user,
            name="Test Affiliate",
            email="test@example.com",
            commission_model="PURE_AFFILIATE",
            commission_rate=10.00,
            tracking_code=self.tracking_code
        )
        
        # Create an affiliate link
        self.link = self.tracking_service.create_affiliate_link(
            affiliate=self.affiliate,
            target_url="https://testsimu.com/product/1",
            name="Test Product Link",
            link_type="PRODUCT"
        )
    
    def test_link_creation(self):
        """Test that the affiliate link was created correctly."""
        self.assertEqual(self.link.affiliate, self.affiliate)
        self.assertEqual(self.link.name, "Test Product Link")
        self.assertEqual(self.link.target_url, "https://testsimu.com/product/1")
        self.assertEqual(self.link.link_type, "PRODUCT")
        self.assertTrue(self.link.is_active)
    
    def test_full_url_method(self):
        """Test the full_url method for generating tracking URLs."""
        full_url = self.link.full_url()
        self.assertIn(self.affiliate.tracking_code, full_url)
        self.assertIn(self.link.tracking_id, full_url)
        self.assertIn("utm_source=affiliate", full_url)


class VoucherCodeTestCase(TestCase):
    def setUp(self):
        # Create a test user and affiliate
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpassword"
        )
        
        self.tracking_service = AffiliateTrackingService()
        self.tracking_code = self.tracking_service.generate_tracking_code()
        
        self.affiliate = Affiliate.objects.create(
            user=self.user,
            name="Test Affiliate",
            email="test@example.com",
            commission_model="PURE_AFFILIATE",
            commission_rate=10.00,
            tracking_code=self.tracking_code
        )
        
        # Create a voucher code
        self.voucher = self.tracking_service.create_voucher_code(
            affiliate=self.affiliate,
            code_type="PERCENTAGE",
            discount_value=15,
            description="15% off",
            max_uses=100
        )
    
    def test_voucher_creation(self):
        """Test that the voucher code was created correctly."""
        self.assertEqual(self.voucher.affiliate, self.affiliate)
        self.assertEqual(self.voucher.code_type, "PERCENTAGE")
        self.assertEqual(self.voucher.discount_value, 15)
        self.assertEqual(self.voucher.current_uses, 0)
        self.assertEqual(self.voucher.max_uses, 100)
        self.assertTrue(self.voucher.is_active)
    
    def test_is_valid_method(self):
        """Test the is_valid method."""
        # Should be valid initially
        self.assertTrue(self.voucher.is_valid())
        
        # Set max_uses to 1 and current_uses to 1
        self.voucher.max_uses = 1
        self.voucher.current_uses = 1
        self.voucher.save()
        
        # Should no longer be valid
        self.assertFalse(self.voucher.is_valid())


class AffiliateAPITestCase(TestCase):
    def setUp(self):
        # Create a test user and affiliate
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpassword"
        )
        
        self.tracking_service = AffiliateTrackingService()
        self.tracking_code = self.tracking_service.generate_tracking_code()
        
        self.affiliate = Affiliate.objects.create(
            user=self.user,
            name="Test Affiliate",
            email="test@example.com",
            commission_model="PURE_AFFILIATE",
            commission_rate=10.00,
            tracking_code=self.tracking_code
        )
        
        # Create an affiliate link
        self.link = self.tracking_service.create_affiliate_link(
            affiliate=self.affiliate,
            target_url="https://testsimu.com/product/1",
            name="Test Product Link",
            link_type="PRODUCT"
        )
        
        # Create a voucher code
        self.voucher = self.tracking_service.create_voucher_code(
            affiliate=self.affiliate,
            code_type="PERCENTAGE",
            discount_value=15,
            description="15% off",
            max_uses=100
        )
        
        # Set up the API client
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def test_get_affiliate_profile(self):
        """Test retrieving the affiliate profile."""
        url = reverse('affiliate-profile')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], self.affiliate.name)
        self.assertEqual(response.data['tracking_code'], self.affiliate.tracking_code)
    
    def test_get_affiliate_links(self):
        """Test retrieving affiliate links."""
        url = reverse('affiliate-link-list')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Check that response has pagination structure
        self.assertIn('results', response.data)
        self.assertIn('count', response.data)
        # The response should contain at least our test link
        results = response.data['results']
        self.assertGreaterEqual(len(results), 1)
        # Find our specific test link
        test_link = next((link for link in results if link['name'] == self.link.name), None)
        self.assertIsNotNone(test_link)
        self.assertEqual(test_link['name'], self.link.name)
    
    def test_create_affiliate_link(self):
        """Test creating a new affiliate link."""
        url = reverse('affiliate-link-list')
        data = {
            'name': 'New Test Link',
            'link_type': 'GENERAL',
            'target_url': 'https://testsimu.com/features'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'New Test Link')
        self.assertEqual(response.data['target_url'], 'https://testsimu.com/features')
        
        # Check that the link was actually created in the database
        self.assertEqual(AffiliateLink.objects.count(), 2)
    
    def test_get_voucher_codes(self):
        """Test retrieving voucher codes."""
        url = reverse('voucher-code-list')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Check that response has pagination structure
        self.assertIn('results', response.data)
        self.assertIn('count', response.data)
        # The response should contain at least our test voucher
        results = response.data['results']
        self.assertGreaterEqual(len(results), 1)
        # Find our specific test voucher
        test_voucher = next((voucher for voucher in results if voucher['code'] == self.voucher.code), None)
        self.assertIsNotNone(test_voucher)
        self.assertEqual(test_voucher['code'], self.voucher.code)
    
    def test_track_click(self):
        """Test tracking a click on an affiliate link."""
        url = reverse('track-click')
        data = {
            'tracking_id': self.link.tracking_id
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['success'], True)
        
        # Check that the click was recorded
        self.link.refresh_from_db()
        self.assertEqual(self.link.click_count, 1)
        self.assertEqual(ClickEvent.objects.count(), 1)
    
    def test_apply_voucher(self):
        """Test applying a voucher code."""
        url = reverse('apply-voucher')
        data = {
            'code': self.voucher.code
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['success'], True)
        self.assertEqual(response.data['voucher']['code'], self.voucher.code)
        self.assertEqual(response.data['voucher']['discount_value'], self.voucher.discount_value) 