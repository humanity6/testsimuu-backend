from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from exam_prep_platform.permissions import IsAdminUser
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Count, Q, Avg
from django.utils import timezone
from datetime import timedelta

from .models import (
    AIFeedbackTemplate,
    AIEvaluationLog,
    ChatbotConversation,
    ChatbotMessage,
    AIContentAlert,
    ContentUpdateScanConfig,
    ContentUpdateScanLog
)
from .serializers import (
    AIFeedbackTemplateSerializer,
    AIEvaluationLogSerializer,
    ChatbotConversationSerializer,
    ChatbotMessageSerializer,
    AIContentAlertSerializer,
    ContentUpdateScanConfigSerializer,
    ContentUpdateScanLogSerializer
)


class AdminAIFeedbackTemplateViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing AI feedback templates.
    """
    queryset = AIFeedbackTemplate.objects.all().order_by('-created_at')
    serializer_class = AIFeedbackTemplateSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['question_type', 'is_active']

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Toggle the active status of a feedback template."""
        template = self.get_object()
        template.is_active = not template.is_active
        template.save()
        
        return Response({
            'detail': f'Template "{template.template_name}" is now {"active" if template.is_active else "inactive"}.',
            'is_active': template.is_active
        })

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about AI feedback templates."""
        total_templates = AIFeedbackTemplate.objects.count()
        active_templates = AIFeedbackTemplate.objects.filter(is_active=True).count()
        
        by_question_type = AIFeedbackTemplate.objects.values('question_type').annotate(
            count=Count('id')
        )
        
        return Response({
            'total_templates': total_templates,
            'active_templates': active_templates,
            'inactive_templates': total_templates - active_templates,
            'by_question_type': list(by_question_type)
        })


class AdminAIEvaluationLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Admin ViewSet for viewing AI evaluation logs.
    Read-only as these are system-generated logs.
    """
    queryset = AIEvaluationLog.objects.all().order_by('-created_at')
    serializer_class = AIEvaluationLogSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['success']

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Date range filtering
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(created_at__gte=date_from)
            
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(created_at__lte=date_to)
            
        # Filter by user
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_answer__user_id=user_id)
            
        # Filter by question type
        question_type = self.request.query_params.get('question_type')
        if question_type:
            queryset = queryset.filter(user_answer__question__question_type=question_type)
            
        return queryset

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about AI evaluations."""
        # Get date range for filtering (default to last 30 days)
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30)
        
        date_from = request.query_params.get('date_from')
        if date_from:
            start_date = timezone.datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            
        date_to = request.query_params.get('date_to')
        if date_to:
            end_date = timezone.datetime.fromisoformat(date_to.replace('Z', '+00:00'))

        queryset = self.get_queryset().filter(created_at__range=[start_date, end_date])
        
        total_evaluations = queryset.count()
        successful_evaluations = queryset.filter(success=True).count()
        failed_evaluations = queryset.filter(success=False).count()
        
        # Average processing time for successful evaluations
        avg_processing_time = queryset.filter(success=True).aggregate(
            avg_time=Avg('processing_time_ms')
        )['avg_time'] or 0
        
        # Evaluations by question type
        by_question_type = queryset.values(
            'user_answer__question__question_type'
        ).annotate(
            count=Count('id'),
            success_rate=Count('id', filter=Q(success=True)) * 100.0 / Count('id')
        )
        
        return Response({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'total_evaluations': total_evaluations,
            'successful_evaluations': successful_evaluations,
            'failed_evaluations': failed_evaluations,
            'success_rate': (successful_evaluations / total_evaluations * 100) if total_evaluations > 0 else 0,
            'average_processing_time_ms': round(avg_processing_time, 2),
            'by_question_type': list(by_question_type)
        })


class AdminChatbotConversationViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing chatbot conversations.
    Allows admins to view, moderate, and manage chatbot conversations.
    """
    queryset = ChatbotConversation.objects.all().order_by('-updated_at')
    serializer_class = ChatbotConversationSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_active']

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter by user
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
            
        # Date range filtering
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(created_at__gte=date_from)
            
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(created_at__lte=date_to)
            
        return queryset

    @action(detail=True, methods=['post'])
    def deactivate(self, request, pk=None):
        """Deactivate a conversation (admin moderation)."""
        conversation = self.get_object()
        conversation.is_active = False
        conversation.save()
        
        return Response({
            'detail': f'Conversation {conversation.id} has been deactivated.'
        })

    @action(detail=True, methods=['post'])
    def reactivate(self, request, pk=None):
        """Reactivate a conversation."""
        conversation = self.get_object()
        conversation.is_active = True
        conversation.save()
        
        return Response({
            'detail': f'Conversation {conversation.id} has been reactivated.'
        })

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about chatbot conversations."""
        # Get date range for filtering (default to last 30 days)
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30)
        
        date_from = request.query_params.get('date_from')
        if date_from:
            start_date = timezone.datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            
        date_to = request.query_params.get('date_to')
        if date_to:
            end_date = timezone.datetime.fromisoformat(date_to.replace('Z', '+00:00'))

        queryset = self.get_queryset().filter(created_at__range=[start_date, end_date])
        
        total_conversations = queryset.count()
        active_conversations = queryset.filter(is_active=True).count()
        
        # Average messages per conversation
        avg_messages = queryset.annotate(
            message_count=Count('messages')
        ).aggregate(
            avg_messages=Avg('message_count')
        )['avg_messages'] or 0
        
        # Most active users
        top_users = queryset.values(
            'user__username', 'user__id'
        ).annotate(
            conversation_count=Count('id')
        ).order_by('-conversation_count')[:10]
        
        return Response({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'total_conversations': total_conversations,
            'active_conversations': active_conversations,
            'inactive_conversations': total_conversations - active_conversations,
            'average_messages_per_conversation': round(avg_messages, 2),
            'top_users': list(top_users)
        })


class AdminChatbotMessageViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Admin ViewSet for viewing chatbot messages.
    Read-only for moderation and analysis purposes.
    """
    queryset = ChatbotMessage.objects.all().order_by('-created_at')
    serializer_class = ChatbotMessageSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['role', 'conversation']

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter by conversation user
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(conversation__user_id=user_id)
            
        # Date range filtering
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(created_at__gte=date_from)
            
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(created_at__lte=date_to)
            
        # Filter by processing time (for performance analysis)
        min_processing_time = self.request.query_params.get('min_processing_time')
        if min_processing_time:
            queryset = queryset.filter(processing_time_ms__gte=min_processing_time)
            
        return queryset

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about chatbot messages."""
        # Get date range for filtering (default to last 30 days)
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30)
        
        date_from = request.query_params.get('date_from')
        if date_from:
            start_date = timezone.datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            
        date_to = request.query_params.get('date_to')
        if date_to:
            end_date = timezone.datetime.fromisoformat(date_to.replace('Z', '+00:00'))

        queryset = self.get_queryset().filter(created_at__range=[start_date, end_date])
        
        total_messages = queryset.count()
        user_messages = queryset.filter(role='USER').count()
        assistant_messages = queryset.filter(role='ASSISTANT').count()
        
        # Average processing time for assistant messages
        avg_processing_time = queryset.filter(
            role='ASSISTANT', 
            processing_time_ms__isnull=False
        ).aggregate(
            avg_time=Avg('processing_time_ms')
        )['avg_time'] or 0
        
        # Messages by role
        by_role = queryset.values('role').annotate(
            count=Count('id')
        )
        
        return Response({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'total_messages': total_messages,
            'user_messages': user_messages,
            'assistant_messages': assistant_messages,
            'average_processing_time_ms': round(avg_processing_time, 2),
            'by_role': list(by_role)
        })


class AdminAIContentAlertViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing AI content alerts.
    Allows admins to view, update status, and manage content alerts.
    """
    queryset = AIContentAlert.objects.all().order_by('-created_at')
    serializer_class = AIContentAlertSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['alert_type', 'priority', 'status']

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter by related topic
        topic_id = self.request.query_params.get('topic_id')
        if topic_id:
            queryset = queryset.filter(related_topic_id=topic_id)
        
        # Filter by related question
        question_id = self.request.query_params.get('question_id')
        if question_id:
            queryset = queryset.filter(related_question_id=question_id)
            
        # Date range filtering
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(created_at__gte=date_from)
            
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(created_at__lte=date_to)
            
        return queryset

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        """Update the status of an alert."""
        alert = self.get_object()
        new_status = request.data.get('status')
        
        if new_status not in dict(AIContentAlert.STATUS_CHOICES):
            return Response(
                {'error': 'Invalid status'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        alert.status = new_status
        if new_status in ['UNDER_REVIEW', 'ACTION_TAKEN', 'DISMISSED']:
            alert.reviewed_by_admin = request.user
            alert.reviewed_at = timezone.now()
        
        admin_notes = request.data.get('admin_notes')
        if admin_notes:
            alert.admin_notes = admin_notes
            
        action_taken = request.data.get('action_taken')
        if action_taken:
            alert.action_taken = action_taken
            
        alert.save()
        
        return Response({
            'detail': f'Alert status updated to {new_status}',
            'status': alert.status
        })

    @action(detail=False, methods=['post'])
    def bulk_update_status(self, request):
        """Bulk update status for multiple alerts."""
        alert_ids = request.data.get('alert_ids', [])
        new_status = request.data.get('status')
        
        if not alert_ids:
            return Response(
                {'error': 'No alert IDs provided'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if new_status not in dict(AIContentAlert.STATUS_CHOICES):
            return Response(
                {'error': 'Invalid status'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        alerts = AIContentAlert.objects.filter(id__in=alert_ids)
        
        for alert in alerts:
            alert.status = new_status
            if new_status in ['UNDER_REVIEW', 'ACTION_TAKEN', 'DISMISSED']:
                alert.reviewed_by_admin = request.user
                alert.reviewed_at = timezone.now()
        
        AIContentAlert.objects.bulk_update(
            alerts, 
            ['status', 'reviewed_by_admin', 'reviewed_at']
        )
        
        return Response({
            'detail': f'Updated {len(alerts)} alerts to status {new_status}',
            'updated_count': len(alerts)
        })

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about AI content alerts."""
        # Get date range for filtering (default to last 30 days)
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30)
        
        date_from = request.query_params.get('date_from')
        if date_from:
            start_date = timezone.datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            
        date_to = request.query_params.get('date_to')
        if date_to:
            end_date = timezone.datetime.fromisoformat(date_to.replace('Z', '+00:00'))

        queryset = self.get_queryset().filter(created_at__range=[start_date, end_date])
        
        total_alerts = queryset.count()
        
        # Alerts by status
        by_status = queryset.values('status').annotate(
            count=Count('id')
        )
        
        # Alerts by priority
        by_priority = queryset.values('priority').annotate(
            count=Count('id')
        )
        
        # Alerts by type
        by_type = queryset.values('alert_type').annotate(
            count=Count('id')
        )
        
        # Average confidence score
        avg_confidence = queryset.aggregate(
            avg_confidence=Avg('ai_confidence_score')
        )['avg_confidence'] or 0
        
        return Response({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'total_alerts': total_alerts,
            'average_confidence_score': round(avg_confidence, 2),
            'by_status': list(by_status),
            'by_priority': list(by_priority),
            'by_type': list(by_type)
        })


class AdminContentUpdateScanConfigViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing content update scan configurations.
    """
    queryset = ContentUpdateScanConfig.objects.all().order_by('-created_at')
    serializer_class = ContentUpdateScanConfigSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['frequency', 'is_active']
    
    def perform_create(self, serializer):
        # Set created_by to current user
        serializer.save(created_by=self.request.user)
    
    @action(detail=True, methods=['post'])
    def run_scan(self, request, pk=None):
        """Trigger a content update scan for this configuration."""
        from .tasks import run_content_update_scan
        
        scan_config = self.get_object()
        
        if not scan_config.is_active:
            return Response(
                {'error': 'Cannot run scan for inactive configuration'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Queue the scan task
        task = run_content_update_scan.delay(scan_config.id)
        
        # Update last_run time
        scan_config.last_run = timezone.now()
        scan_config.save(update_fields=['last_run'])
        
        return Response(
            {
                "detail": f"Content update scan has been queued for '{scan_config.name}'.",
                "task_id": task.id
            },
            status=status.HTTP_202_ACCEPTED
        )

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Toggle the active status of a scan configuration."""
        scan_config = self.get_object()
        scan_config.is_active = not scan_config.is_active
        scan_config.save()
        
        return Response({
            'detail': f'Scan configuration "{scan_config.name}" is now {"active" if scan_config.is_active else "inactive"}.',
            'is_active': scan_config.is_active
        })

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about scan configurations."""
        total_configs = ContentUpdateScanConfig.objects.count()
        active_configs = ContentUpdateScanConfig.objects.filter(is_active=True).count()
        
        # Configs by frequency
        by_frequency = ContentUpdateScanConfig.objects.values('frequency').annotate(
            count=Count('id')
        )
        
        # Recent scans (last 7 days)
        last_week = timezone.now() - timedelta(days=7)
        recent_scans = ContentUpdateScanLog.objects.filter(
            start_time__gte=last_week
        ).count()
        
        # Success rate for recent scans
        recent_successful = ContentUpdateScanLog.objects.filter(
            start_time__gte=last_week,
            status='COMPLETED'
        ).count()
        
        success_rate = (recent_successful / recent_scans * 100) if recent_scans > 0 else 0
        
        return Response({
            'total_configs': total_configs,
            'active_configs': active_configs,
            'inactive_configs': total_configs - active_configs,
            'by_frequency': list(by_frequency),
            'recent_scans_count': recent_scans,
            'success_rate_percent': round(success_rate, 2)
        })


class AdminContentUpdateScanLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Admin ViewSet for viewing content update scan logs.
    """
    queryset = ContentUpdateScanLog.objects.all().order_by('-start_time')
    serializer_class = ContentUpdateScanLogSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status', 'scan_config']

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Date range filtering
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(start_time__gte=date_from)
            
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(start_time__lte=date_to)
            
        return queryset

    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get metrics about scan logs."""
        # Get date range for filtering (default to last 30 days)
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30)
        
        date_from = request.query_params.get('date_from')
        if date_from:
            start_date = timezone.datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            
        date_to = request.query_params.get('date_to')
        if date_to:
            end_date = timezone.datetime.fromisoformat(date_to.replace('Z', '+00:00'))

        queryset = self.get_queryset().filter(start_time__range=[start_date, end_date])
        
        total_scans = queryset.count()
        completed_scans = queryset.filter(status='COMPLETED').count()
        failed_scans = queryset.filter(status='FAILED').count()
        
        # Average alerts generated per scan
        avg_alerts = queryset.aggregate(
            avg_alerts=Avg('alerts_generated')
        )['avg_alerts'] or 0
        
        # Average questions scanned per scan
        avg_questions = queryset.aggregate(
            avg_questions=Avg('questions_scanned')
        )['avg_questions'] or 0
        
        return Response({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'total_scans': total_scans,
            'completed_scans': completed_scans,
            'failed_scans': failed_scans,
            'success_rate': (completed_scans / total_scans * 100) if total_scans > 0 else 0,
            'average_alerts_per_scan': round(avg_alerts, 2),
            'average_questions_per_scan': round(avg_questions, 2)
        }) 