from django.db import models
from django.utils import timezone
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from users.models import User
from subscriptions.models import UserSubscription, Payment

class Affiliate(models.Model):
    """Model for affiliates/influencers who promote the platform."""
    COMMISSION_MODEL_CHOICES = (
        ('PURE_AFFILIATE', 'Pure Affiliate (% of sales)'),
        ('FIXED_PERFORMANCE', 'Fixed + Performance'),
    )
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='affiliate_profile')
    name = models.CharField(max_length=100)
    email = models.EmailField()
    website = models.URLField(blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    
    # Link to affiliate plan (new field)
    affiliate_plan = models.ForeignKey('AffiliatePlan', on_delete=models.SET_NULL, blank=True, null=True, related_name='affiliates')
    
    # Commission model and rates (kept for backward compatibility)
    commission_model = models.CharField(max_length=20, choices=COMMISSION_MODEL_CHOICES, default='PURE_AFFILIATE')
    commission_rate = models.DecimalField(max_digits=5, decimal_places=2, help_text="Percentage or fixed amount per conversion")
    fixed_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Monthly fixed payment (for Fixed + Performance model)")
    
    # Payment details
    payment_method = models.CharField(max_length=100, blank=True, null=True)
    payment_details = models.JSONField(blank=True, null=True)
    
    # Tracking
    tracking_code = models.CharField(max_length=20, unique=True, help_text="Unique code for this affiliate")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.name} ({self.tracking_code})"
    
    def total_earnings(self):
        """Calculate total earnings for this affiliate."""
        payments = AffiliatePayment.objects.filter(affiliate=self)
        return sum(payment.amount for payment in payments)
    
    def pending_earnings(self):
        """Calculate pending earnings (not yet paid out)."""
        conversions = Conversion.objects.filter(affiliate=self, is_paid=False)
        return sum(conversion.commission_amount for conversion in conversions)


class AffiliateLink(models.Model):
    """Model for trackable affiliate links."""
    LINK_TYPE_CHOICES = (
        ('GENERAL', 'General Link'),
        ('PRODUCT', 'Product Specific'),
        ('CAMPAIGN', 'Campaign Specific'),
    )
    
    affiliate = models.ForeignKey(Affiliate, on_delete=models.CASCADE, related_name='links')
    name = models.CharField(max_length=100, help_text="Internal name for this link")
    link_type = models.CharField(max_length=20, choices=LINK_TYPE_CHOICES)
    
    # Where this link points to
    target_url = models.URLField(help_text="Target URL (without tracking parameters)")
    
    # For product-specific links
    content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE, blank=True, null=True)
    object_id = models.PositiveIntegerField(blank=True, null=True)
    linked_object = GenericForeignKey('content_type', 'object_id')
    
    # Tracking
    tracking_id = models.CharField(max_length=50, unique=True, help_text="Unique ID for this link")
    utm_medium = models.CharField(max_length=50, default='affiliate')
    utm_campaign = models.CharField(max_length=50, blank=True, null=True)
    
    click_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.name} - {self.affiliate.name}"
    
    def full_url(self):
        """Generate the full URL with tracking parameters."""
        separator = '&' if '?' in self.target_url else '?'
        tracking_params = f"ref={self.affiliate.tracking_code}&utm_source=affiliate&utm_medium={self.utm_medium}"
        
        if self.utm_campaign:
            tracking_params += f"&utm_campaign={self.utm_campaign}"
            
        tracking_params += f"&aff_id={self.tracking_id}"
        
        return f"{self.target_url}{separator}{tracking_params}"
    
    def conversion_rate(self):
        """Calculate conversion rate for this link."""
        if not self.click_count:
            return 0
        conversions = Conversion.objects.filter(affiliate_link=self).count()
        return (conversions / self.click_count) * 100


class VoucherCode(models.Model):
    """Model for affiliate voucher/discount codes."""
    CODE_TYPE_CHOICES = (
        ('PERCENTAGE', 'Percentage Discount'),
        ('FIXED', 'Fixed Amount Discount'),
        ('FREE_TRIAL', 'Extended Free Trial'),
    )
    
    affiliate = models.ForeignKey(Affiliate, on_delete=models.CASCADE, related_name='voucher_codes')
    code = models.CharField(max_length=20, unique=True)
    description = models.CharField(max_length=200)
    
    # Discount details
    code_type = models.CharField(max_length=20, choices=CODE_TYPE_CHOICES)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2, help_text="Percentage or fixed amount")
    
    # Validity
    valid_from = models.DateTimeField(default=timezone.now)
    valid_until = models.DateTimeField(blank=True, null=True)
    max_uses = models.PositiveIntegerField(default=0, help_text="0 for unlimited")
    current_uses = models.PositiveIntegerField(default=0)
    
    # Restrictions
    minimum_purchase = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    applicable_products = models.JSONField(blank=True, null=True, help_text="List of product IDs this code applies to")
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.code} - {self.affiliate.name}"
    
    def is_valid(self):
        """Check if the voucher code is still valid."""
        now = timezone.now()
        
        # Check if code is active
        if not self.is_active:
            return False
            
        # Check validity period
        if now < self.valid_from:
            return False
            
        if self.valid_until and now > self.valid_until:
            return False
            
        # Check usage limit
        if self.max_uses > 0 and self.current_uses >= self.max_uses:
            return False
            
        return True


class Conversion(models.Model):
    """Model for tracking affiliate conversions."""
    CONVERSION_TYPE_CHOICES = (
        ('SIGNUP', 'User Signup'),
        ('DOWNLOAD', 'App Download'),
        ('SUBSCRIPTION', 'Subscription Purchase'),
    )
    
    affiliate = models.ForeignKey(Affiliate, on_delete=models.CASCADE, related_name='conversions')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='affiliate_conversions')
    
    # Source of conversion
    affiliate_link = models.ForeignKey(AffiliateLink, on_delete=models.SET_NULL, blank=True, null=True, related_name='conversions')
    voucher_code = models.ForeignKey(VoucherCode, on_delete=models.SET_NULL, blank=True, null=True, related_name='conversions')
    
    # Conversion details
    conversion_type = models.CharField(max_length=20, choices=CONVERSION_TYPE_CHOICES)
    conversion_value = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    commission_amount = models.DecimalField(max_digits=10, decimal_places=2)
    
    # Associated subscription/payment if applicable
    subscription = models.ForeignKey(UserSubscription, on_delete=models.SET_NULL, blank=True, null=True, related_name='affiliate_conversions')
    payment = models.ForeignKey(Payment, on_delete=models.SET_NULL, blank=True, null=True, related_name='affiliate_conversions')
    
    # Tracking
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    user_agent = models.TextField(blank=True, null=True)
    referrer_url = models.URLField(blank=True, null=True)
    
    is_verified = models.BooleanField(default=False)
    is_paid = models.BooleanField(default=False)
    conversion_date = models.DateTimeField(default=timezone.now)
    verification_date = models.DateTimeField(blank=True, null=True)
    
    def __str__(self):
        return f"{self.get_conversion_type_display()} - {self.affiliate.name} - {self.user.email}"


class AffiliatePayment(models.Model):
    """Model for tracking affiliate payments."""
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('PROCESSING', 'Processing'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed'),
    )
    
    affiliate = models.ForeignKey(Affiliate, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, default='EUR')
    
    # Payment details
    payment_method = models.CharField(max_length=50)
    transaction_id = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    
    # Period covered
    period_start = models.DateField()
    period_end = models.DateField()
    
    # SumUp integration
    sumup_checkout_id = models.CharField(max_length=100, blank=True, null=True)
    sumup_transaction_code = models.CharField(max_length=100, blank=True, null=True)
    
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Related conversions
    conversions = models.ManyToManyField(Conversion, related_name='affiliate_payments')
    
    def __str__(self):
        return f"{self.affiliate.name} - {self.amount} {self.currency} - {self.get_status_display()}"


class ClickEvent(models.Model):
    """Model for tracking affiliate link clicks."""
    affiliate = models.ForeignKey(Affiliate, on_delete=models.CASCADE, related_name='clicks')
    affiliate_link = models.ForeignKey(AffiliateLink, on_delete=models.CASCADE, related_name='click_events')
    
    # User info (if available)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, blank=True, null=True, related_name='affiliate_clicks')
    session_id = models.CharField(max_length=100, blank=True, null=True)
    
    # Request details
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    user_agent = models.TextField(blank=True, null=True)
    referrer_url = models.URLField(blank=True, null=True)
    
    timestamp = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"Click on {self.affiliate_link.name} by {self.user or 'Anonymous'}"


class AffiliatePlan(models.Model):
    """Model for managing different affiliate plan types that admins can configure."""
    PLAN_TYPE_CHOICES = (
        ('PURE_AFFILIATE', 'Pure Affiliate (Commission only)'),
        ('FIXED_PLUS_COMMISSION', 'Fixed Payment + Commission'),
        ('TIERED_COMMISSION', 'Tiered Commission'),
    )
    
    name = models.CharField(max_length=100, help_text="Plan name (e.g., 'Influencer Basic', 'Premium Partner')")
    description = models.TextField(help_text="Description of what this plan offers")
    plan_type = models.CharField(max_length=25, choices=PLAN_TYPE_CHOICES)
    
    # Commission settings
    commission_per_download = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.00,
        help_text="Fixed amount per download/signup (in EUR)"
    )
    commission_per_subscription = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.00,
        help_text="Fixed amount per successful subscription (in EUR)"
    )
    commission_percentage = models.DecimalField(
        max_digits=5, decimal_places=2, default=0.00,
        help_text="Percentage of subscription value (0-100)"
    )
    
    # Fixed payment (for combination plans)
    fixed_monthly_payment = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.00,
        help_text="Fixed monthly payment (in EUR)"
    )
    
    # Tiered commission settings (JSON format)
    tier_settings = models.JSONField(
        blank=True, null=True,
        help_text="Tiered commission settings in JSON format"
    )
    
    # Plan requirements and limits
    minimum_followers = models.PositiveIntegerField(
        default=0, help_text="Minimum followers required for this plan"
    )
    minimum_monthly_conversions = models.PositiveIntegerField(
        default=0, help_text="Minimum monthly conversions to maintain this plan"
    )
    
    # Availability
    is_active = models.BooleanField(default=True)
    is_auto_approval = models.BooleanField(
        default=False, help_text="Whether applications for this plan are auto-approved"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
    
    def __str__(self):
        return f"{self.name} ({self.get_plan_type_display()})"
    
    def get_commission_summary(self):
        """Get a summary of commission structure."""
        summary = []
        
        if self.commission_per_download > 0:
            summary.append(f"€{self.commission_per_download} per download")
        
        if self.commission_per_subscription > 0:
            summary.append(f"€{self.commission_per_subscription} per subscription")
        
        if self.commission_percentage > 0:
            summary.append(f"{self.commission_percentage}% of subscription value")
        
        if self.fixed_monthly_payment > 0:
            summary.append(f"€{self.fixed_monthly_payment} fixed monthly")
        
        return " + ".join(summary) if summary else "No commission"


class AffiliateApplication(models.Model):
    """Model for tracking affiliate applications."""
    STATUS_CHOICES = (
        ('PENDING', 'Pending Review'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
        ('UNDER_REVIEW', 'Under Review'),
    )
    
    # Applicant information
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='affiliate_applications')
    requested_plan = models.ForeignKey(AffiliatePlan, on_delete=models.CASCADE, related_name='applications')
    
    # Application details
    business_name = models.CharField(max_length=200, blank=True, null=True)
    website_url = models.URLField(blank=True, null=True)
    social_media_links = models.JSONField(
        blank=True, null=True,
        help_text="Social media profiles in JSON format"
    )
    audience_description = models.TextField(
        help_text="Description of audience and reach"
    )
    promotion_strategy = models.TextField(
        help_text="How they plan to promote the platform"
    )
    follower_count = models.PositiveIntegerField(
        default=0, help_text="Total follower count across platforms"
    )
    
    # Application status
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    admin_notes = models.TextField(blank=True, null=True)
    reviewed_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, blank=True, null=True,
        related_name='reviewed_affiliate_applications'
    )
    reviewed_at = models.DateTimeField(blank=True, null=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.user.email} - {self.requested_plan.name} ({self.status})" 