from rest_framework import serializers
from .models import Affiliate, AffiliateLink, VoucherCode, Conversion, AffiliatePayment, ClickEvent, AffiliatePlan, AffiliateApplication


class AffiliateLinkSerializer(serializers.ModelSerializer):
    full_url = serializers.CharField(read_only=True)
    click_count = serializers.IntegerField(read_only=True)
    conversion_rate = serializers.SerializerMethodField()
    
    class Meta:
        model = AffiliateLink
        fields = ['id', 'name', 'link_type', 'target_url', 'tracking_id', 
                  'utm_medium', 'utm_campaign', 'click_count', 'full_url', 
                  'conversion_rate', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'tracking_id', 'click_count', 'full_url', 
                          'conversion_rate', 'created_at', 'updated_at']
    
    def get_conversion_rate(self, obj):
        return obj.conversion_rate()
    
    def create(self, validated_data):
        # Get the affiliate from the user
        user = self.context['request'].user
        try:
            affiliate = user.affiliate_profile
        except Affiliate.DoesNotExist:
            raise serializers.ValidationError("User doesn't have an affiliate profile")
            
        # Add the affiliate to the validated data
        validated_data['affiliate'] = affiliate
        
        return super().create(validated_data)


class VoucherCodeSerializer(serializers.ModelSerializer):
    is_valid = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = VoucherCode
        fields = ['id', 'code', 'description', 'code_type', 'discount_value',
                  'valid_from', 'valid_until', 'max_uses', 'current_uses',
                  'minimum_purchase', 'applicable_products', 'is_active',
                  'is_valid', 'created_at', 'updated_at']
        read_only_fields = ['id', 'code', 'created_at', 'updated_at', 
                           'current_uses', 'is_valid']


class ConversionSerializer(serializers.ModelSerializer):
    affiliate_link_name = serializers.SerializerMethodField()
    voucher_code_name = serializers.SerializerMethodField()
    user_email = serializers.SerializerMethodField()
    
    class Meta:
        model = Conversion
        fields = ['id', 'conversion_type', 'conversion_value', 'commission_amount',
                  'affiliate_link_name', 'voucher_code_name', 'user_email',
                  'is_verified', 'is_paid', 'conversion_date', 'verification_date']
    
    def get_affiliate_link_name(self, obj):
        return obj.affiliate_link.name if obj.affiliate_link else None
    
    def get_voucher_code_name(self, obj):
        return obj.voucher_code.code if obj.voucher_code else None
    
    def get_user_email(self, obj):
        return obj.user.email


class AffiliatePaymentSerializer(serializers.ModelSerializer):
    conversions_count = serializers.SerializerMethodField()
    
    class Meta:
        model = AffiliatePayment
        fields = ['id', 'amount', 'currency', 'payment_method', 'status',
                  'period_start', 'period_end', 'conversions_count',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_conversions_count(self, obj):
        return obj.conversions.count()


class AffiliateSerializer(serializers.ModelSerializer):
    total_earnings = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    pending_earnings = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    
    class Meta:
        model = Affiliate
        fields = ['id', 'name', 'email', 'website', 'description', 
                  'commission_model', 'commission_rate', 'fixed_fee',
                  'tracking_code', 'is_active', 'created_at', 'updated_at',
                  'total_earnings', 'pending_earnings']
        read_only_fields = ['id', 'tracking_code', 'created_at', 'updated_at', 
                            'total_earnings', 'pending_earnings']


class ClickTrackingSerializer(serializers.Serializer):
    tracking_id = serializers.CharField(required=True)
    referrer_url = serializers.URLField(required=False, allow_blank=True)


class VoucherApplySerializer(serializers.Serializer):
    code = serializers.CharField(required=True)


class AffiliatePlanSerializer(serializers.ModelSerializer):
    commission_summary = serializers.CharField(source='get_commission_summary', read_only=True)
    
    class Meta:
        model = AffiliatePlan
        fields = ['id', 'name', 'description', 'plan_type', 
                  'commission_per_download', 'commission_per_subscription', 
                  'commission_percentage', 'fixed_monthly_payment',
                  'minimum_followers', 'minimum_monthly_conversions',
                  'commission_summary', 'is_active', 'is_auto_approval',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'commission_summary', 'created_at', 'updated_at']


class AffiliateApplicationSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)
    plan_name = serializers.CharField(source='requested_plan.name', read_only=True)
    
    class Meta:
        model = AffiliateApplication
        fields = ['id', 'user_email', 'requested_plan', 'plan_name',
                  'business_name', 'website_url', 'social_media_links',
                  'audience_description', 'promotion_strategy', 'follower_count',
                  'status', 'admin_notes', 'created_at', 'updated_at']
        read_only_fields = ['id', 'user_email', 'plan_name', 'status', 
                           'admin_notes', 'created_at', 'updated_at']
    
    def create(self, validated_data):
        # Set the user to the requesting user
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class AffiliateApplicationCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating affiliate applications."""
    
    class Meta:
        model = AffiliateApplication
        fields = ['requested_plan', 'business_name', 'website_url', 
                  'social_media_links', 'audience_description', 
                  'promotion_strategy', 'follower_count']
    
    def create(self, validated_data):
        # Set the user to the requesting user
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class PublicAffiliatePlanSerializer(serializers.ModelSerializer):
    """Public serializer for affiliate plans (visible to non-affiliates)."""
    commission_summary = serializers.CharField(source='get_commission_summary', read_only=True)
    
    class Meta:
        model = AffiliatePlan
        fields = ['id', 'name', 'description', 'plan_type', 
                  'commission_summary', 'minimum_followers', 'minimum_monthly_conversions'] 