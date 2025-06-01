import requests
import json
import logging
import uuid
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from .models import Payment, UserSubscription, PricingPlan
from users.models import User

logger = logging.getLogger(__name__)

class SumUpPaymentService:
    """Service class for interacting with SumUp payment gateway."""
    
    def __init__(self):
        self.api_key = getattr(settings, 'SUMUP_API_KEY', '')
        self.base_url = getattr(settings, 'SUMUP_API_BASE_URL', 'https://api.sumup.com/v0.1')
        self.merchant_code = getattr(settings, 'SUMUP_MERCHANT_CODE', '')
        self.merchant_email = getattr(settings, 'SUMUP_MERCHANT_EMAIL', '')
        self.webhook_url = getattr(settings, 'SUMUP_WEBHOOK_URL', '')
        
        if not self.api_key:
            logger.error("SumUp API key not configured")
            
    def _get_headers(self):
        """Get HTTP headers for SumUp API requests."""
        return {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def _get_merchant_profile(self):
        """Get merchant profile from SumUp."""
        try:
            response = requests.get(
                f"{self.base_url}/me",
                headers=self._get_headers()
            )
            response.raise_for_status()
            
            profile_data = response.json()
            merchant_profile = profile_data.get('merchant_profile', {})
            
            return {
                'merchant_code': merchant_profile.get('merchant_code', ''),
                'country': merchant_profile.get('country', ''),
                'default_currency': merchant_profile.get('default_currency', 'EUR'),
                'company_name': merchant_profile.get('company_name', ''),
                'email': profile_data.get('account', {}).get('username', '')
            }
        except Exception as e:
            logger.error(f"Failed to get merchant profile: {str(e)}")
            return {}
    
    def get_available_payment_methods(self):
        """Get available payment methods for the merchant."""
        try:
            if not self.merchant_code:
                merchant_profile = self._get_merchant_profile()
                merchant_code = merchant_profile.get('merchant_code', '')
            else:
                merchant_code = self.merchant_code
                
            if not merchant_code:
                logger.error("No merchant code available")
                return []
            
            response = requests.get(
                f"{self.base_url}/merchants/{merchant_code}/payment-methods",
                headers=self._get_headers()
            )
            response.raise_for_status()
            
            data = response.json()
            return data.get('available_payment_methods', [])
            
        except Exception as e:
            logger.error(f"Failed to get payment methods: {str(e)}")
            return []
    
    def create_checkout(self, amount, currency='EUR', description=None, user_id=None):
        """
        Create a SumUp checkout session.
        
        Args:
            amount (float): Payment amount
            currency (str): Currency code (default: EUR)
            description (str): Payment description
            user_id (int): User ID for tracking
            
        Returns:
            dict: SumUp checkout response or error details
        """
        try:
            # Generate unique checkout reference
            checkout_reference = str(uuid.uuid4())
            
            # Get merchant code if not configured
            merchant_code = self.merchant_code
            if not merchant_code:
                merchant_profile = self._get_merchant_profile()
                merchant_code = merchant_profile.get('merchant_code', '')
                
            if not merchant_code:
                return {
                    'success': False,
                    'error': 'Merchant code not available',
                    'error_code': 'CONFIGURATION_ERROR'
                }
            
            # Build payload with required fields only
            payload = {
                'checkout_reference': checkout_reference,
                'amount': float(amount),
                'currency': currency,
                'merchant_code': merchant_code
            }
            
            # Add optional fields if provided
            if description:
                payload['description'] = description
                
            logger.info(f"Creating SumUp checkout with payload: {json.dumps(payload, indent=2)}")
            
            response = requests.post(
                f"{self.base_url}/checkouts",
                json=payload,
                headers=self._get_headers()
            )
            
            logger.info(f"SumUp checkout response status: {response.status_code}")
            logger.info(f"SumUp checkout response body: {response.text}")
            
            if response.status_code in [200, 201]:
                result = response.json()
                return {
                    'success': True,
                    'checkout_id': result.get('id'),
                    'checkout_reference': checkout_reference,
                    'amount': amount,
                    'currency': currency,
                    'status': result.get('status', 'PENDING'),
                    'checkout_url': f"https://checkout.sumup.com/{result.get('id')}",
                    'data': result
                }
            else:
                # Handle API errors
                try:
                    error_data = response.json()
                    error_code = error_data.get('error_code', 'UNKNOWN_ERROR')
                    error_message = error_data.get('message', 'Unknown error')
                except:
                    error_code = f"HTTP_{response.status_code}"
                    error_message = response.text or 'Unknown error'
                
                logger.error(f"SumUp checkout creation failed: {error_code} - {error_message}")
                
                return {
                    'success': False,
                    'error': error_message,
                    'error_code': error_code,
                    'status_code': response.status_code
                }
                
        except requests.RequestException as e:
            logger.error(f"SumUp API request failed: {str(e)}")
            return {
                'success': False,
                'error': f'API request failed: {str(e)}',
                'error_code': 'REQUEST_ERROR'
            }
        except Exception as e:
            logger.error(f"Unexpected error in create_checkout: {str(e)}")
            return {
                'success': False,
                'error': f'Unexpected error: {str(e)}',
                'error_code': 'INTERNAL_ERROR'
            }
    
    def get_checkout_status(self, checkout_id):
        """
        Get the status of a SumUp checkout.
        
        Args:
            checkout_id (str): SumUp checkout ID
            
        Returns:
            dict: Checkout status information
        """
        try:
            response = requests.get(
                f"{self.base_url}/checkouts/{checkout_id}",
                headers=self._get_headers()
            )
            response.raise_for_status()
            
            data = response.json()
            return {
                'success': True,
                'status': data.get('status'),
                'amount': data.get('amount'),
                'currency': data.get('currency'),
                'transactions': data.get('transactions', []),
                'data': data
            }
            
        except Exception as e:
            logger.error(f"Failed to get checkout status: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'error_code': 'STATUS_CHECK_ERROR'
            }
    
    def process_payment(self, user, plan, custom_amount=None):
        """
        Process a payment for a subscription plan using SumUp.
        
        Args:
            user: User instance
            plan: PricingPlan instance
            custom_amount: Optional custom amount (for flexible plans)
            
        Returns:
            dict: Payment processing result
        """
        try:
            amount = custom_amount if custom_amount else plan.price
            currency = plan.currency
            description = f"Subscription: {plan.name}"
            
            # Create SumUp checkout
            checkout_result = self.create_checkout(
                amount=amount,
                currency=currency,
                description=description,
                user_id=user.id
            )
            
            if not checkout_result.get('success'):
                return {
                    'success': False,
                    'error': checkout_result.get('error', 'Checkout creation failed'),
                    'error_code': checkout_result.get('error_code', 'CHECKOUT_ERROR')
                }
            
            # Create Payment record
            payment = Payment.objects.create(
                user=user,
                amount=amount,
                currency=currency,
                payment_method='sumup',
                status='pending',
                gateway_payment_id=checkout_result['checkout_id'],
                gateway_reference=checkout_result['checkout_reference'],
                gateway_response=checkout_result.get('data', {})
            )
            
            # Create UserSubscription record
            start_date = timezone.now()
            end_date = start_date + timedelta(days=plan.duration_days)
            
            subscription = UserSubscription.objects.create(
                user=user,
                plan=plan,
                payment=payment,
                start_date=start_date,
                end_date=end_date,
                status='pending'
            )
            
            logger.info(f"Created payment {payment.id} and subscription {subscription.id} for user {user.id}")
            
            return {
                'success': True,
                'payment_id': payment.id,
                'subscription_id': subscription.id,
                'checkout_url': checkout_result['checkout_url'],
                'checkout_id': checkout_result['checkout_id'],
                'amount': amount,
                'currency': currency
            }
            
        except Exception as e:
            logger.error(f"Payment processing failed: {str(e)}")
            return {
                'success': False,
                'error': f'Payment processing failed: {str(e)}',
                'error_code': 'PROCESSING_ERROR'
            }
    
    def handle_webhook(self, webhook_data):
        """
        Handle SumUp webhook notifications.
        
        Args:
            webhook_data (dict): Webhook payload from SumUp
            
        Returns:
            dict: Processing result
        """
        try:
            checkout_id = webhook_data.get('checkout_id')
            status = webhook_data.get('status')
            
            if not checkout_id:
                logger.error("Webhook missing checkout_id")
                return {'success': False, 'error': 'Missing checkout_id'}
            
            # Find the payment by gateway_payment_id
            try:
                payment = Payment.objects.get(gateway_payment_id=checkout_id)
            except Payment.DoesNotExist:
                logger.error(f"Payment not found for checkout_id: {checkout_id}")
                return {'success': False, 'error': 'Payment not found'}
            
            # Update payment status based on webhook
            if status == 'PAID':
                payment.status = 'completed'
                payment.paid_at = timezone.now()
                
                # Update associated subscription
                try:
                    subscription = UserSubscription.objects.get(payment=payment)
                    subscription.status = 'active'
                    subscription.save()
                    logger.info(f"Activated subscription {subscription.id}")
                except UserSubscription.DoesNotExist:
                    logger.warning(f"No subscription found for payment {payment.id}")
                    
            elif status == 'FAILED':
                payment.status = 'failed'
                
                # Update associated subscription
                try:
                    subscription = UserSubscription.objects.get(payment=payment)
                    subscription.status = 'cancelled'
                    subscription.save()
                    logger.info(f"Cancelled subscription {subscription.id}")
                except UserSubscription.DoesNotExist:
                    logger.warning(f"No subscription found for payment {payment.id}")
            
            payment.gateway_response = webhook_data
            payment.save()
            
            logger.info(f"Updated payment {payment.id} status to {payment.status}")
            
            return {'success': True, 'payment_id': payment.id}
            
        except Exception as e:
            logger.error(f"Webhook processing failed: {str(e)}")
            return {'success': False, 'error': str(e)}

class SubscriptionManagementService:
    """Service for managing subscription lifecycle and synchronization with payment gateway."""
    
    def __init__(self):
        self.payment_service = SumUpPaymentService()
    
    def create_pricing_plan(self, name, exam, price, currency, billing_cycle, 
                           description=None, features_list=None, trial_days=0,
                           is_active=True, display_order=0):
        """Create a new pricing plan."""
        
        if features_list is None:
            features_list = []
            
        # Generate slug from name
        from django.utils.text import slugify
        slug = slugify(name)
        
        # Check if slug exists, append a number if needed
        base_slug = slug
        counter = 1
        while PricingPlan.objects.filter(slug=slug).exists():
            slug = f"{base_slug}-{counter}"
            counter += 1
        
        plan = PricingPlan.objects.create(
            name=name,
            slug=slug,
            exam=exam,
            price=price,
            currency=currency,
            billing_cycle=billing_cycle,
            description=description,
            features_list=features_list,
            trial_days=trial_days,
            is_active=is_active,
            display_order=display_order
        )
        
        return plan
    
    def update_pricing_plan(self, plan_id, **kwargs):
        """Update an existing pricing plan."""
        try:
            plan = PricingPlan.objects.get(id=plan_id)
            
            # Update fields
            for key, value in kwargs.items():
                if hasattr(plan, key):
                    setattr(plan, key, value)
            
            # If name is updated, also update slug if not explicitly provided
            if 'name' in kwargs and 'slug' not in kwargs:
                from django.utils.text import slugify
                base_slug = slugify(plan.name)
                slug = base_slug
                counter = 1
                
                # Check if slug exists, append a number if needed
                while PricingPlan.objects.filter(slug=slug).exclude(id=plan.id).exists():
                    slug = f"{base_slug}-{counter}"
                    counter += 1
                
                plan.slug = slug
            
            plan.save()
            return plan
        
        except PricingPlan.DoesNotExist:
            logger.error(f"Pricing plan with ID {plan_id} not found")
            return None
    
    def delete_pricing_plan(self, plan_id):
        """Delete a pricing plan if it has no active subscriptions."""
        try:
            plan = PricingPlan.objects.get(id=plan_id)
            
            # Check if plan has active subscriptions
            if UserSubscription.objects.filter(pricing_plan=plan, status='ACTIVE').exists():
                logger.warning(f"Cannot delete plan {plan_id} with active subscriptions")
                return False, "Cannot delete plan with active subscriptions"
            
            # Delete the plan
            plan.delete()
            return True, "Plan deleted successfully"
            
        except PricingPlan.DoesNotExist:
            logger.error(f"Pricing plan with ID {plan_id} not found")
            return False, "Plan not found"
    
    def create_user_subscription(self, user, pricing_plan, status='PENDING_PAYMENT', auto_renew=True):
        """Create a new user subscription."""
        
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
            # For one-time plans, set a far future date
            end_date = start_date + timedelta(days=3650)  # ~10 years
        else:
            # Default fallback
            end_date = start_date + timedelta(days=30)
        
        # Create the subscription
        subscription = UserSubscription.objects.create(
            user=user,
            pricing_plan=pricing_plan,
            start_date=start_date,
            end_date=end_date,
            status=status,
            auto_renew=auto_renew
        )
        
        return subscription
    
    def create_payment_checkout(self, user, subscription, return_url=None):
        """Create a payment checkout for a subscription."""
        return self.payment_service.create_checkout(
            amount=subscription.pricing_plan.price,
            currency=subscription.pricing_plan.currency,
            description=f"Subscription: {subscription.pricing_plan.name}",
            user_id=user.id
        )
    
    def create_bundle_checkout(self, user, pricing_plan_ids, return_url=None):
        """Create a bundle checkout for multiple pricing plans."""
        # Create subscriptions for each plan
        subscriptions = []
        for plan_id in pricing_plan_ids:
            try:
                plan = PricingPlan.objects.get(id=plan_id, is_active=True)
                subscription = self.create_user_subscription(user, plan)
                subscriptions.append(subscription)
            except PricingPlan.DoesNotExist:
                # Cleanup created subscriptions on error
                for sub in subscriptions:
                    sub.delete()
                logger.error(f"Pricing plan {plan_id} not found or not active")
                raise ValueError(f"Pricing plan {plan_id} not found or not active")
        
        # Create bundle checkout
        return self.payment_service.create_bundle_checkout(
            user=user,
            subscriptions=subscriptions,
            return_url=return_url
        )
    
    def cancel_subscription(self, subscription_id, user=None):
        """Cancel a user subscription."""
        try:
            # If user is provided, make sure the subscription belongs to this user
            if user:
                subscription = UserSubscription.objects.get(id=subscription_id, user=user)
            else:
                subscription = UserSubscription.objects.get(id=subscription_id)
            
            # Update subscription status
            subscription.status = 'CANCELED'
            subscription.cancelled_at = timezone.now()
            subscription.auto_renew = False
            subscription.save()
            
            return True, subscription
            
        except UserSubscription.DoesNotExist:
            logger.error(f"Subscription {subscription_id} not found")
            return False, None
    
    def extend_subscription(self, subscription_id, days=30):
        """Extend a subscription by a number of days."""
        try:
            subscription = UserSubscription.objects.get(id=subscription_id)
            
            if subscription.end_date:
                subscription.end_date = subscription.end_date + timedelta(days=days)
                subscription.save()
                return True, subscription
            
            return False, "Subscription has no end date"
            
        except UserSubscription.DoesNotExist:
            logger.error(f"Subscription {subscription_id} not found")
            return False, "Subscription not found"
    
    def sync_subscription_status(self, subscription_id):
        """Sync subscription status with payment gateway."""
        try:
            subscription = UserSubscription.objects.get(id=subscription_id)
            
            # Find the most recent payment for this subscription
            payment = Payment.objects.filter(
                user_subscription=subscription
            ).order_by('-transaction_time').first()
            
            if not payment:
                logger.warning(f"No payment found for subscription {subscription_id}")
                return False, "No payment found for subscription"
            
            # Verify payment status with SumUp
            result = self.payment_service.verify_payment(payment.payment_gateway_transaction_id)
            
            if result.get('status') == 'error':
                logger.error(f"Error verifying payment: {result.get('message')}")
                return False, result.get('message')
            
            # Update subscription based on payment status
            payment_status = result.get('payment_status')
            
            if payment_status == 'SUCCESSFUL':
                subscription.status = 'ACTIVE'
                subscription.save()
                return True, "Subscription activated"
                
            elif payment_status == 'FAILED':
                subscription.status = 'EXPIRED'
                subscription.save()
                return True, "Subscription expired due to payment failure"
                
            return True, f"Payment status: {payment_status}"
            
        except UserSubscription.DoesNotExist:
            logger.error(f"Subscription {subscription_id} not found")
            return False, "Subscription not found"
    
    def check_expiring_subscriptions(self, days_before=7):
        """Check for subscriptions expiring in the next X days."""
        now = timezone.now()
        expiry_threshold = now + timedelta(days=days_before)
        
        # Find active subscriptions expiring within the threshold
        expiring_subscriptions = UserSubscription.objects.filter(
            status='ACTIVE',
            end_date__lte=expiry_threshold,
            end_date__gt=now,
            renewal_reminder_sent=False,
            auto_renew=False  # Only check non-auto-renewing subscriptions
        )
        
        return expiring_subscriptions
    
    def process_expired_subscriptions(self):
        """Process subscriptions that have expired."""
        now = timezone.now()
        
        # Find active subscriptions that have expired
        expired_subscriptions = UserSubscription.objects.filter(
            status='ACTIVE',
            end_date__lt=now
        )
        
        for subscription in expired_subscriptions:
            # If auto_renew is True, attempt to renew
            if subscription.auto_renew:
                # Implementation would depend on how renewals are handled
                # This might involve creating a new payment checkout
                logger.info(f"Auto-renewal needed for subscription {subscription.id}")
                # TODO: Implement auto-renewal logic
            else:
                # Mark as expired
                subscription.status = 'EXPIRED'
                subscription.save()
                logger.info(f"Subscription {subscription.id} marked as expired")
        
        return expired_subscriptions.count() 