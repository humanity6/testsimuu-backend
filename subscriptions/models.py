from django.db import models
from users.models import User
from exams.models import Exam

class PricingPlan(models.Model):
    """Model for subscription pricing plans."""
    BILLING_CYCLES = (
        ('MONTHLY', 'Monthly'),
        ('QUARTERLY', 'Quarterly'),
        ('YEARLY', 'Yearly'),
        ('ONE_TIME', 'One Time'),
    )

    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True, db_index=True)
    description = models.TextField(null=True, blank=True)
    exam = models.ForeignKey(Exam, on_delete=models.PROTECT, related_name='pricing_plans', 
                           help_text="The exam or category this pricing plan applies to.")
    price = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, default='USD')
    billing_cycle = models.CharField(max_length=20, choices=BILLING_CYCLES)
    features_list = models.JSONField()
    is_active = models.BooleanField(default=True, db_index=True)
    display_order = models.IntegerField(default=0)
    payment_gateway_plan_id = models.CharField(max_length=100, null=True, blank=True, unique=True)
    trial_days = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'subscriptions_pricingplan'
        indexes = [
            models.Index(fields=['exam', 'display_order']),
        ]

    def __str__(self):
        return f"{self.name} ({self.exam.name})"

class UserSubscription(models.Model):
    """Model for user subscriptions."""
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('CANCELED', 'Canceled'),
        ('EXPIRED', 'Expired'),
        ('PENDING_PAYMENT', 'Pending Payment'),
        ('GRACE_PERIOD', 'Grace Period'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='subscriptions')
    pricing_plan = models.ForeignKey(PricingPlan, on_delete=models.PROTECT)
    start_date = models.DateTimeField(db_index=True)
    end_date = models.DateTimeField(null=True, blank=True, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, db_index=True)
    payment_gateway_subscription_id = models.CharField(max_length=100, null=True, blank=True, unique=True)
    auto_renew = models.BooleanField(default=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    renewal_reminder_sent = models.BooleanField(default=False)

    class Meta:
        db_table = 'subscriptions_usersubscription'
        ordering = ['-created_at']  # Default ordering by creation date descending
        indexes = [
            models.Index(fields=['user', 'status', 'end_date']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.pricing_plan.name}"

class Payment(models.Model):
    """Model for payment transactions."""
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('SUCCESSFUL', 'Successful'),
        ('FAILED', 'Failed'),
        ('REFUNDED', 'Refunded'),
    )

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name='payments')
    user_subscription = models.ForeignKey(UserSubscription, null=True, blank=True, on_delete=models.SET_NULL, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, db_index=True)
    payment_gateway_transaction_id = models.CharField(max_length=100, unique=True)
    payment_method_details = models.JSONField(null=True, blank=True)
    transaction_time = models.DateTimeField(db_index=True)
    billing_address = models.JSONField(null=True, blank=True)
    invoice_number = models.CharField(max_length=50, null=True, blank=True, unique=True)
    refund_reference = models.CharField(max_length=100, null=True, blank=True)
    metadata = models.JSONField(null=True, blank=True)

    class Meta:
        db_table = 'subscriptions_payment'
        indexes = [
            models.Index(fields=['user', 'transaction_time']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.amount} {self.currency} - {self.status}"

class ReferralProgram(models.Model):
    """Model for referral programs."""
    REWARD_TYPE_CHOICES = (
        ('DISCOUNT_PERCENTAGE', 'Discount Percentage'),
        ('DISCOUNT_FIXED', 'Discount Fixed Amount'),
        ('EXTEND_SUBSCRIPTION_DAYS', 'Extend Subscription Days'),
        ('CREDIT', 'Account Credit'),
    )

    name = models.CharField(max_length=100, unique=True)
    description = models.TextField()
    reward_type = models.CharField(max_length=30, choices=REWARD_TYPE_CHOICES)
    reward_value = models.DecimalField(max_digits=10, decimal_places=2)
    referrer_reward_type = models.CharField(max_length=30, choices=REWARD_TYPE_CHOICES)
    referrer_reward_value = models.DecimalField(max_digits=10, decimal_places=2)
    is_active = models.BooleanField(default=True, db_index=True)
    valid_from = models.DateField(null=True, blank=True)
    valid_until = models.DateField(null=True, blank=True)
    usage_limit = models.IntegerField(default=0)
    min_purchase_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'subscriptions_referralprogram'

    def __str__(self):
        return self.name

class UserReferral(models.Model):
    """Model for tracking user referrals."""
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('COMPLETED', 'Completed'),
        ('EXPIRED', 'Expired'),
        ('INVALID', 'Invalid'),
    )

    referrer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='referrals_made')
    referred_user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='referred_by')
    referral_program = models.ForeignKey(ReferralProgram, on_delete=models.PROTECT)
    referral_code_used = models.CharField(max_length=50, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, db_index=True)
    reward_granted_to_referrer = models.BooleanField(default=False)
    reward_granted_to_referred = models.BooleanField(default=False)
    date_referred = models.DateTimeField(auto_now_add=True)
    date_completed = models.DateTimeField(null=True, blank=True)
    conversion_subscription = models.ForeignKey(UserSubscription, null=True, blank=True, on_delete=models.SET_NULL)

    class Meta:
        db_table = 'subscriptions_userreferral'

    def __str__(self):
        return f"{self.referrer.username} referred {self.referred_user.username}" 