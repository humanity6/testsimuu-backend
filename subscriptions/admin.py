from django.contrib import admin
from django.utils.html import format_html
from .models import PricingPlan, UserSubscription, Payment, ReferralProgram, UserReferral
import json

@admin.register(PricingPlan)
class PricingPlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'exam', 'price', 'currency', 'billing_cycle', 'is_active', 'display_order')
    list_filter = ('is_active', 'billing_cycle', 'exam', 'currency')
    search_fields = ('name', 'description', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'slug', 'description', 'exam')
        }),
        ('Pricing Details', {
            'fields': ('price', 'currency', 'billing_cycle', 'trial_days')
        }),
        ('Features and Settings', {
            'fields': ('features_list', 'is_active', 'display_order', 'payment_gateway_plan_id')
        }),
    )
    actions = ['duplicate_plan', 'activate_plans', 'deactivate_plans']
    
    def duplicate_plan(self, request, queryset):
        for plan in queryset:
            plan.pk = None
            plan.name = f"Copy of {plan.name}"
            plan.slug = f"{plan.slug}-copy"
            plan.is_active = False
            plan.payment_gateway_plan_id = None
            plan.save()
    duplicate_plan.short_description = "Duplicate selected plans"
    
    def activate_plans(self, request, queryset):
        queryset.update(is_active=True)
    activate_plans.short_description = "Activate selected plans"
    
    def deactivate_plans(self, request, queryset):
        queryset.update(is_active=False)
    deactivate_plans.short_description = "Deactivate selected plans"


@admin.register(UserSubscription)
class UserSubscriptionAdmin(admin.ModelAdmin):
    list_display = ('user', 'pricing_plan', 'status', 'start_date', 'end_date', 'auto_renew', 'created_at')
    list_filter = ('status', 'auto_renew', 'pricing_plan__billing_cycle', 'pricing_plan__exam')
    search_fields = ('user__email', 'user__username', 'pricing_plan__name')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'start_date'
    fieldsets = (
        ('User Information', {
            'fields': ('user',)
        }),
        ('Subscription Details', {
            'fields': ('pricing_plan', 'status', 'start_date', 'end_date', 'auto_renew')
        }),
        ('Payment Information', {
            'fields': ('payment_gateway_subscription_id', 'cancelled_at', 'renewal_reminder_sent')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )
    actions = ['activate_subscriptions', 'cancel_subscriptions', 'extend_subscription_month']
    
    def activate_subscriptions(self, request, queryset):
        queryset.update(status='ACTIVE')
    activate_subscriptions.short_description = "Activate selected subscriptions"
    
    def cancel_subscriptions(self, request, queryset):
        from django.utils import timezone
        queryset.update(status='CANCELED', auto_renew=False, cancelled_at=timezone.now())
    cancel_subscriptions.short_description = "Cancel selected subscriptions"
    
    def extend_subscription_month(self, request, queryset):
        from django.utils import timezone
        import datetime
        for subscription in queryset:
            if subscription.end_date:
                subscription.end_date = subscription.end_date + datetime.timedelta(days=30)
                subscription.save()
    extend_subscription_month.short_description = "Extend subscriptions by 30 days"


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'amount', 'currency', 'status', 'transaction_time', 'payment_gateway_transaction_id')
    list_filter = ('status', 'currency', 'transaction_time')
    search_fields = ('user__email', 'user__username', 'payment_gateway_transaction_id', 'invoice_number')
    readonly_fields = ('payment_details_formatted', 'metadata_formatted')
    date_hierarchy = 'transaction_time'
    fieldsets = (
        ('User Information', {
            'fields': ('user', 'user_subscription')
        }),
        ('Payment Details', {
            'fields': ('amount', 'currency', 'status', 'transaction_time')
        }),
        ('Gateway Information', {
            'fields': ('payment_gateway_transaction_id', 'payment_details_formatted', 'metadata_formatted')
        }),
        ('Additional Information', {
            'fields': ('billing_address', 'invoice_number', 'refund_reference')
        }),
    )
    actions = ['mark_as_successful', 'mark_as_failed', 'sync_with_sumup']
    
    def payment_details_formatted(self, obj):
        if obj.payment_method_details:
            return format_html("<pre>{}</pre>", json.dumps(obj.payment_method_details, indent=2))
        return "-"
    payment_details_formatted.short_description = "Payment Method Details"
    
    def metadata_formatted(self, obj):
        if obj.metadata:
            return format_html("<pre>{}</pre>", json.dumps(obj.metadata, indent=2))
        return "-"
    metadata_formatted.short_description = "Metadata"
    
    def mark_as_successful(self, request, queryset):
        queryset.update(status='SUCCESSFUL')
        # Also update related subscriptions
        for payment in queryset:
            if payment.user_subscription:
                payment.user_subscription.status = 'ACTIVE'
                payment.user_subscription.save()
    mark_as_successful.short_description = "Mark selected payments as successful"
    
    def mark_as_failed(self, request, queryset):
        queryset.update(status='FAILED')
        # Also update related subscriptions
        for payment in queryset:
            if payment.user_subscription:
                payment.user_subscription.status = 'EXPIRED'
                payment.user_subscription.save()
    mark_as_failed.short_description = "Mark selected payments as failed"
    
    def sync_with_sumup(self, request, queryset):
        from .services import SumUpPaymentService
        service = SumUpPaymentService()
        success_count = 0
        for payment in queryset:
            try:
                result = service.verify_payment(payment.payment_gateway_transaction_id)
                if result.get('status') == 'success':
                    success_count += 1
            except Exception as e:
                self.message_user(request, f"Error syncing payment {payment.id}: {str(e)}")
        
        self.message_user(request, f"Successfully synced {success_count} out of {queryset.count()} payments")
    sync_with_sumup.short_description = "Sync selected payments with SumUp"


@admin.register(ReferralProgram)
class ReferralProgramAdmin(admin.ModelAdmin):
    list_display = ('name', 'reward_type', 'reward_value', 'referrer_reward_type', 'referrer_reward_value', 'is_active')
    list_filter = ('is_active', 'reward_type', 'referrer_reward_type')
    search_fields = ('name', 'description')


@admin.register(UserReferral)
class UserReferralAdmin(admin.ModelAdmin):
    list_display = ('referrer', 'referred_user', 'referral_program', 'status', 'date_referred', 'date_completed')
    list_filter = ('status', 'reward_granted_to_referrer', 'reward_granted_to_referred')
    search_fields = ('referrer__email', 'referred_user__email', 'referral_code_used')
    date_hierarchy = 'date_referred' 