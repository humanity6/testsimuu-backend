import uuid
import string
import random
import logging
from decimal import Decimal
from datetime import datetime, timedelta
from django.utils import timezone
from django.conf import settings
from django.db.models import Sum, Count
from django.contrib.contenttypes.models import ContentType

from .models import (
    Affiliate, 
    AffiliateLink, 
    VoucherCode, 
    Conversion, 
    AffiliatePayment,
    ClickEvent
)
from subscriptions.services import SumUpPaymentService
from subscriptions.models import Payment, UserSubscription

logger = logging.getLogger(__name__)

class AffiliateTrackingService:
    """Service for tracking affiliate-related activities."""
    
    @staticmethod
    def generate_tracking_code(length=8):
        """Generate a unique tracking code for an affiliate."""
        characters = string.ascii_uppercase + string.digits
        while True:
            code = ''.join(random.choices(characters, k=length))
            if not Affiliate.objects.filter(tracking_code=code).exists():
                return code
    
    @staticmethod
    def generate_voucher_code(length=10, prefix=None):
        """Generate a unique voucher code."""
        characters = string.ascii_uppercase + string.digits
        
        while True:
            if prefix:
                code = f"{prefix}-{''.join(random.choices(characters, k=length))}"
            else:
                code = ''.join(random.choices(characters, k=length))
                
            if not VoucherCode.objects.filter(code=code).exists():
                return code
    
    @staticmethod
    def generate_tracking_id():
        """Generate a unique tracking ID for affiliate links."""
        return str(uuid.uuid4())[:8]
    
    def create_affiliate_link(self, affiliate, target_url, name=None, link_type='GENERAL', 
                             linked_object=None, utm_campaign=None):
        """Create a new affiliate tracking link."""
        if not name:
            name = f"Link-{timezone.now().strftime('%Y%m%d-%H%M%S')}"
            
        # Generate tracking ID
        tracking_id = self.generate_tracking_id()
        
        # Set content type and object ID if linked object is provided
        content_type = None
        object_id = None
        
        if linked_object:
            content_type = ContentType.objects.get_for_model(linked_object)
            object_id = linked_object.id
            
        # Create the link
        link = AffiliateLink.objects.create(
            affiliate=affiliate,
            name=name,
            link_type=link_type,
            target_url=target_url,
            tracking_id=tracking_id,
            content_type=content_type,
            object_id=object_id,
            utm_campaign=utm_campaign
        )
        
        return link
    
    def create_voucher_code(self, affiliate, code_type, discount_value, description=None,
                          max_uses=0, valid_days=90, prefix=None, minimum_purchase=0.00,
                          applicable_products=None):
        """Create a new voucher code for an affiliate."""
        # Generate code if not provided
        code = self.generate_voucher_code(prefix=prefix or affiliate.tracking_code[:4])
        
        if not description:
            if code_type == 'PERCENTAGE':
                description = f"{discount_value}% discount"
            elif code_type == 'FIXED':
                description = f"€{discount_value} off"
            else:
                description = f"Extended trial"
        
        # Set validity period
        valid_from = timezone.now()
        valid_until = valid_from + timedelta(days=valid_days) if valid_days else None
        
        # Create voucher
        voucher = VoucherCode.objects.create(
            affiliate=affiliate,
            code=code,
            description=description,
            code_type=code_type,
            discount_value=discount_value,
            valid_from=valid_from,
            valid_until=valid_until,
            max_uses=max_uses,
            minimum_purchase=minimum_purchase,
            applicable_products=applicable_products
        )
        
        return voucher
    
    def track_click(self, affiliate_link, request=None, user=None, session_id=None):
        """Track a click on an affiliate link."""
        # Update click count
        affiliate_link.click_count += 1
        affiliate_link.save()
        
        # Record click event if request is provided
        if request:
            ip_address = self.get_client_ip(request)
            user_agent = request.META.get('HTTP_USER_AGENT', '')
            referrer = request.META.get('HTTP_REFERER', '')
            
            # Get session ID if not provided
            if not session_id and request.session.session_key:
                session_id = request.session.session_key
            
            # Get user if not provided but authenticated
            if not user and request.user.is_authenticated:
                user = request.user
        else:
            ip_address = None
            user_agent = None
            referrer = None
        
        # Create click event
        click = ClickEvent.objects.create(
            affiliate=affiliate_link.affiliate,
            affiliate_link=affiliate_link,
            user=user,
            session_id=session_id,
            ip_address=ip_address,
            user_agent=user_agent,
            referrer_url=referrer
        )
        
        return click
    
    def record_conversion(self, affiliate, user, conversion_type, conversion_value=0.00,
                        affiliate_link=None, voucher_code=None, subscription=None, 
                        payment=None, request=None):
        """Record a conversion from an affiliate."""
        # Calculate commission amount
        commission_amount = self.calculate_commission(
            affiliate=affiliate,
            conversion_type=conversion_type,
            conversion_value=conversion_value
        )
        
        # Get tracking info from request if available
        ip_address = None
        user_agent = None
        referrer = None
        
        if request:
            ip_address = self.get_client_ip(request)
            user_agent = request.META.get('HTTP_USER_AGENT', '')
            referrer = request.META.get('HTTP_REFERER', '')
        
        # Create conversion record
        conversion = Conversion.objects.create(
            affiliate=affiliate,
            user=user,
            affiliate_link=affiliate_link,
            voucher_code=voucher_code,
            conversion_type=conversion_type,
            conversion_value=conversion_value,
            commission_amount=commission_amount,
            subscription=subscription,
            payment=payment,
            ip_address=ip_address,
            user_agent=user_agent,
            referrer_url=referrer,
            is_verified=False
        )
        
        # Update voucher code usage if used
        if voucher_code:
            voucher_code.current_uses += 1
            voucher_code.save()
        
        return conversion
    
    def verify_conversion(self, conversion_id):
        """Verify a conversion as legitimate."""
        try:
            conversion = Conversion.objects.get(id=conversion_id)
            conversion.is_verified = True
            conversion.verification_date = timezone.now()
            conversion.save()
            return True
            
        except Conversion.DoesNotExist:
            logger.error(f"Conversion ID {conversion_id} not found for verification")
            return False
    
    def calculate_commission(self, affiliate, conversion_type, conversion_value):
        """Calculate commission for a conversion based on affiliate's commission model."""
        # Pure affiliate model - percentage of the conversion value
        if affiliate.commission_model == 'PURE_AFFILIATE':
            commission_rate = affiliate.commission_rate / Decimal('100.0')
            return Decimal(conversion_value) * commission_rate
            
        # Fixed + performance model - fixed fee + percentage for SUBSCRIPTION conversions
        elif affiliate.commission_model == 'FIXED_PERFORMANCE':
            # For subscription conversions, calculate percentage
            if conversion_type == 'SUBSCRIPTION':
                commission_rate = affiliate.commission_rate / Decimal('100.0')
                return Decimal(conversion_value) * commission_rate
            # For other conversion types, use a fixed amount
            else:
                return affiliate.commission_rate
    
    def get_client_ip(self, request):
        """Extract client IP address from request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip


class AffiliateAnalyticsService:
    """Service for generating affiliate analytics and reports."""
    
    def get_affiliate_dashboard_data(self, affiliate, period_days=30):
        """Get dashboard data for an affiliate."""
        end_date = timezone.now()
        start_date = end_date - timedelta(days=period_days)
        
        # Get conversions in the period
        conversions = Conversion.objects.filter(
            affiliate=affiliate,
            conversion_date__gte=start_date,
            conversion_date__lte=end_date
        )
        
        # Get clicks in the period
        clicks = ClickEvent.objects.filter(
            affiliate=affiliate,
            timestamp__gte=start_date,
            timestamp__lte=end_date
        )
        
        # Calculate statistics
        total_clicks = clicks.count()
        total_conversions = conversions.count()
        conversion_rate = (total_conversions / total_clicks * 100) if total_clicks > 0 else 0
        
        # Calculate earnings
        verified_conversions = conversions.filter(is_verified=True)
        total_earnings = verified_conversions.aggregate(total=Sum('commission_amount'))['total'] or 0
        
        # Conversion breakdown by type
        conversion_breakdown = conversions.values('conversion_type').annotate(
            count=Count('id'),
            value=Sum('conversion_value'),
            commission=Sum('commission_amount')
        )
        
        # Link performance
        link_performance = AffiliateLink.objects.filter(
            affiliate=affiliate,
            click_events__timestamp__gte=start_date,
            click_events__timestamp__lte=end_date
        ).annotate(
            clicks=Count('click_events'),
            conversion_count=Count('conversions'),
        ).values('id', 'name', 'clicks', 'conversion_count')
        
        # Add conversion rate to link performance
        for link in link_performance:
            link['conversion_rate'] = (link['conversion_count'] / link['clicks'] * 100) if link['clicks'] > 0 else 0
        
        # Voucher code performance
        voucher_performance = VoucherCode.objects.filter(
            affiliate=affiliate,
            conversions__conversion_date__gte=start_date,
            conversions__conversion_date__lte=end_date
        ).annotate(
            uses=Count('conversions'),
            value=Sum('conversions__conversion_value'),
            commission=Sum('conversions__commission_amount')
        ).values('code', 'description', 'uses', 'value', 'commission')
        
        return {
            'period_days': period_days,
            'start_date': start_date,
            'end_date': end_date,
            'total_clicks': total_clicks,
            'total_conversions': total_conversions,
            'conversion_rate': conversion_rate,
            'total_earnings': total_earnings,
            'conversion_breakdown': conversion_breakdown,
            'link_performance': link_performance,
            'voucher_performance': voucher_performance,
            'pending_earnings': affiliate.pending_earnings(),
            'total_earnings_all_time': affiliate.total_earnings()
        }
    
    def get_conversion_history(self, affiliate, start_date=None, end_date=None, 
                             conversion_type=None, is_verified=None, is_paid=None):
        """Get detailed conversion history for an affiliate."""
        # Set default date range if not provided
        if not end_date:
            end_date = timezone.now()
        if not start_date:
            start_date = end_date - timedelta(days=90)
            
        # Base query
        conversions = Conversion.objects.filter(
            affiliate=affiliate,
            conversion_date__gte=start_date,
            conversion_date__lte=end_date
        )
        
        # Apply filters if provided
        if conversion_type:
            conversions = conversions.filter(conversion_type=conversion_type)
            
        if is_verified is not None:
            conversions = conversions.filter(is_verified=is_verified)
            
        if is_paid is not None:
            conversions = conversions.filter(is_paid=is_paid)
            
        return conversions.order_by('-conversion_date')
    
    def get_payment_history(self, affiliate):
        """Get payment history for an affiliate."""
        return AffiliatePayment.objects.filter(affiliate=affiliate).order_by('-created_at')


class AffiliatePaymentService:
    """Service for handling affiliate payments."""
    
    def __init__(self):
        self.sumup_service = SumUpPaymentService()
    
    def calculate_affiliate_earnings(self, affiliate, start_date, end_date):
        """Calculate total earnings for an affiliate in a given period."""
        conversions = Conversion.objects.filter(
            affiliate=affiliate,
            conversion_date__gte=start_date,
            conversion_date__lte=end_date,
            is_verified=True,
            is_paid=False
        )
        
        total_earnings = conversions.aggregate(
            total=Sum('commission_amount')
        )['total'] or Decimal('0.00')
        
        # Add fixed fee if applicable
        if affiliate.commission_model == 'FIXED_PERFORMANCE':
            # Calculate number of months in period
            months = (end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)
            if months > 0:
                total_earnings += affiliate.fixed_fee * months
        
        return {
            'total_earnings': total_earnings,
            'conversions': conversions,
            'conversion_count': conversions.count()
        }
    
    def create_payment(self, affiliate, amount, currency='EUR', payment_method='bank_transfer',
                     period_start=None, period_end=None, conversions=None):
        """Create a payment record for an affiliate."""
        if not period_start:
            period_start = timezone.now().date().replace(day=1)
        
        if not period_end:
            # Last day of the month
            next_month = period_start.replace(day=28) + timedelta(days=4)
            period_end = next_month - timedelta(days=next_month.day)
        
        payment = AffiliatePayment.objects.create(
            affiliate=affiliate,
            amount=amount,
            currency=currency,
            payment_method=payment_method,
            period_start=period_start,
            period_end=period_end,
            status='PENDING'
        )
        
        # Link conversions to payment
        if conversions:
            payment.conversions.set(conversions)
        
        return payment
    
    def process_payment_via_sumup(self, payment):
        """Process payment through SumUp."""
        try:
            # Create SumUp checkout
            checkout_data = {
                'amount': float(payment.amount),
                'currency': payment.currency,
                'description': f'Affiliate payment for {payment.affiliate.name}',
                'merchant_code': settings.SUMUP_MERCHANT_CODE,
                'pay_to_email': payment.affiliate.email,
                'redirect_url': f"{settings.FRONTEND_URL}/affiliate/payment-success",
                'return_url': f"{settings.FRONTEND_URL}/affiliate/payment-return"
            }
            
            checkout = self.sumup_service.create_checkout(checkout_data)
            
            if checkout and 'id' in checkout:
                payment.sumup_checkout_id = checkout['id']
                payment.status = 'PROCESSING'
                payment.save()
                
                logger.info(f"Created SumUp checkout {checkout['id']} for affiliate payment {payment.id}")
                return checkout
            else:
                logger.error(f"Failed to create SumUp checkout for affiliate payment {payment.id}")
                payment.status = 'FAILED'
                payment.save()
                return None
                
        except Exception as e:
            logger.error(f"Error processing SumUp payment for affiliate {payment.affiliate.id}: {str(e)}")
            payment.status = 'FAILED'
            payment.save()
            return None
    
    def verify_payment_status(self, payment):
        """Verify payment status with SumUp."""
        if not payment.sumup_checkout_id:
            return False
            
        try:
            checkout_status = self.sumup_service.get_checkout_status(payment.sumup_checkout_id)
            
            if checkout_status:
                if checkout_status.get('status') == 'PAID':
                    payment.status = 'COMPLETED'
                    payment.sumup_transaction_code = checkout_status.get('transaction_code')
                    payment.save()
                    
                    # Mark related conversions as paid
                    payment.conversions.update(is_paid=True)
                    
                    logger.info(f"Affiliate payment {payment.id} completed successfully")
                    return True
                elif checkout_status.get('status') == 'FAILED':
                    payment.status = 'FAILED'
                    payment.save()
                    logger.warning(f"Affiliate payment {payment.id} failed")
                    return False
                    
        except Exception as e:
            logger.error(f"Error verifying payment status for affiliate payment {payment.id}: {str(e)}")
            
        return False
    
    def generate_monthly_payments(self, month=None, year=None):
        """Generate monthly payments for all affiliates."""
        if not month:
            month = timezone.now().month
        if not year:
            year = timezone.now().year
            
        # Calculate period
        period_start = timezone.datetime(year, month, 1).date()
        if month == 12:
            period_end = timezone.datetime(year + 1, 1, 1).date() - timedelta(days=1)
        else:
            period_end = timezone.datetime(year, month + 1, 1).date() - timedelta(days=1)
        
        payments_created = []
        
        # Get all active affiliates
        affiliates = Affiliate.objects.filter(is_active=True)
        
        for affiliate in affiliates:
            # Calculate earnings for the period
            earnings_data = self.calculate_affiliate_earnings(
                affiliate=affiliate,
                start_date=period_start,
                end_date=period_end
            )
            
            if earnings_data['total_earnings'] > 0:
                # Create payment
                payment = self.create_payment(
                    affiliate=affiliate,
                    amount=earnings_data['total_earnings'],
                    period_start=period_start,
                    period_end=period_end,
                    conversions=earnings_data['conversions']
                )
                
                payments_created.append(payment)
                logger.info(f"Created payment {payment.id} for affiliate {affiliate.name}: €{payment.amount}")
        
        return payments_created


class AffiliateService:
    """Service for managing affiliate operations."""
    
    def __init__(self):
        self.tracking_service = AffiliateTrackingService()
    
    def create_affiliate_from_application(self, application, approved_by=None):
        """Create an affiliate profile from an approved application."""
        from django.utils import timezone
        
        # Generate tracking code
        tracking_code = self.tracking_service.generate_tracking_code()
        
        # Create affiliate profile
        affiliate = Affiliate.objects.create(
            user=application.user,
            name=application.business_name or application.user.get_full_name() or application.user.email,
            email=application.user.email,
            website=application.website_url,
            description=application.audience_description,
            affiliate_plan=application.requested_plan,
            tracking_code=tracking_code,
            is_active=True
        )
        
        # Create default affiliate link
        default_link = self.tracking_service.create_affiliate_link(
            affiliate=affiliate,
            target_url=f"{settings.FRONTEND_URL}/",
            name="Main App Link",
            link_type='GENERAL'
        )
        
        # Create default voucher code
        voucher = self.tracking_service.create_voucher_code(
            affiliate=affiliate,
            code_type='PERCENTAGE',
            discount_value=10,  # Default 10% discount
            description=f"10% discount with {affiliate.name}",
            max_uses=0,  # Unlimited
            valid_days=365,  # Valid for 1 year
            prefix=affiliate.tracking_code[:4]
        )
        
        # Update application status
        application.status = 'APPROVED'
        application.reviewed_by = approved_by
        application.reviewed_at = timezone.now()
        application.save()
        
        return affiliate
    
    def calculate_commission_for_plan(self, plan, conversion_type, conversion_value=0.00):
        """Calculate commission based on affiliate plan."""
        commission = Decimal('0.00')
        
        if conversion_type == 'DOWNLOAD' and plan.commission_per_download > 0:
            commission += plan.commission_per_download
        
        if conversion_type == 'SUBSCRIPTION':
            if plan.commission_per_subscription > 0:
                commission += plan.commission_per_subscription
            
            if plan.commission_percentage > 0 and conversion_value > 0:
                commission += (conversion_value * plan.commission_percentage / 100)
        
        return commission
    
    def get_affiliate_performance_metrics(self, affiliate, period_days=30):
        """Get performance metrics for an affiliate."""
        end_date = timezone.now()
        start_date = end_date - timedelta(days=period_days)
        
        # Get conversions in period
        conversions = Conversion.objects.filter(
            affiliate=affiliate,
            conversion_date__gte=start_date,
            conversion_date__lte=end_date
        )
        
        # Get clicks in period
        clicks = ClickEvent.objects.filter(
            affiliate=affiliate,
            timestamp__gte=start_date,
            timestamp__lte=end_date
        )
        
        # Calculate metrics
        total_clicks = clicks.count()
        total_conversions = conversions.count()
        total_earnings = conversions.filter(is_verified=True).aggregate(
            total=Sum('commission_amount')
        )['total'] or Decimal('0.00')
        
        conversion_rate = (total_conversions / total_clicks * 100) if total_clicks > 0 else 0
        
        # Breakdown by conversion type
        conversion_breakdown = {}
        for conv_type, _ in Conversion.CONVERSION_TYPE_CHOICES:
            count = conversions.filter(conversion_type=conv_type).count()
            if count > 0:
                conversion_breakdown[conv_type] = count
        
        return {
            'period_days': period_days,
            'total_clicks': total_clicks,
            'total_conversions': total_conversions,
            'conversion_rate': round(conversion_rate, 2),
            'total_earnings': total_earnings,
            'conversion_breakdown': conversion_breakdown,
            'average_commission': total_earnings / total_conversions if total_conversions > 0 else Decimal('0.00')
        } 