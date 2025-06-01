from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Sum, Count

from .models import (
    Affiliate, 
    AffiliateLink, 
    VoucherCode, 
    Conversion, 
    AffiliatePayment,
    ClickEvent,
    AffiliatePlan,
    AffiliateApplication
)


@admin.register(Affiliate)
class AffiliateAdmin(admin.ModelAdmin):
    list_display = ('name', 'user_email', 'tracking_code', 'affiliate_plan', 'commission_model', 
                    'commission_rate', 'is_active', 'created_at', 'total_conversions', 
                    'total_earnings')
    list_filter = ('is_active', 'affiliate_plan', 'commission_model', 'created_at')
    search_fields = ('name', 'user__email', 'tracking_code')
    readonly_fields = ('tracking_code', 'created_at', 'updated_at')
    fieldsets = (
        (None, {
            'fields': ('user', 'name', 'email', 'tracking_code', 'is_active')
        }),
        ('Details', {
            'fields': ('website', 'description')
        }),
        ('Plan Settings', {
            'fields': ('affiliate_plan',)
        }),
        ('Legacy Commission Settings', {
            'fields': ('commission_model', 'commission_rate', 'fixed_fee'),
            'classes': ('collapse',)
        }),
        ('Payment Details', {
            'fields': ('payment_method', 'payment_details')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def user_email(self, obj):
        return obj.user.email
    user_email.short_description = 'User Email'
    
    def total_conversions(self, obj):
        return Conversion.objects.filter(affiliate=obj).count()
    total_conversions.short_description = 'Conversions'
    
    def total_earnings(self, obj):
        return obj.total_earnings()
    total_earnings.short_description = 'Total Earnings'


class ConversionInline(admin.TabularInline):
    model = Conversion
    fields = ('user', 'conversion_type', 'conversion_value', 'commission_amount', 
              'is_verified', 'is_paid', 'conversion_date')
    readonly_fields = ('conversion_date',)
    extra = 0


@admin.register(AffiliateLink)
class AffiliateLinkAdmin(admin.ModelAdmin):
    list_display = ('name', 'affiliate', 'link_type', 'target_url_display', 
                   'tracking_id', 'click_count', 'is_active', 'created_at')
    list_filter = ('link_type', 'is_active', 'created_at')
    search_fields = ('name', 'affiliate__name', 'tracking_id', 'target_url')
    readonly_fields = ('tracking_id', 'click_count', 'created_at', 'updated_at', 'full_url')
    fieldsets = (
        (None, {
            'fields': ('affiliate', 'name', 'link_type', 'is_active')
        }),
        ('URL Details', {
            'fields': ('target_url', 'full_url', 'tracking_id', 'utm_medium', 'utm_campaign')
        }),
        ('Content Association', {
            'fields': ('content_type', 'object_id')
        }),
        ('Tracking', {
            'fields': ('click_count', 'created_at', 'updated_at')
        }),
    )
    inlines = [ConversionInline]
    
    def target_url_display(self, obj):
        if len(obj.target_url) > 50:
            return f"{obj.target_url[:50]}..."
        return obj.target_url
    target_url_display.short_description = 'Target URL'
    
    def full_url(self, obj):
        return obj.full_url()
    full_url.short_description = 'Full Tracking URL'


@admin.register(VoucherCode)
class VoucherCodeAdmin(admin.ModelAdmin):
    list_display = ('code', 'affiliate', 'code_type', 'discount_value', 
                   'current_uses', 'max_uses', 'valid_from', 'valid_until', 
                   'is_active', 'is_valid_display')
    list_filter = ('code_type', 'is_active', 'valid_from', 'valid_until')
    search_fields = ('code', 'affiliate__name', 'description')
    readonly_fields = ('current_uses', 'created_at', 'updated_at')
    fieldsets = (
        (None, {
            'fields': ('affiliate', 'code', 'description', 'is_active')
        }),
        ('Discount Details', {
            'fields': ('code_type', 'discount_value')
        }),
        ('Validity', {
            'fields': ('valid_from', 'valid_until', 'max_uses', 'current_uses')
        }),
        ('Restrictions', {
            'fields': ('minimum_purchase', 'applicable_products')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    inlines = [ConversionInline]
    
    def is_valid_display(self, obj):
        is_valid = obj.is_valid()
        return format_html(
            '<span style="color: {};">{}</span>',
            'green' if is_valid else 'red',
            'Valid' if is_valid else 'Invalid'
        )
    is_valid_display.short_description = 'Is Valid'


@admin.register(Conversion)
class ConversionAdmin(admin.ModelAdmin):
    list_display = ('user_email', 'affiliate', 'conversion_type', 'conversion_value', 
                   'commission_amount', 'is_verified', 'is_paid', 'conversion_date')
    list_filter = ('conversion_type', 'is_verified', 'is_paid', 'conversion_date')
    search_fields = ('user__email', 'affiliate__name')
    readonly_fields = ('conversion_date', 'verification_date')
    fieldsets = (
        (None, {
            'fields': ('user', 'affiliate', 'conversion_type')
        }),
        ('Source', {
            'fields': ('affiliate_link', 'voucher_code')
        }),
        ('Conversion Details', {
            'fields': ('conversion_value', 'commission_amount', 'subscription', 'payment')
        }),
        ('Status', {
            'fields': ('is_verified', 'is_paid', 'conversion_date', 'verification_date')
        }),
        ('Tracking Info', {
            'fields': ('ip_address', 'user_agent', 'referrer_url'),
            'classes': ('collapse',)
        }),
    )
    
    def user_email(self, obj):
        return obj.user.email
    user_email.short_description = 'User Email'


class ConversionInlineForPayment(admin.TabularInline):
    model = AffiliatePayment.conversions.through
    extra = 0
    verbose_name = "Conversion"
    verbose_name_plural = "Conversions"


@admin.register(AffiliatePayment)
class AffiliatePaymentAdmin(admin.ModelAdmin):
    list_display = ('affiliate', 'amount', 'currency', 'payment_method', 
                   'status', 'period_start', 'period_end', 'created_at')
    list_filter = ('status', 'payment_method', 'currency', 'period_start', 'period_end')
    search_fields = ('affiliate__name', 'transaction_id')
    readonly_fields = ('created_at', 'updated_at')
    exclude = ('conversions',)
    fieldsets = (
        (None, {
            'fields': ('affiliate', 'amount', 'currency', 'status')
        }),
        ('Payment Details', {
            'fields': ('payment_method', 'transaction_id')
        }),
        ('Period', {
            'fields': ('period_start', 'period_end')
        }),
        ('SumUp Details', {
            'fields': ('sumup_checkout_id', 'sumup_transaction_code')
        }),
        ('Additional Info', {
            'fields': ('notes', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    inlines = [ConversionInlineForPayment]


@admin.register(ClickEvent)
class ClickEventAdmin(admin.ModelAdmin):
    list_display = ('affiliate', 'affiliate_link', 'user_display', 
                   'ip_address', 'timestamp')
    list_filter = ('timestamp',)
    search_fields = ('affiliate__name', 'affiliate_link__name', 'user__email', 'ip_address')
    readonly_fields = ('timestamp',)
    fieldsets = (
        (None, {
            'fields': ('affiliate', 'affiliate_link', 'user', 'session_id')
        }),
        ('Request Details', {
            'fields': ('ip_address', 'user_agent', 'referrer_url', 'timestamp')
        }),
    )
    
    def user_display(self, obj):
        if obj.user:
            return obj.user.email
        return '-'
    user_display.short_description = 'User'


@admin.register(AffiliatePlan)
class AffiliatePlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'plan_type', 'commission_summary_display', 'minimum_followers', 
                   'is_active', 'is_auto_approval', 'created_at')
    list_filter = ('plan_type', 'is_active', 'is_auto_approval', 'created_at')
    search_fields = ('name', 'description')
    fieldsets = (
        (None, {
            'fields': ('name', 'description', 'plan_type', 'is_active', 'is_auto_approval')
        }),
        ('Commission Settings', {
            'fields': ('commission_per_download', 'commission_per_subscription', 
                      'commission_percentage', 'fixed_monthly_payment')
        }),
        ('Requirements', {
            'fields': ('minimum_followers', 'minimum_monthly_conversions')
        }),
        ('Advanced', {
            'fields': ('tier_settings',),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    readonly_fields = ('created_at', 'updated_at')
    
    def commission_summary_display(self, obj):
        return obj.get_commission_summary()
    commission_summary_display.short_description = 'Commission Structure'


class AffiliateApplicationInline(admin.TabularInline):
    model = AffiliateApplication
    fields = ('user', 'status', 'follower_count', 'created_at')
    readonly_fields = ('created_at',)
    extra = 0


@admin.register(AffiliateApplication)
class AffiliateApplicationAdmin(admin.ModelAdmin):
    list_display = ('user_email', 'requested_plan', 'status', 'follower_count', 
                   'created_at', 'reviewed_by', 'reviewed_at')
    list_filter = ('status', 'requested_plan', 'created_at', 'reviewed_at')
    search_fields = ('user__email', 'business_name', 'website_url')
    readonly_fields = ('created_at', 'updated_at')
    actions = ['approve_applications', 'reject_applications']
    fieldsets = (
        (None, {
            'fields': ('user', 'requested_plan', 'status')
        }),
        ('Business Details', {
            'fields': ('business_name', 'website_url', 'social_media_links', 'follower_count')
        }),
        ('Application Info', {
            'fields': ('audience_description', 'promotion_strategy')
        }),
        ('Review', {
            'fields': ('admin_notes', 'reviewed_by', 'reviewed_at')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def user_email(self, obj):
        return obj.user.email
    user_email.short_description = 'User Email'
    
    def approve_applications(self, request, queryset):
        """Bulk approve applications."""
        from django.utils import timezone
        from .services import AffiliateService
        
        for application in queryset.filter(status='PENDING'):
            # Create affiliate profile if approved
            if not hasattr(application.user, 'affiliate_profile'):
                service = AffiliateService()
                service.create_affiliate_from_application(application, request.user)
            
            application.status = 'APPROVED'
            application.reviewed_by = request.user
            application.reviewed_at = timezone.now()
            application.save()
        
        self.message_user(request, f"Approved {queryset.count()} applications.")
    
    approve_applications.short_description = "Approve selected applications"
    
    def reject_applications(self, request, queryset):
        """Bulk reject applications."""
        from django.utils import timezone
        
        queryset.update(
            status='REJECTED',
            reviewed_by=request.user,
            reviewed_at=timezone.now()
        )
        self.message_user(request, f"Rejected {queryset.count()} applications.")
    
    reject_applications.short_description = "Reject selected applications" 