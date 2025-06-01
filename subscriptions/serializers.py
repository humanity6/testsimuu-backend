from rest_framework import serializers
from django.db import models
from django.utils import timezone
from datetime import datetime, timedelta
from .models import PricingPlan, UserSubscription, ReferralProgram, UserReferral, Payment
from users.models import User
from exams.models import Exam


class PricingPlanSerializer(serializers.ModelSerializer):
    exam_id = serializers.IntegerField(source='exam.id', read_only=True)
    exam_name = serializers.StringRelatedField(source='exam.name', read_only=True)
    exam_slug = serializers.SlugRelatedField(source='exam', slug_field='slug', read_only=True)
    
    class Meta:
        model = PricingPlan
        fields = ['id', 'name', 'slug', 'description', 'exam_id', 'exam_name', 'exam_slug',
                 'price', 'currency', 'billing_cycle', 'features_list', 'trial_days', 
                 'display_order', 'is_active', 'created_at', 'updated_at']


class PricingPlanDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingPlan
        fields = ['id', 'name', 'slug', 'description', 'price', 'currency',
                 'billing_cycle', 'features_list', 'trial_days', 'display_order',
                 'created_at', 'updated_at']


class UserSubscriptionSerializer(serializers.ModelSerializer):
    pricing_plan_name = serializers.StringRelatedField(source='pricing_plan.name', read_only=True)
    pricing_plan_price = serializers.DecimalField(
        source='pricing_plan.price', 
        max_digits=10, 
        decimal_places=2, 
        read_only=True
    )
    pricing_plan_currency = serializers.CharField(source='pricing_plan.currency', read_only=True)
    pricing_plan_billing_cycle = serializers.CharField(source='pricing_plan.billing_cycle', read_only=True)
    exam_id = serializers.IntegerField(source='pricing_plan.exam.id', read_only=True)
    exam_name = serializers.StringRelatedField(source='pricing_plan.exam.name', read_only=True)
    exam_slug = serializers.SlugRelatedField(source='pricing_plan.exam', slug_field='slug', read_only=True)
    
    class Meta:
        model = UserSubscription
        fields = ['id', 'pricing_plan_id', 'pricing_plan_name', 'pricing_plan_price', 
                 'pricing_plan_currency', 'pricing_plan_billing_cycle', 'exam_id', 
                 'exam_name', 'exam_slug', 'start_date', 'end_date', 'status', 
                 'auto_renew', 'cancelled_at']
        read_only_fields = ['start_date', 'end_date', 'status', 'cancelled_at']


class UserSubscriptionCreateSerializer(serializers.ModelSerializer):
    pricing_plan_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = UserSubscription
        fields = ['pricing_plan_id']
        
    def validate_pricing_plan_id(self, value):
        try:
            pricing_plan = PricingPlan.objects.get(id=value, is_active=True)
            return value
        except PricingPlan.DoesNotExist:
            raise serializers.ValidationError("Selected pricing plan does not exist or is not active.")
    
    def create(self, validated_data):
        user = self.context['request'].user
        pricing_plan = PricingPlan.objects.get(id=validated_data['pricing_plan_id'])
        
        # Set the start date to now
        start_date = timezone.now()
        
        # Calculate end date based on billing cycle and trial days
        trial_period = timedelta(days=pricing_plan.trial_days)
        
        if pricing_plan.billing_cycle == 'MONTHLY':
            # Add 1 month + trial days
            # For simplicity, approximating a month as 30 days
            end_date = start_date + timedelta(days=30) + trial_period
        elif pricing_plan.billing_cycle == 'QUARTERLY':
            # Add 3 months + trial days
            end_date = start_date + timedelta(days=90) + trial_period
        elif pricing_plan.billing_cycle == 'YEARLY':
            # Add 1 year + trial days
            end_date = start_date + timedelta(days=365) + trial_period
        elif pricing_plan.billing_cycle == 'ONE_TIME':
            # For one-time plans, set a far future date or null
            # Here we're setting it to 10 years in the future
            end_date = start_date + timedelta(days=3650)
        else:
            # Default fallback
            end_date = start_date + timedelta(days=30)
        
        # Create the subscription
        subscription = UserSubscription.objects.create(
            user=user,
            pricing_plan=pricing_plan,
            start_date=start_date,
            end_date=end_date,
            status='PENDING_PAYMENT',
            auto_renew=True
        )
        
        return subscription


class SubscriptionCancelSerializer(serializers.Serializer):
    # This is just a serializer for cancel action, doesn't need fields
    pass


class ReferralProgramSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferralProgram
        fields = [
            'id', 'name', 'description', 'reward_type', 'reward_value',
            'referrer_reward_type', 'referrer_reward_value', 'valid_from',
            'valid_until', 'usage_limit', 'min_purchase_amount'
        ]


class ReferralProgramDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferralProgram
        fields = [
            'id', 'name', 'description', 'reward_type', 'reward_value',
            'referrer_reward_type', 'referrer_reward_value', 'valid_from',
            'valid_until', 'usage_limit', 'min_purchase_amount', 'is_active',
            'created_at', 'updated_at'
        ]


class UserReferralSerializer(serializers.ModelSerializer):
    referrer_username = serializers.CharField(source='referrer.username', read_only=True)
    referred_username = serializers.CharField(source='referred_user.username', read_only=True)
    program_name = serializers.CharField(source='referral_program.name', read_only=True)
    
    class Meta:
        model = UserReferral
        fields = [
            'id', 'referrer_username', 'referred_username', 'program_name', 
            'referral_code_used', 'status', 'reward_granted_to_referrer',
            'reward_granted_to_referred', 'date_referred', 'date_completed'
        ]
        read_only_fields = ['status', 'reward_granted_to_referrer', 'reward_granted_to_referred']


class ReferralCodeApplySerializer(serializers.Serializer):
    referral_code = serializers.CharField(max_length=50, required=True)
    
    def validate_referral_code(self, value):
        # Check if the current user is already referred
        user = self.context['request'].user
        if UserReferral.objects.filter(referred_user=user).exists():
            raise serializers.ValidationError("You have already been referred.")
        
        # Find referrer with this code
        try:
            referrer = User.objects.get(username=value)
            
            # Find active referral program
            now = timezone.now().date()
            referral_program = ReferralProgram.objects.filter(
                is_active=True,
                valid_from__lte=now,
            ).filter(
                models.Q(valid_until__isnull=True) | models.Q(valid_until__gte=now)
            ).first()
            
            if not referral_program:
                raise serializers.ValidationError("No active referral program found.")
                
            # Don't allow self-referrals
            if referrer.id == user.id:
                raise serializers.ValidationError("You cannot refer yourself.")
                
            # Store these for later use in create()
            self.context['referrer'] = referrer
            self.context['referral_program'] = referral_program
            
            return value
            
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid referral code.")


class PaymentSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source='user.email', read_only=True)
    
    class Meta:
        model = Payment
        fields = [
            'id', 'user_email', 'amount', 'currency', 'status',
            'payment_gateway_transaction_id', 'transaction_time',
            'invoice_number', 'refund_reference', 
        ]
        read_only_fields = ['id', 'user_email', 'payment_gateway_transaction_id', 
                          'transaction_time', 'invoice_number']


class PaymentDetailSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source='user.email', read_only=True)
    subscription_plan = serializers.SerializerMethodField()
    
    class Meta:
        model = Payment
        fields = [
            'id', 'user_email', 'amount', 'currency', 'status',
            'payment_gateway_transaction_id', 'payment_method_details',
            'transaction_time', 'billing_address', 'invoice_number',
            'refund_reference', 'subscription_plan', 'metadata'
        ]
    
    def get_subscription_plan(self, obj):
        if obj.user_subscription:
            return {
                'id': obj.user_subscription.pricing_plan.id,
                'name': obj.user_subscription.pricing_plan.name,
                'billing_cycle': obj.user_subscription.pricing_plan.billing_cycle
            }
        return None


class SumUpWebhookSerializer(serializers.Serializer):
    event_type = serializers.CharField(required=True)
    transaction_id = serializers.CharField(required=True)
    status = serializers.CharField(required=True)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    currency = serializers.CharField(required=False)
    payment_date = serializers.DateTimeField(required=False)
    metadata = serializers.JSONField(required=False)


class BundleSubscriptionSerializer(serializers.Serializer):
    """Serializer for creating multiple subscriptions in a bundle."""
    pricing_plan_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=True,
        min_length=1
    )
    
    def validate_pricing_plan_ids(self, value):
        """Validate that all pricing plans exist and are active."""
        if not value:
            raise serializers.ValidationError("At least one pricing plan must be selected.")
        
        # Check for duplicate IDs
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Duplicate pricing plan IDs found.")
        
        # Verify all plans exist and are active
        for plan_id in value:
            try:
                plan = PricingPlan.objects.get(id=plan_id, is_active=True)
            except PricingPlan.DoesNotExist:
                raise serializers.ValidationError(f"Pricing plan with ID {plan_id} does not exist or is not active.")
        
        return value


class PaymentVerificationSerializer(serializers.Serializer):
    """Serializer for verifying payment status."""
    transaction_id = serializers.CharField(required=True)
    
    def validate_transaction_id(self, value):
        """Validate that the transaction ID is valid."""
        if not value:
            raise serializers.ValidationError("Transaction ID is required.")
        return value


# Admin serializers for subscription management
class AdminPricingPlanSerializer(serializers.ModelSerializer):
    exam_name = serializers.CharField(source='exam.name', read_only=True)
    subscription_count = serializers.SerializerMethodField()
    
    class Meta:
        model = PricingPlan
        fields = [
            'id', 'name', 'slug', 'description', 'exam', 'exam_name', 'price', 
            'currency', 'billing_cycle', 'features_list', 'trial_days', 
            'is_active', 'display_order', 'payment_gateway_plan_id',
            'subscription_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'exam_name', 'subscription_count']
    
    def get_subscription_count(self, obj):
        return obj.usersubscription_set.count()


class AdminPricingPlanCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingPlan
        fields = [
            'name', 'slug', 'description', 'exam', 'price', 'currency', 
            'billing_cycle', 'features_list', 'trial_days', 'is_active', 
            'display_order', 'payment_gateway_plan_id'
        ]


class AdminPricingPlanUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingPlan
        fields = [
            'name', 'description', 'price', 'currency', 'billing_cycle', 
            'features_list', 'trial_days', 'is_active', 'display_order', 
            'payment_gateway_plan_id'
        ]


class AdminUserSubscriptionSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_username = serializers.CharField(source='user.username', read_only=True)
    pricing_plan_name = serializers.CharField(source='pricing_plan.name', read_only=True)
    exam_name = serializers.CharField(source='pricing_plan.exam.name', read_only=True)
    
    class Meta:
        model = UserSubscription
        fields = [
            'id', 'user', 'user_email', 'user_username', 'pricing_plan', 
            'pricing_plan_name', 'exam_name', 'start_date', 'end_date', 
            'status', 'auto_renew', 'cancelled_at', 'payment_gateway_subscription_id',
            'renewal_reminder_sent', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'user_email', 
                           'user_username', 'pricing_plan_name', 'exam_name']


class AdminUserSubscriptionCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSubscription
        fields = [
            'user', 'pricing_plan', 'start_date', 'end_date', 'status', 
            'auto_renew', 'payment_gateway_subscription_id'
        ]


class AdminUserSubscriptionUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSubscription
        fields = [
            'pricing_plan', 'start_date', 'end_date', 'status', 'auto_renew', 
            'cancelled_at', 'payment_gateway_subscription_id', 'renewal_reminder_sent'
        ]


# Add admin referral program serializers
class AdminReferralProgramSerializer(serializers.ModelSerializer):
    usage_count = serializers.SerializerMethodField()
    
    class Meta:
        model = ReferralProgram
        fields = [
            'id', 'name', 'description', 'reward_type', 'reward_value',
            'referrer_reward_type', 'referrer_reward_value', 'is_active',
            'valid_from', 'valid_until', 'usage_limit', 'min_purchase_amount',
            'usage_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'usage_count']
    
    def get_usage_count(self, obj):
        return obj.userreferral_set.count()


class AdminReferralProgramCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferralProgram
        fields = [
            'name', 'description', 'reward_type', 'reward_value',
            'referrer_reward_type', 'referrer_reward_value', 'is_active',
            'valid_from', 'valid_until', 'usage_limit', 'min_purchase_amount'
        ]


class AdminReferralProgramUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferralProgram
        fields = [
            'name', 'description', 'reward_type', 'reward_value',
            'referrer_reward_type', 'referrer_reward_value', 'is_active',
            'valid_from', 'valid_until', 'usage_limit', 'min_purchase_amount'
        ]


class AdminUserReferralSerializer(serializers.ModelSerializer):
    referrer_email = serializers.CharField(source='referrer.email', read_only=True)
    referrer_username = serializers.CharField(source='referrer.username', read_only=True)
    referred_user_email = serializers.CharField(source='referred_user.email', read_only=True)
    referred_user_username = serializers.CharField(source='referred_user.username', read_only=True)
    program_name = serializers.CharField(source='referral_program.name', read_only=True)
    
    class Meta:
        model = UserReferral
        fields = [
            'id', 'referrer', 'referrer_email', 'referrer_username',
            'referred_user', 'referred_user_email', 'referred_user_username',
            'referral_program', 'program_name', 'referral_code_used',
            'status', 'reward_granted_to_referrer', 'reward_granted_to_referred',
            'date_referred', 'date_completed', 'conversion_subscription'
        ]
        read_only_fields = ['id', 'date_referred', 'referrer_email', 'referrer_username',
                           'referred_user_email', 'referred_user_username', 'program_name'] 