from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.utils.decorators import method_decorator
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import Payment, UserSubscription
from .services import SumUpPaymentService, SubscriptionManagementService
import json
import logging

logger = logging.getLogger(__name__)


@method_decorator(csrf_exempt, name='dispatch')
@api_view(['POST'])
@permission_classes([AllowAny])
def test_webhook_simulation(request):
    """
    Simulate a SumUp webhook for testing purposes.
    This endpoint allows frontend to trigger webhook events during testing.
    """
    try:
        data = request.data
        transaction_id = data.get('transaction_id')
        status_to_set = data.get('status', 'PAID')  # Default to successful payment
        
        if not transaction_id:
            return Response({
                'error': 'transaction_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Find the payment record
        try:
            payment = Payment.objects.get(payment_gateway_transaction_id=transaction_id)
        except Payment.DoesNotExist:
            return Response({
                'error': 'Payment not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Update payment status based on simulated webhook
        status_map = {
            'PAID': 'SUCCESSFUL',
            'SUCCESSFUL': 'SUCCESSFUL',
            'FAILED': 'FAILED',
            'CANCELLED': 'FAILED',
            'PENDING': 'PENDING',
            'REFUNDED': 'REFUNDED'
        }
        
        new_status = status_map.get(status_to_set, 'SUCCESSFUL')
        old_status = payment.status
        
        payment.status = new_status
        payment.save()
        
        # Update subscription status if payment was successful
        if payment.user_subscription and new_status == 'SUCCESSFUL':
            subscription = payment.user_subscription
            subscription.status = 'ACTIVE'
            subscription.start_date = timezone.now()
            
            # Set end date based on billing cycle
            if subscription.pricing_plan.billing_cycle == 'MONTHLY':
                from datetime import timedelta
                subscription.end_date = timezone.now() + timedelta(days=30)
            elif subscription.pricing_plan.billing_cycle == 'QUARTERLY':
                from datetime import timedelta
                subscription.end_date = timezone.now() + timedelta(days=90)
            elif subscription.pricing_plan.billing_cycle == 'YEARLY':
                from datetime import timedelta
                subscription.end_date = timezone.now() + timedelta(days=365)
            # For ONE_TIME purchases, end_date can remain null
            
            subscription.save()
            
            logger.info(f"Test webhook: Activated subscription {subscription.id} for user {subscription.user.id}")
        
        elif payment.user_subscription and new_status == 'FAILED':
            subscription = payment.user_subscription
            subscription.status = 'CANCELED'
            subscription.save()
            
            logger.info(f"Test webhook: Cancelled subscription {subscription.id} for user {subscription.user.id}")
        
        # Handle bundle payments
        if payment.metadata and payment.metadata.get('is_bundle'):
            subscription_ids = payment.metadata.get('subscription_ids', [])
            for sub_id in subscription_ids:
                try:
                    subscription = UserSubscription.objects.get(id=sub_id)
                    if new_status == 'SUCCESSFUL':
                        subscription.status = 'ACTIVE'
                        subscription.start_date = timezone.now()
                        
                        # Set end dates for bundle subscriptions
                        if subscription.pricing_plan.billing_cycle == 'MONTHLY':
                            from datetime import timedelta
                            subscription.end_date = timezone.now() + timedelta(days=30)
                        elif subscription.pricing_plan.billing_cycle == 'QUARTERLY':
                            from datetime import timedelta
                            subscription.end_date = timezone.now() + timedelta(days=90)
                        elif subscription.pricing_plan.billing_cycle == 'YEARLY':
                            from datetime import timedelta
                            subscription.end_date = timezone.now() + timedelta(days=365)
                        
                        subscription.save()
                        logger.info(f"Test webhook: Activated bundle subscription {subscription.id}")
                    elif new_status == 'FAILED':
                        subscription.status = 'CANCELED'
                        subscription.save()
                        logger.info(f"Test webhook: Cancelled bundle subscription {subscription.id}")
                except UserSubscription.DoesNotExist:
                    logger.warning(f"Bundle subscription {sub_id} not found")
        
        return Response({
            'status': 'success',
            'message': f'Payment status updated from {old_status} to {new_status}',
            'payment_id': payment.id,
            'transaction_id': transaction_id,
            'new_status': new_status
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error in test webhook simulation: {str(e)}")
        return Response({
            'error': 'Error processing test webhook',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def test_payment_status(request, transaction_id):
    """
    Get the current status of a test payment.
    """
    try:
        payment = Payment.objects.get(payment_gateway_transaction_id=transaction_id)
        
        return Response({
            'transaction_id': transaction_id,
            'status': payment.status,
            'amount': str(payment.amount),
            'currency': payment.currency,
            'user_id': payment.user.id,
            'subscription_id': payment.user_subscription.id if payment.user_subscription else None,
            'created_at': payment.transaction_time.isoformat(),
            'is_bundle': payment.metadata.get('is_bundle', False) if payment.metadata else False
        }, status=status.HTTP_200_OK)
        
    except Payment.DoesNotExist:
        return Response({
            'error': 'Payment not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({
            'error': 'Error retrieving payment status',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def simulate_payment_flow(request):
    """
    Simulate the complete payment flow for testing.
    This creates a test payment and automatically processes it.
    """
    try:
        from users.models import User
        from exams.models import Exam
        from .models import PricingPlan
        
        # Get or create test data
        user_id = request.data.get('user_id')
        pricing_plan_id = request.data.get('pricing_plan_id')
        auto_complete = request.data.get('auto_complete', True)
        
        if not user_id or not pricing_plan_id:
            return Response({
                'error': 'user_id and pricing_plan_id are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(id=user_id)
            pricing_plan = PricingPlan.objects.get(id=pricing_plan_id)
        except (User.DoesNotExist, PricingPlan.DoesNotExist) as e:
            return Response({
                'error': f'User or pricing plan not found: {str(e)}'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Create subscription management service
        subscription_service = SubscriptionManagementService()
        
        # Create a subscription
        subscription = subscription_service.create_user_subscription(
            user=user,
            pricing_plan=pricing_plan,
            status='PENDING_PAYMENT'
        )
        
        # Create payment service and generate checkout
        payment_service = SumUpPaymentService()
        checkout_result = payment_service.create_checkout(
            user=user,
            subscription=subscription,
            description=f"Test payment for {pricing_plan.name}"
        )
        
        response_data = {
            'subscription_id': subscription.id,
            'payment_id': checkout_result['payment_id'],
            'checkout_url': checkout_result['checkout_url'],
            'transaction_id': checkout_result['transaction_id'],
            'checkout_id': checkout_result['checkout_id']
        }
        
        # Auto-complete the payment if requested
        if auto_complete:
            # Simulate successful payment
            import time
            time.sleep(1)  # Simulate processing delay
            
            # Call our test webhook simulation
            webhook_response = test_webhook_simulation(type('Request', (), {
                'data': {
                    'transaction_id': checkout_result['transaction_id'],
                    'status': 'PAID'
                }
            })())
            
            if webhook_response.status_code == 200:
                response_data['payment_completed'] = True
                response_data['subscription_status'] = 'ACTIVE'
            else:
                response_data['payment_completed'] = False
                response_data['webhook_error'] = 'Failed to auto-complete payment'
        
        return Response(response_data, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"Error in simulate payment flow: {str(e)}")
        return Response({
            'error': 'Error simulating payment flow',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def test_configuration_status(request):
    """
    Check the current test configuration and SumUp settings.
    """
    from django.conf import settings
    
    config = {
        'testing_mode': getattr(settings, 'SUMUP_TESTING_MODE', True),
        'api_key_configured': bool(getattr(settings, 'SUMUP_API_KEY', '')),
        'merchant_id_configured': bool(getattr(settings, 'SUMUP_MERCHANT_ID', '')),
        'webhook_url': getattr(settings, 'SUMUP_WEBHOOK_URL', ''),
        'return_url': getattr(settings, 'SUMUP_RETURN_URL', ''),
        'api_base_url': getattr(settings, 'SUMUP_API_BASE_URL', ''),
        'frontend_url': getattr(settings, 'FRONTEND_URL', ''),
    }
    
    # Test payment service initialization
    try:
        payment_service = SumUpPaymentService()
        config['payment_service_initialized'] = True
        config['payment_service_testing'] = payment_service.is_testing
    except Exception as e:
        config['payment_service_initialized'] = False
        config['payment_service_error'] = str(e)
    
    return Response({
        'status': 'Configuration retrieved successfully',
        'configuration': config,
        'recommendations': _get_configuration_recommendations(config)
    }, status=status.HTTP_200_OK)


def _get_configuration_recommendations(config):
    """
    Provide configuration recommendations based on current setup.
    """
    recommendations = []
    
    if not config['testing_mode']:
        if not config['api_key_configured']:
            recommendations.append("Set SUMUP_API_KEY environment variable for production")
        if not config['merchant_id_configured']:
            recommendations.append("Set SUMUP_MERCHANT_ID environment variable for production")
    
    if config['testing_mode']:
        recommendations.append("Currently in testing mode - payments will be simulated")
        recommendations.append("Use the test endpoints to simulate payment flows")
    
    if not config.get('payment_service_initialized'):
        recommendations.append("Payment service failed to initialize - check configuration")
    
    return recommendations 