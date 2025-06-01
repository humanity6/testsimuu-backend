from rest_framework import generics, status, filters, viewsets
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from exam_prep_platform.permissions import IsAdminUser
from rest_framework.exceptions import ValidationError
from rest_framework.decorators import action
from django.utils import timezone
from django.db.models import Q
from django.conf import settings
from datetime import datetime
import hmac
import hashlib
import json
import logging
from .models import PricingPlan, UserSubscription, ReferralProgram, UserReferral, Payment
from users.models import User
from exams.models import Exam
from .services import SumUpPaymentService, SubscriptionManagementService
from .serializers import (
    PricingPlanSerializer,
    PricingPlanDetailSerializer,
    UserSubscriptionSerializer,
    UserSubscriptionCreateSerializer,
    SubscriptionCancelSerializer,
    ReferralProgramSerializer,
    ReferralProgramDetailSerializer,
    UserReferralSerializer,
    ReferralCodeApplySerializer,
    PaymentSerializer,
    PaymentDetailSerializer,
    SumUpWebhookSerializer,
    BundleSubscriptionSerializer,
    PaymentVerificationSerializer,
    # Admin serializers
    AdminPricingPlanSerializer,
    AdminPricingPlanCreateSerializer,
    AdminPricingPlanUpdateSerializer,
    AdminUserSubscriptionSerializer,
    AdminUserSubscriptionCreateSerializer,
    AdminUserSubscriptionUpdateSerializer,
    AdminReferralProgramSerializer,
    AdminReferralProgramCreateSerializer,
    AdminReferralProgramUpdateSerializer,
    AdminUserReferralSerializer
)

logger = logging.getLogger(__name__)


class PricingPlanListView(generics.ListAPIView):
    serializer_class = PricingPlanSerializer
    permission_classes = [AllowAny]  # Make pricing plans publicly accessible
    
    def get_queryset(self):
        queryset = PricingPlan.objects.filter(is_active=True).order_by('display_order')
        
        # Filter by exam if provided
        exam_id = self.request.query_params.get('exam_id')
        if exam_id:
            queryset = queryset.filter(exam_id=exam_id)
            
        exam_slug = self.request.query_params.get('exam_slug')
        if exam_slug:
            queryset = queryset.filter(exam__slug=exam_slug)
            
        return queryset


class PricingPlanDetailView(generics.RetrieveAPIView):
    serializer_class = PricingPlanDetailSerializer
    permission_classes = [AllowAny]  # Make pricing plan details publicly accessible
    lookup_field = 'slug'
    
    def get_queryset(self):
        return PricingPlan.objects.filter(is_active=True)
    
    def get_object(self):
        lookup_value = self.kwargs[self.lookup_field]
        
        # Try to retrieve by slug first
        queryset = self.get_queryset()
        
        # If the lookup value is numeric, try finding by ID
        if lookup_value.isdigit():
            try:
                return queryset.get(id=lookup_value)
            except PricingPlan.DoesNotExist:
                pass
                
        # Otherwise, find by slug
        return queryset.get(slug=lookup_value)


class UserSubscriptionListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserSubscriptionCreateSerializer
        return UserSubscriptionSerializer
    
    def get_queryset(self):
        return UserSubscription.objects.filter(user=self.request.user).order_by('-start_date')
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription = serializer.save()
        
        # Use the SumUp payment service to create a checkout
        try:
            payment_service = SumUpPaymentService()
            checkout = payment_service.create_checkout(
                user=request.user,
                subscription=subscription,
                return_url=request.build_absolute_uri('/account/subscription/thank-you/')
            )
            
            return Response({
                'subscription': UserSubscriptionSerializer(subscription).data,
                'payment_url': checkout.get('checkout_url'),
                'transaction_id': checkout.get('transaction_id'),
                'message': 'Please complete payment to activate your subscription'
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Payment gateway error: {str(e)}")
            # In case of payment gateway error, still create the subscription
            # but let the user know there was an issue
            return Response({
                'subscription': UserSubscriptionSerializer(subscription).data,
                'error': 'Payment gateway error. Please contact support.',
                'message': str(e)
            }, status=status.HTTP_201_CREATED)


class UserSubscriptionCancelView(generics.GenericAPIView):
    serializer_class = SubscriptionCancelSerializer
    permission_classes = [IsAuthenticated]
    
    def post(self, request, *args, **kwargs):
        try:
            subscription_id = self.kwargs.get('id')
            subscription = UserSubscription.objects.get(
                id=subscription_id,
                user=request.user,
                status='ACTIVE'
            )
            
            # Update subscription status
            subscription.status = 'CANCELED'
            subscription.cancelled_at = timezone.now()
            subscription.auto_renew = False
            subscription.save()
            
            return Response({
                'message': 'Subscription has been canceled successfully',
                'subscription': UserSubscriptionSerializer(subscription).data
            }, status=status.HTTP_200_OK)
            
        except UserSubscription.DoesNotExist:
            return Response({
                'error': 'Active subscription not found or you do not have permission to cancel it'
            }, status=status.HTTP_404_NOT_FOUND)


# Referral Program Views
class ReferralProgramListView(generics.ListAPIView):
    serializer_class = ReferralProgramSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        now = timezone.now().date()
        return ReferralProgram.objects.filter(
            is_active=True,
            valid_from__lte=now
        ).filter(
            Q(valid_until__isnull=True) | Q(valid_until__gte=now)
        ).order_by('-created_at')


class ReferralProgramDetailView(generics.RetrieveAPIView):
    serializer_class = ReferralProgramDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'
    
    def get_queryset(self):
        return ReferralProgram.objects.all()


class ReferralCodeApplyView(generics.GenericAPIView):
    serializer_class = ReferralCodeApplySerializer
    permission_classes = [IsAuthenticated]
    
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        
        # Get the stored context data from validation
        referrer = serializer.context.get('referrer')
        referral_program = serializer.context.get('referral_program')
        referral_code = serializer.validated_data.get('referral_code')
        
        # Create UserReferral record
        user_referral = UserReferral.objects.create(
            referrer=referrer,
            referred_user=request.user,
            referral_program=referral_program,
            referral_code_used=referral_code,
            status='PENDING'
        )
        
        return Response({
            'message': 'Referral code applied successfully.',
            'referral': UserReferralSerializer(user_referral).data
        }, status=status.HTTP_201_CREATED)


class UserReferralListView(generics.ListAPIView):
    serializer_class = UserReferralSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return UserReferral.objects.filter(referrer=self.request.user).order_by('-date_referred')


# Payment API Views
class UserPaymentListView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Payment.objects.filter(user=self.request.user).order_by('-transaction_time')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())
        
        # Filter by date range if provided
        date_from = self.request.query_params.get('from')
        date_to = self.request.query_params.get('to')
        
        if date_from:
            try:
                date_from = datetime.strptime(date_from, '%Y-%m-%d').date()
                queryset = queryset.filter(transaction_time__date__gte=date_from)
            except ValueError:
                pass
                
        if date_to:
            try:
                date_to = datetime.strptime(date_to, '%Y-%m-%d').date()
                queryset = queryset.filter(transaction_time__date__lte=date_to)
            except ValueError:
                pass
                
        return queryset


class UserPaymentDetailView(generics.RetrieveAPIView):
    serializer_class = PaymentDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'
    
    def get_queryset(self):
        return Payment.objects.filter(user=self.request.user)


# SumUp Webhook Handler
class SumUpWebhookVerificationMixin:
    """Mixin for verifying SumUp webhook requests."""
    
    def verify_signature(self, request):
        """Verify that the webhook request came from SumUp."""
        try:
            webhook_secret = getattr(settings, 'SUMUP_WEBHOOK_SECRET', '')
            
            if not webhook_secret:
                logger.warning('SumUp webhook secret not configured')
                return False
                
            signature = request.headers.get('Sumup-Signature', '')
            
            if not signature:
                logger.warning('No SumUp signature in request headers')
                return False
                
            # Get the raw body
            body = request.body.decode('utf-8')
            
            # Compute HMAC
            expected_signature = hmac.new(
                webhook_secret.encode('utf-8'),
                body.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
            
            # Compare signatures
            return hmac.compare_digest(signature, expected_signature)
                
        except Exception as e:
            logger.error(f"Error verifying webhook signature: {str(e)}")
            return False


class SumUpWebhookHandlerView(SumUpWebhookVerificationMixin, generics.GenericAPIView):
    serializer_class = SumUpWebhookSerializer
    permission_classes = [AllowAny]  # Public endpoint
    
    def post(self, request, *args, **kwargs):
        # Verify signature
        if not self.verify_signature(request):
            logger.warning('Invalid webhook signature')
            return Response({'error': 'Invalid signature'}, status=status.HTTP_401_UNAUTHORIZED)
        
        # Process webhook data
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        event_type = serializer.validated_data.get('event_type')
        transaction_id = serializer.validated_data.get('transaction_id')
        payment_status = serializer.validated_data.get('status')
        
        logger.info(f"Received SumUp webhook: {event_type} - {transaction_id} - {payment_status}")
        
        try:
            # Find the payment record
            try:
                payment = Payment.objects.get(payment_gateway_transaction_id=transaction_id)
            except Payment.DoesNotExist:
                logger.error(f"Payment with transaction ID {transaction_id} not found")
                return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)
            
            # Update payment status based on the webhook
            if event_type == 'PAYMENT_STATUS_CHANGED':
                mapped_status = self.map_sumup_status(payment_status)
                payment.status = mapped_status
                
                # If amount and currency provided, update those too
                if 'amount' in serializer.validated_data:
                    payment.amount = serializer.validated_data.get('amount')
                if 'currency' in serializer.validated_data:
                    payment.currency = serializer.validated_data.get('currency')
                
                # Update payment metadata
                if payment.metadata is None:
                    payment.metadata = {}
                
                payment.metadata.update({
                    'webhook_received': timezone.now().isoformat(),
                    'webhook_event_type': event_type,
                    'webhook_status': payment_status,
                })
                
                payment.save()
                
                # Handle successful payment
                if mapped_status == 'SUCCESSFUL':
                    self.handle_successful_payment(payment)
                
                # Handle refunded payment
                elif mapped_status == 'REFUNDED':
                    self.handle_refunded_payment(payment)
                
                return Response({'status': 'success'}, status=status.HTTP_200_OK)
                
            else:
                logger.warning(f"Unhandled webhook event type: {event_type}")
                return Response({'warning': 'Unhandled event type'}, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing webhook: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def map_sumup_status(self, sumup_status):
        """Map SumUp status to our internal status."""
        status_map = {
            'PENDING': 'PENDING',
            'PAID': 'SUCCESSFUL',
            'FAILED': 'FAILED',
            'CANCELLED': 'FAILED',
            'EXPIRED': 'FAILED',
            'REFUNDED': 'REFUNDED',
            'PARTIALLY_REFUNDED': 'REFUNDED',
        }
        
        return status_map.get(sumup_status, 'PENDING')
    
    def handle_successful_payment(self, payment):
        """Handle actions needed when a payment is successful."""
        # Update subscription if it exists
        if payment.user_subscription:
            subscription = payment.user_subscription
            
            # Check if this is a bundle payment
            if payment.metadata and payment.metadata.get('is_bundle', False):
                # Update all subscriptions in the bundle
                subscription_ids = payment.metadata.get('subscription_ids', [])
                for sub_id in subscription_ids:
                    try:
                        sub = UserSubscription.objects.get(id=sub_id)
                        sub.status = 'ACTIVE'
                        sub.save()
                    except UserSubscription.DoesNotExist:
                        logger.error(f"Subscription {sub_id} in bundle not found")
            else:
                # Single subscription
                subscription.status = 'ACTIVE'
                subscription.save()
        
        # Create notification for the user
        user = payment.user
        self.create_payment_notification(
            user=user,
            title='Payment Successful',
            message=f'Your payment of {payment.amount} {payment.currency} was successful. Your subscription is now active.'
        )
        
        # Process referral if applicable
        self.process_referral_completion(user)
    
    def handle_refunded_payment(self, payment):
        """Handle actions needed when a payment is refunded."""
        # Update subscription if it exists
        if payment.user_subscription:
            subscription = payment.user_subscription
            
            # Check if this is a bundle payment
            if payment.metadata and payment.metadata.get('is_bundle', False):
                # Update all subscriptions in the bundle
                subscription_ids = payment.metadata.get('subscription_ids', [])
                for sub_id in subscription_ids:
                    try:
                        sub = UserSubscription.objects.get(id=sub_id)
                        sub.status = 'CANCELED'
                        sub.save()
                    except UserSubscription.DoesNotExist:
                        logger.error(f"Subscription {sub_id} in bundle not found")
            else:
                # Single subscription
                subscription.status = 'CANCELED'
                subscription.save()
        
        # Create notification for the user
        user = payment.user
        self.create_payment_notification(
            user=user,
            title='Payment Refunded',
            message=f'Your payment of {payment.amount} {payment.currency} has been refunded.'
        )
    
    def create_payment_notification(self, user, title, message):
        """Create a notification for the user."""
        try:
            # Import here to avoid circular imports
            from notifications.models import Notification
            
            Notification.objects.create(
                user=user,
                title=title,
                message=message,
                notification_type='PAYMENT',
                is_read=False
            )
            
        except ImportError:
            logger.warning('Notifications app not available, skipping notification creation')
        except Exception as e:
            logger.error(f"Error creating notification: {str(e)}")
    
    def process_referral_completion(self, user):
        """Process referral completion if this user was referred."""
        try:
            # Check if this user was referred
            user_referral = UserReferral.objects.filter(
                referred_user=user,
                status='PENDING'
            ).first()
            
            if user_referral:
                # Mark the referral as completed
                user_referral.status = 'COMPLETED'
                user_referral.date_completed = timezone.now()
                user_referral.save()
                
                # Create notification for the referrer
                referrer = user_referral.referrer
                self.create_payment_notification(
                    user=referrer,
                    title='Referral Completed',
                    message=f'Your referral {user.email} has completed a purchase. Your reward will be processed shortly.'
                )
                
        except Exception as e:
            logger.error(f"Error processing referral completion: {str(e)}")


class BundleSubscriptionCreateView(generics.GenericAPIView):
    """Create multiple subscriptions as a bundle and process payment together."""
    serializer_class = BundleSubscriptionSerializer
    permission_classes = [IsAuthenticated]
    
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        # Create all subscriptions
        pricing_plan_ids = serializer.validated_data.get('pricing_plan_ids', [])
        subscriptions = []
        
        for plan_id in pricing_plan_ids:
            try:
                pricing_plan = PricingPlan.objects.get(id=plan_id, is_active=True)
                
                # Set the start date to now
                start_date = timezone.now()
                
                # Calculate end date based on billing cycle
                if pricing_plan.billing_cycle == 'MONTHLY':
                    end_date = start_date + timezone.timedelta(days=30)
                elif pricing_plan.billing_cycle == 'QUARTERLY':
                    end_date = start_date + timezone.timedelta(days=90)
                elif pricing_plan.billing_cycle == 'YEARLY':
                    end_date = start_date + timezone.timedelta(days=365)
                elif pricing_plan.billing_cycle == 'ONE_TIME':
                    end_date = start_date + timezone.timedelta(days=3650)
                else:
                    end_date = start_date + timezone.timedelta(days=30)
                
                # Create subscription
                subscription = UserSubscription.objects.create(
                    user=request.user,
                    pricing_plan=pricing_plan,
                    start_date=start_date,
                    end_date=end_date,
                    status='PENDING_PAYMENT',
                    auto_renew=True
                )
                
                subscriptions.append(subscription)
                
            except PricingPlan.DoesNotExist:
                # Clean up created subscriptions
                for sub in subscriptions:
                    sub.delete()
                return Response({
                    'error': f'Pricing plan with ID {plan_id} does not exist or is not active'
                }, status=status.HTTP_400_BAD_REQUEST)
        
        # Process bundle payment
        try:
            payment_service = SumUpPaymentService()
            checkout = payment_service.create_bundle_checkout(
                user=request.user,
                subscriptions=subscriptions,
                return_url=request.build_absolute_uri('/account/subscription/thank-you/')
            )
            
            return Response({
                'subscriptions': UserSubscriptionSerializer(subscriptions, many=True).data,
                'payment_url': checkout.get('checkout_url'),
                'transaction_id': checkout.get('transaction_id'),
                'message': 'Please complete payment to activate your subscriptions'
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Bundle payment error: {str(e)}")
            # Clean up created subscriptions on payment error
            for sub in subscriptions:
                sub.delete()
            
            return Response({
                'error': 'Payment gateway error. Please try again or contact support.',
                'message': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PaymentVerificationView(generics.GenericAPIView):
    """Verify the status of a payment with SumUp and update local records."""
    serializer_class = PaymentVerificationSerializer
    permission_classes = [IsAuthenticated]
    
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        transaction_id = serializer.validated_data.get('transaction_id')
        
        try:
            payment_service = SumUpPaymentService()
            result = payment_service.verify_payment(transaction_id)
            
            if result.get('status') == 'error':
                return Response({
                    'error': result.get('message')
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get the payment for the response
            try:
                payment = Payment.objects.get(payment_gateway_transaction_id=transaction_id)
                
                # Include subscription information if available
                subscription_data = None
                if payment.user_subscription:
                    subscription_data = UserSubscriptionSerializer(payment.user_subscription).data
                
                return Response({
                    'status': 'success',
                    'payment': PaymentSerializer(payment).data,
                    'subscription': subscription_data,
                    'message': f'Payment status: {payment.status}'
                }, status=status.HTTP_200_OK)
                
            except Payment.DoesNotExist:
                return Response({
                    'error': 'Payment record not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
        except Exception as e:
            logger.error(f"Payment verification error: {str(e)}")
            return Response({
                'error': 'Error verifying payment',
                'message': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class GetAvailablePaymentMethodsView(generics.GenericAPIView):
    """Get the available payment methods from SumUp for the merchant."""
    permission_classes = [IsAuthenticated]
    
    def get(self, request, *args, **kwargs):
        try:
            payment_service = SumUpPaymentService()
            payment_methods = payment_service.get_available_payment_methods()
            
            return Response({
                'payment_methods': payment_methods
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting payment methods: {str(e)}")
            return Response({
                'error': 'Error retrieving payment methods',
                'message': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Admin API views for subscription management
class AdminPricingPlanViewSet(viewsets.ModelViewSet):
    """Admin API for managing pricing plans."""
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['is_active', 'billing_cycle', 'exam']
    search_fields = ['name', 'description', 'slug']
    ordering_fields = ['name', 'price', 'display_order', 'created_at']
    ordering = ['display_order', 'name']
    
    def get_queryset(self):
        queryset = PricingPlan.objects.all().order_by('display_order', 'name')
        
        # Filter by exam if provided
        exam_id = self.request.query_params.get('exam_id')
        if exam_id:
            queryset = queryset.filter(exam_id=exam_id)
            
        # Filter by billing cycle if provided
        billing_cycle = self.request.query_params.get('billing_cycle')
        if billing_cycle:
            queryset = queryset.filter(billing_cycle=billing_cycle)
            
        # Filter by active status if provided
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            is_active = is_active.lower() == 'true'
            queryset = queryset.filter(is_active=is_active)
            
        return queryset
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AdminPricingPlanCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return AdminPricingPlanUpdateSerializer
        return AdminPricingPlanSerializer
    
    def perform_destroy(self, instance):
        # Check if the plan has active subscriptions before deletion
        if UserSubscription.objects.filter(pricing_plan=instance, status='ACTIVE').exists():
            raise ValidationError("Cannot delete plan with active subscriptions")
        instance.delete()
    
    @action(detail=True, methods=['post'])
    def duplicate(self, request, pk=None):
        """Duplicate a pricing plan."""
        try:
            plan = self.get_object()
            
            # Create a copy with new name and slug
            plan.pk = None
            plan.name = f"Copy of {plan.name}"
            
            # Generate a unique slug
            from django.utils.text import slugify
            base_slug = slugify(plan.name)
            slug = base_slug
            counter = 1
            while PricingPlan.objects.filter(slug=slug).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            
            plan.slug = slug
            plan.is_active = False
            plan.payment_gateway_plan_id = None
            plan.save()
            
            return Response(
                AdminPricingPlanSerializer(plan).data,
                status=status.HTTP_201_CREATED
            )
            
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['get'])
    def by_exam(self, request):
        """Get pricing plans grouped by exam."""
        result = []
        
        # Get all exams
        exams = Exam.objects.filter(is_active=True)
        
        for exam in exams:
            plans = PricingPlan.objects.filter(exam=exam).order_by('display_order')
            
            if plans.exists():
                result.append({
                    'exam_id': exam.id,
                    'exam_name': exam.name,
                    'plans': AdminPricingPlanSerializer(plans, many=True).data
                })
        
        return Response(result)
    
    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        """Activate a pricing plan."""
        plan = self.get_object()
        plan.is_active = True
        plan.save()
        return Response({'status': 'Plan activated'})
    
    @action(detail=True, methods=['post'])
    def deactivate(self, request, pk=None):
        """Deactivate a pricing plan."""
        plan = self.get_object()
        plan.is_active = False
        plan.save()
        return Response({'status': 'Plan deactivated'})


class AdminUserSubscriptionViewSet(viewsets.ModelViewSet):
    """Admin API for managing user subscriptions."""
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['status', 'auto_renew']
    search_fields = ['user__email', 'user__username', 'pricing_plan__name']
    ordering_fields = ['start_date', 'end_date', 'created_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        queryset = UserSubscription.objects.all()
        
        # Filter by user if provided
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
            
        # Filter by pricing plan if provided
        pricing_plan_id = self.request.query_params.get('pricing_plan_id')
        if pricing_plan_id:
            queryset = queryset.filter(pricing_plan_id=pricing_plan_id)
            
        # Filter by exam if provided
        exam_id = self.request.query_params.get('exam_id')
        if exam_id:
            queryset = queryset.filter(pricing_plan__exam_id=exam_id)
            
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
            
        # Filter by auto_renew if provided
        auto_renew = self.request.query_params.get('auto_renew')
        if auto_renew is not None:
            auto_renew = auto_renew.lower() == 'true'
            queryset = queryset.filter(auto_renew=auto_renew)
            
        # Filter by expiring soon
        expiring_soon = self.request.query_params.get('expiring_soon')
        if expiring_soon is not None:
            now = timezone.now()
            days = int(expiring_soon) if expiring_soon.isdigit() else 7
            threshold = now + timezone.timedelta(days=days)
            queryset = queryset.filter(
                status='ACTIVE', 
                end_date__lte=threshold,
                end_date__gt=now
            )
            
        # Filter by expired
        expired = self.request.query_params.get('expired')
        if expired is not None and expired.lower() == 'true':
            now = timezone.now()
            queryset = queryset.filter(
                status='ACTIVE',
                end_date__lt=now
            )
            
        return queryset
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AdminUserSubscriptionCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return AdminUserSubscriptionUpdateSerializer
        return AdminUserSubscriptionSerializer
    
    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel a subscription."""
        subscription = self.get_object()
        
        # Update subscription status
        subscription.status = 'CANCELED'
        subscription.cancelled_at = timezone.now()
        subscription.auto_renew = False
        subscription.save()
        
        return Response({
            'status': 'Subscription canceled',
            'subscription': AdminUserSubscriptionSerializer(subscription).data
        })
    
    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        """Activate a subscription."""
        subscription = self.get_object()
        
        # Update subscription status
        subscription.status = 'ACTIVE'
        subscription.save()
        
        return Response({
            'status': 'Subscription activated',
            'subscription': AdminUserSubscriptionSerializer(subscription).data
        })
    
    @action(detail=True, methods=['post'])
    def extend(self, request, pk=None):
        """Extend a subscription."""
        subscription = self.get_object()
        days = request.data.get('days', 30)
        
        try:
            days = int(days)
        except (TypeError, ValueError):
            return Response(
                {'error': 'Days must be a valid integer'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Update subscription end date
        if subscription.end_date:
            subscription.end_date = subscription.end_date + timezone.timedelta(days=days)
            subscription.save()
            
            return Response({
                'status': f'Subscription extended by {days} days',
                'subscription': AdminUserSubscriptionSerializer(subscription).data
            })
        else:
            return Response(
                {'error': 'Subscription has no end date'},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['post'])
    def sync_payment_status(self, request, pk=None):
        """Sync subscription with payment gateway."""
        subscription = self.get_object()
        
        subscription_service = SubscriptionManagementService()
        success, message = subscription_service.sync_subscription_status(subscription.id)
        
        if success:
            # Refresh the subscription object
            subscription = UserSubscription.objects.get(id=subscription.id)
            return Response({
                'status': 'success',
                'message': message,
                'subscription': AdminUserSubscriptionSerializer(subscription).data
            })
        else:
            return Response(
                {'error': message},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['post'])
    def process_expired(self, request):
        """Process all expired subscriptions."""
        subscription_service = SubscriptionManagementService()
        count = subscription_service.process_expired_subscriptions()
        
        return Response({
            'status': 'success',
            'message': f'Processed {count} expired subscriptions'
        })
    
    @action(detail=False, methods=['get'])
    def expiring_soon(self, request):
        """Get subscriptions expiring soon."""
        days = request.query_params.get('days', 7)
        try:
            days = int(days)
        except (TypeError, ValueError):
            days = 7
            
        subscription_service = SubscriptionManagementService()
        subscriptions = subscription_service.check_expiring_subscriptions(days_before=days)
        
        return Response({
            'count': subscriptions.count(),
            'subscriptions': AdminUserSubscriptionSerializer(subscriptions, many=True).data
        })


class AdminPaymentViewSet(viewsets.ReadOnlyModelViewSet):
    """Admin API for viewing payments."""
    serializer_class = PaymentDetailSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['status', 'currency']
    search_fields = ['user__email', 'user__username', 'payment_gateway_transaction_id', 'invoice_number']
    ordering_fields = ['transaction_time', 'amount']
    ordering = ['-transaction_time']
    
    def get_queryset(self):
        queryset = Payment.objects.all()
        
        # Filter by user if provided
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
            
        # Filter by subscription if provided
        subscription_id = self.request.query_params.get('subscription_id')
        if subscription_id:
            queryset = queryset.filter(user_subscription_id=subscription_id)
            
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
            
        # Filter by date range if provided
        date_from = self.request.query_params.get('from')
        date_to = self.request.query_params.get('to')
        
        if date_from:
            try:
                date_from = datetime.strptime(date_from, '%Y-%m-%d').date()
                queryset = queryset.filter(transaction_time__date__gte=date_from)
            except ValueError:
                pass
                
        if date_to:
            try:
                date_to = datetime.strptime(date_to, '%Y-%m-%d').date()
                queryset = queryset.filter(transaction_time__date__lte=date_to)
            except ValueError:
                pass
            
        return queryset
    
    @action(detail=True, methods=['post'])
    def mark_as_successful(self, request, pk=None):
        """Mark a payment as successful."""
        payment = self.get_object()
        payment.status = 'SUCCESSFUL'
        payment.save()
        
        # Update subscription if it exists
        if payment.user_subscription:
            subscription = payment.user_subscription
            subscription.status = 'ACTIVE'
            subscription.save()
        
        return Response({
            'status': 'Payment marked as successful',
            'payment': PaymentDetailSerializer(payment).data
        })
    
    @action(detail=True, methods=['post'])
    def mark_as_failed(self, request, pk=None):
        """Mark a payment as failed."""
        payment = self.get_object()
        payment.status = 'FAILED'
        payment.save()
        
        # Update subscription if it exists
        if payment.user_subscription:
            subscription = payment.user_subscription
            subscription.status = 'EXPIRED'
            subscription.save()
        
        return Response({
            'status': 'Payment marked as failed',
            'payment': PaymentDetailSerializer(payment).data
        })
    
    @action(detail=True, methods=['post'])
    def sync_with_sumup(self, request, pk=None):
        """Sync payment status with SumUp."""
        payment = self.get_object()
        
        try:
            payment_service = SumUpPaymentService()
            result = payment_service.verify_payment(payment.payment_gateway_transaction_id)
            
            if result.get('status') == 'error':
                return Response(
                    {'error': result.get('message')},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Refresh the payment object
            payment = Payment.objects.get(id=payment.id)
            return Response({
                'status': 'success',
                'message': f'Payment synced. Status: {payment.status}',
                'payment': PaymentDetailSerializer(payment).data
            })
            
        except Exception as e:
            logger.error(f"Error syncing payment with SumUp: {str(e)}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AdminReferralProgramViewSet(viewsets.ModelViewSet):
    """Admin API for managing referral programs."""
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['is_active', 'reward_type', 'referrer_reward_type']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at', 'updated_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        return ReferralProgram.objects.all()
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AdminReferralProgramCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return AdminReferralProgramUpdateSerializer
        return AdminReferralProgramSerializer
    
    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Toggle the active status of a referral program."""
        program = self.get_object()
        program.is_active = not program.is_active
        program.save()
        
        return Response({
            'status': f'Program {"activated" if program.is_active else "deactivated"}',
            'program': AdminReferralProgramSerializer(program).data
        })


class AdminUserReferralViewSet(viewsets.ReadOnlyModelViewSet):
    """Admin API for viewing user referrals."""
    serializer_class = AdminUserReferralSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['status', 'reward_granted_to_referrer', 'reward_granted_to_referred']
    search_fields = ['referrer__email', 'referred_user__email', 'referral_code_used']
    ordering_fields = ['date_referred', 'date_completed']
    ordering = ['-date_referred']
    
    def get_queryset(self):
        queryset = UserReferral.objects.all()
        
        # Filter by referrer if provided
        referrer_id = self.request.query_params.get('referrer_id')
        if referrer_id:
            queryset = queryset.filter(referrer_id=referrer_id)
            
        # Filter by referred user if provided
        referred_user_id = self.request.query_params.get('referred_user_id')
        if referred_user_id:
            queryset = queryset.filter(referred_user_id=referred_user_id)
            
        # Filter by program if provided
        program_id = self.request.query_params.get('program_id')
        if program_id:
            queryset = queryset.filter(referral_program_id=program_id)
            
        # Filter by date range if provided
        date_from = self.request.query_params.get('from')
        date_to = self.request.query_params.get('to')
        
        if date_from:
            try:
                date_from = datetime.strptime(date_from, '%Y-%m-%d').date()
                queryset = queryset.filter(date_referred__date__gte=date_from)
            except ValueError:
                pass
                
        if date_to:
            try:
                date_to = datetime.strptime(date_to, '%Y-%m-%d').date()
                queryset = queryset.filter(date_referred__date__lte=date_to)
            except ValueError:
                pass
            
        return queryset
    
    @action(detail=True, methods=['post'])
    def mark_rewards_granted(self, request, pk=None):
        """Mark rewards as granted for a referral."""
        referral = self.get_object()
        
        grant_to_referrer = request.data.get('grant_to_referrer', False)
        grant_to_referred = request.data.get('grant_to_referred', False)
        
        if grant_to_referrer:
            referral.reward_granted_to_referrer = True
        if grant_to_referred:
            referral.reward_granted_to_referred = True
            
        referral.save()
        
        return Response({
            'status': 'Rewards marked as granted',
            'referral': AdminUserReferralSerializer(referral).data
        }) 