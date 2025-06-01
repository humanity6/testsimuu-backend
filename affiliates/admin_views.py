from rest_framework import viewsets, status, permissions, views
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta

from .models import Affiliate, AffiliateApplication, AffiliatePlan, Conversion
from .serializers import (
    AffiliateSerializer, 
    AffiliateApplicationSerializer,
    AffiliatePlanSerializer
)


class IsAdminPermission(permissions.BasePermission):
    """
    Custom permission to only allow admin users to access views.
    """
    def has_permission(self, request, view):
        return request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser)


class AdminAffiliateApplicationViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing affiliate applications.
    """
    serializer_class = AffiliateApplicationSerializer
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        queryset = AffiliateApplication.objects.all().order_by('-created_at')
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Search functionality
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(user__email__icontains=search) |
                Q(business_name__icontains=search) |
                Q(website_url__icontains=search)
            )
        
        return queryset
    
    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve an affiliate application."""
        application = self.get_object()
        
        if application.status != 'PENDING':
            return Response(
                {'error': 'Only pending applications can be approved'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create affiliate from application
        affiliate = Affiliate.objects.create(
            user=application.user,
            name=application.business_name or application.user.get_full_name() or application.user.username,
            email=application.user.email,
            website=application.website_url,
            affiliate_plan=application.requested_plan,
            is_active=True
        )
        
        # Update application status
        application.status = 'APPROVED'
        application.reviewed_by = request.user
        application.reviewed_at = timezone.now()
        application.admin_notes = request.data.get('admin_notes', '')
        application.save()
        
        return Response({
            'message': 'Application approved successfully',
            'affiliate_id': affiliate.id
        })
    
    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject an affiliate application."""
        application = self.get_object()
        
        if application.status != 'PENDING':
            return Response(
                {'error': 'Only pending applications can be rejected'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Update application status
        application.status = 'REJECTED'
        application.reviewed_by = request.user
        application.reviewed_at = timezone.now()
        application.admin_notes = request.data.get('admin_notes', '')
        application.save()
        
        return Response({'message': 'Application rejected successfully'})


class AdminAffiliateViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing affiliates.
    """
    serializer_class = AffiliateSerializer
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        queryset = Affiliate.objects.all().order_by('-created_at')
        
        # Filter by active status
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Search functionality
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) |
                Q(email__icontains=search) |
                Q(user__email__icontains=search)
            )
        
        return queryset


class AdminAffiliatePlanViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing affiliate plans.
    """
    serializer_class = AffiliatePlanSerializer
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        queryset = AffiliatePlan.objects.all().order_by('-created_at')
        
        # Filter by active status
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        return queryset


class AdminAffiliateAnalyticsView(views.APIView):
    """
    Admin view for affiliate analytics and statistics.
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, format=None):
        # Get basic counts
        total_affiliates = Affiliate.objects.count()
        active_affiliates = Affiliate.objects.filter(is_active=True).count()
        pending_applications = AffiliateApplication.objects.filter(status='PENDING').count()
        
        # Get conversion stats
        total_conversions = Conversion.objects.count()
        total_earnings = Conversion.objects.aggregate(
            total=Sum('commission_amount')
        )['total'] or 0
        
        # Get monthly stats for the last 12 months
        monthly_stats = []
        for i in range(12):
            month_start = timezone.now().replace(day=1) - timedelta(days=30 * i)
            month_end = month_start + timedelta(days=30)
            
            month_conversions = Conversion.objects.filter(
                conversion_date__gte=month_start,
                conversion_date__lt=month_end
            ).count()
            
            month_earnings = Conversion.objects.filter(
                conversion_date__gte=month_start,
                conversion_date__lt=month_end
            ).aggregate(total=Sum('commission_amount'))['total'] or 0
            
            monthly_stats.append({
                'month': month_start.strftime('%Y-%m'),
                'conversions': month_conversions,
                'earnings': float(month_earnings)
            })
        
        return Response({
            'total_affiliates': total_affiliates,
            'active_affiliates': active_affiliates,
            'pending_applications': pending_applications,
            'total_conversions': total_conversions,
            'total_earnings': float(total_earnings),
            'monthly_stats': monthly_stats
        }) 