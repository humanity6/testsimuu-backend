from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from django.db.models import Count, Q
from django.utils import timezone
from datetime import timedelta
from .models import Exam
from .admin_serializers import AdminExamSerializer


class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow admin users to access the view.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            print(f"❌ Exams Admin permission denied: User not authenticated")
            return False
            
        # Force a fresh database lookup to ensure we have latest is_staff status
        try:
            from users.models import User
            fresh_user = User.objects.get(id=request.user.id)
            has_permission = fresh_user.is_staff
            print(f"🔍 Exams Admin permission check: user={fresh_user.email}, is_staff={fresh_user.is_staff}, result={has_permission}")
            return has_permission
        except User.DoesNotExist:
            print(f"❌ Exams Admin permission denied: User not found in database")
            return False


class AdminExamViewSet(viewsets.ModelViewSet):
    queryset = Exam.objects.all()
    serializer_class = AdminExamSerializer
    permission_classes = [IsAdminUser]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter by parent exam if specified
        parent_exam_id = self.request.query_params.get('parent_exam_id')
        if parent_exam_id:
            queryset = queryset.filter(parent_exam_id=parent_exam_id)
        
        # Filter by active status if specified
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            is_active_bool = is_active.lower() == 'true'
            queryset = queryset.filter(is_active=is_active_bool)
        
        # Search by name or description
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) | 
                Q(description__icontains=search)
            )
        
        return queryset.order_by('display_order', 'name')
    
    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get exam metrics."""
        print(f"🔍 ExamMetricsAction: Authenticated user: {request.user.email}")
        print(f"🔍 ExamMetricsAction: User is_staff: {request.user.is_staff}")
        
        # Get exam metrics
        total_exams = Exam.objects.count()
        active_exams = Exam.objects.filter(is_active=True).count()
        inactive_exams = total_exams - active_exams
        
        # Get exams with questions
        exams_with_questions = Exam.objects.filter(questions__isnull=False).distinct().count()
        empty_exams = total_exams - exams_with_questions
        
        # Get question count per exam
        question_counts = Exam.objects.annotate(
            question_count=Count('questions')
        ).values_list('question_count', flat=True)
        
        avg_questions_per_exam = sum(question_counts) / len(question_counts) if question_counts else 0
        
        metrics = {
            'total_exams': total_exams,
            'active_exams': active_exams,
            'inactive_exams': inactive_exams,
            'exams_with_questions': exams_with_questions,
            'empty_exams': empty_exams,
            'avg_questions_per_exam': round(avg_questions_per_exam, 2),
        }
        
        print(f"✅ ExamMetricsAction: Returning metrics: {metrics}")
        return Response(metrics) 