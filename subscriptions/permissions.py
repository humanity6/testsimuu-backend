from rest_framework import permissions
from django.utils import timezone
from .models import UserSubscription, PricingPlan
import logging

logger = logging.getLogger(__name__)


class HasActiveExamSubscription(permissions.BasePermission):
    """
    Custom permission to only allow users with an active subscription
    for the specific Exam to access the content or create a session.
    """
    
    def has_permission(self, request, view):
        # Admin users bypass subscription check
        if request.user.is_staff:
            return True
            
        # For exam session listing, just check if user has any active subscription
        if (hasattr(view, 'action') and view.action == 'list' and 
            view.__class__.__name__ == 'ExamSessionViewSet'):
            return self._has_any_active_subscription(request.user)
            
        # For non-admin users, check for an active subscription
        exam_id = self._get_exam_id(request, view)
        
        if not exam_id:
            # For list views that don't specify exam_id, check if user has any active subscription
            return self._has_any_active_subscription(request.user)
        
        # Check if exam exists
        from exams.models import Exam
        try:
            exam = Exam.objects.get(id=exam_id, is_active=True)
        except Exam.DoesNotExist:
            logger.warning(f"User {request.user.id} tried to access non-existent exam {exam_id}")
            # If the exam doesn't exist, check if user has subscription to any exam
            # This allows them to access their own data even if they're using wrong exam_id
            return self._has_any_active_subscription(request.user)
            
        return self._has_active_subscription_for_exam(request.user, exam_id)
    
    def _get_exam_id(self, request, view):
        """
        Extract exam_id from the request, view, or object
        This handles both GET and POST requests for different views
        """
        # First check if exam_id is in the request data (for POST)
        if request.method == 'POST' and request.data.get('exam_id'):
            return request.data.get('exam_id')
            
        # For detail views, check if the object has an exam_id
        if hasattr(view, 'get_object'):
            try:
                obj = view.get_object()
                if hasattr(obj, 'exam_id'):
                    return obj.exam_id
                # Special case for QuestionDetail view
                if hasattr(obj, 'exam') and hasattr(obj.exam, 'id'):
                    return obj.exam.id
            except:
                pass
                
        # For list views, check for query parameters
        return request.query_params.get('exam_id')
    
    def _has_any_active_subscription(self, user):
        """Check if the user has any active subscription"""
        now = timezone.now()
        
        return UserSubscription.objects.filter(
            user=user,
            status='ACTIVE',
            start_date__lte=now,
            end_date__gte=now
        ).exists()
    
    def _has_active_subscription_for_exam(self, user, exam_id):
        """Check if the user has an active subscription for the given exam"""
        now = timezone.now()
        
        # Find active subscriptions for the user
        active_subscriptions = UserSubscription.objects.filter(
            user=user,
            status='ACTIVE',
            start_date__lte=now,
            end_date__gte=now
        ).select_related('pricing_plan')
        
        # Check if any of the active subscriptions are for the requested exam
        has_subscription = active_subscriptions.filter(
            pricing_plan__exam_id=exam_id
        ).exists()
        
        if not has_subscription:
            # Log for debugging
            user_exam_ids = list(active_subscriptions.values_list('pricing_plan__exam_id', flat=True))
            logger.info(f"User {user.id} tried to access exam {exam_id} but has subscriptions for exams: {user_exam_ids}")
        
        return has_subscription 