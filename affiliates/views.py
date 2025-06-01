from rest_framework import viewsets, status, permissions, views
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db.models import Sum

from .models import Affiliate, AffiliateLink, VoucherCode, Conversion, AffiliatePayment, ClickEvent, AffiliatePlan, AffiliateApplication
from .serializers import (
    AffiliateSerializer, 
    AffiliateLinkSerializer, 
    VoucherCodeSerializer, 
    ConversionSerializer, 
    AffiliatePaymentSerializer,
    ClickTrackingSerializer,
    VoucherApplySerializer,
    AffiliatePlanSerializer,
    PublicAffiliatePlanSerializer,
    AffiliateApplicationSerializer,
    AffiliateApplicationCreateSerializer
)
from .services import AffiliateTrackingService, AffiliateAnalyticsService, AffiliatePaymentService


class IsAffiliatePermission(permissions.BasePermission):
    """
    Custom permission to only allow affiliates to access views.
    """
    def has_permission(self, request, view):
        return hasattr(request.user, 'affiliate_profile')


class AffiliateProfileView(views.APIView):
    """
    View for retrieving the current user's affiliate profile.
    """
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get(self, request, format=None):
        affiliate = request.user.affiliate_profile
        serializer = AffiliateSerializer(affiliate)
        
        # Enrich with method fields
        data = serializer.data
        data['total_earnings'] = affiliate.total_earnings()
        data['pending_earnings'] = affiliate.pending_earnings()
        
        return Response(data)


class AffiliateLinkViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing affiliate links.
    """
    serializer_class = AffiliateLinkSerializer
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get_queryset(self):
        return AffiliateLink.objects.filter(
            affiliate=self.request.user.affiliate_profile
        ).order_by('-created_at')


class VoucherCodeViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing voucher codes.
    """
    serializer_class = VoucherCodeSerializer
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get_queryset(self):
        return VoucherCode.objects.filter(
            affiliate=self.request.user.affiliate_profile
        ).order_by('-created_at')
        
    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        data = serializer.data
        data['is_valid'] = instance.is_valid()
        return Response(data)


class ConversionViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing conversions.
    """
    serializer_class = ConversionSerializer
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get_queryset(self):
        return Conversion.objects.filter(
            affiliate=self.request.user.affiliate_profile
        ).order_by('-conversion_date')


class AffiliatePaymentViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing affiliate payments.
    """
    serializer_class = AffiliatePaymentSerializer
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get_queryset(self):
        return AffiliatePayment.objects.filter(
            affiliate=self.request.user.affiliate_profile
        ).order_by('-created_at')


class AffiliateStatisticsView(views.APIView):
    """
    View for retrieving affiliate statistics.
    """
    permission_classes = [permissions.IsAuthenticated, IsAffiliatePermission]
    
    def get(self, request, format=None):
        # Get period from query params, default to 30 days
        period_days = int(request.query_params.get('period', 30))
        
        analytics_service = AffiliateAnalyticsService()
        statistics = analytics_service.get_affiliate_dashboard_data(
            affiliate=request.user.affiliate_profile,
            period_days=period_days
        )
        
        return Response(statistics)


class TrackClickView(views.APIView):
    """
    View for tracking clicks on affiliate links.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request, format=None):
        serializer = ClickTrackingSerializer(data=request.data)
        
        if serializer.is_valid():
            tracking_id = serializer.validated_data['tracking_id']
            referrer_url = serializer.validated_data.get('referrer_url')
            
            # Get the affiliate link by tracking ID
            try:
                affiliate_link = AffiliateLink.objects.get(tracking_id=tracking_id)
            except AffiliateLink.DoesNotExist:
                return Response(
                    {"error": "Invalid tracking ID"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Track the click
            tracking_service = AffiliateTrackingService()
            click = tracking_service.track_click(
                affiliate_link=affiliate_link,
                request=request,
                user=request.user if request.user.is_authenticated else None
            )
            
            return Response({"success": True})
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ApplyVoucherView(views.APIView):
    """
    View for applying a voucher code.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, format=None):
        serializer = VoucherApplySerializer(data=request.data)
        
        if serializer.is_valid():
            code = serializer.validated_data['code']
            
            # Find the voucher code
            try:
                voucher = VoucherCode.objects.get(code=code, is_active=True)
            except VoucherCode.DoesNotExist:
                return Response(
                    {"error": "Invalid or inactive voucher code"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if the voucher is valid
            if not voucher.is_valid():
                return Response(
                    {"error": "Voucher code has expired or reached maximum uses"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Return voucher details
            return Response({
                "success": True,
                "voucher": {
                    "code": voucher.code,
                    "code_type": voucher.code_type,
                    "discount_value": voucher.discount_value,
                    "affiliate": voucher.affiliate.name,
                    "minimum_purchase": voucher.minimum_purchase
                }
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AffiliatePlansViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for public access to affiliate plans.
    """
    permission_classes = [permissions.AllowAny]
    serializer_class = PublicAffiliatePlanSerializer
    
    def get_queryset(self):
        return AffiliatePlan.objects.filter(is_active=True).order_by('name')


class AffiliateApplicationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing affiliate applications.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return AffiliateApplication.objects.filter(user=self.request.user).order_by('-created_at')
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AffiliateApplicationCreateSerializer
        return AffiliateApplicationSerializer
    
    def create(self, request, *args, **kwargs):
        # Check if user already has an affiliate profile
        if hasattr(request.user, 'affiliate_profile'):
            return Response(
                {"error": "User already has an affiliate profile"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if user already has a pending application
        if AffiliateApplication.objects.filter(
            user=request.user, 
            status__in=['PENDING', 'UNDER_REVIEW']
        ).exists():
            return Response(
                {"error": "User already has a pending application"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().create(request, *args, **kwargs)


class AffiliateOpportunitiesView(views.APIView):
    """
    View for users to see affiliate opportunities (plans they can apply for).
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, format=None):
        # Check if user is already an affiliate
        is_affiliate = hasattr(request.user, 'affiliate_profile')
        
        # Get available plans
        plans = AffiliatePlan.objects.filter(is_active=True).order_by('name')
        serializer = PublicAffiliatePlanSerializer(plans, many=True)
        
        # Check if user has pending applications
        pending_applications = []
        if not is_affiliate:
            pending_apps = AffiliateApplication.objects.filter(
                user=request.user,
                status__in=['PENDING', 'UNDER_REVIEW']
            )
            pending_applications = AffiliateApplicationSerializer(pending_apps, many=True).data
        
        return Response({
            "is_affiliate": is_affiliate,
            "available_plans": serializer.data,
            "pending_applications": pending_applications,
            "can_apply": not is_affiliate and not pending_applications
        })


class UserAffiliateStatusView(views.APIView):
    """
    View to check if user is an affiliate and get their status.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, format=None):
        user = request.user
        
        # Check if user is an affiliate
        if hasattr(user, 'affiliate_profile'):
            affiliate = user.affiliate_profile
            return Response({
                "is_affiliate": True,
                "affiliate_data": AffiliateSerializer(affiliate).data
            })
        
        # Check for pending applications
        pending_app = AffiliateApplication.objects.filter(
            user=user,
            status__in=['PENDING', 'UNDER_REVIEW']
        ).first()
        
        if pending_app:
            return Response({
                "is_affiliate": False,
                "has_pending_application": True,
                "application": AffiliateApplicationSerializer(pending_app).data
            })
        
        return Response({
            "is_affiliate": False,
            "has_pending_application": False,
            "can_apply": True
        }) 