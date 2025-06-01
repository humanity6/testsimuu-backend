from rest_framework import generics, permissions, viewsets, filters, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import action
from django.utils import timezone
from datetime import timedelta
from django.db.models import Count, Q
from django_filters.rest_framework import DjangoFilterBackend
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.core.mail import send_mail
from django.conf import settings
from .models import User
from .serializers import UserSerializer
from drf_spectacular.utils import extend_schema, extend_schema_view, OpenApiParameter, OpenApiResponse, OpenApiExample
from support.models import FAQItem

class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            print(f"❌ Admin permission denied: User not authenticated")
            return False
            
        # Force a fresh database lookup to ensure we have latest is_staff status
        try:
            fresh_user = User.objects.get(id=request.user.id)
            has_permission = fresh_user.is_staff
            print(f"🔍 Admin permission check: user={fresh_user.email}, is_staff={fresh_user.is_staff}, result={has_permission}")
            return has_permission
        except User.DoesNotExist:
            print(f"❌ Admin permission denied: User not found in database")
            return False

@extend_schema(
    tags=['Admin: Users'],
    summary="User metrics",
    description="Get metrics about user registrations and activity",
    responses={
        200: OpenApiResponse(
            description="User metrics retrieved successfully",
            examples=[
                OpenApiExample(
                    'Success Response',
                    value={
                        'total_users': 1250,
                        'active_users': 843,
                        'new_users_this_month': 125,
                        'verified_users': 980,
                        'staff_users': 12
                    }
                )
            ]
        ),
        401: OpenApiResponse(description="Authentication credentials were not provided"),
        403: OpenApiResponse(description="Not authorized to access this resource")
    }
)
class UserMetricsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]

    def get(self, request):
        print(f"🔍 UserMetricsView: Authenticated user: {request.user.email}")
        print(f"🔍 UserMetricsView: User is_staff: {request.user.is_staff}")
        
        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)
        thirty_days_ago = now - timedelta(days=30)

        # Get user metrics - Updated to match API documentation
        total_users = User.objects.count()
        active_users = User.objects.filter(last_active__gte=seven_days_ago).count()
        new_users_this_month = User.objects.filter(date_joined__gte=thirty_days_ago).count()
        verified_users = User.objects.filter(email_verified=True).count()
        staff_users = User.objects.filter(is_staff=True).count()

        metrics = {
            'total_users': total_users,
            'active_users': active_users,
            'new_users_this_month': new_users_this_month,
            'verified_users': verified_users,
            'staff_users': staff_users,
        }
        
        print(f"✅ UserMetricsView: Returning metrics: {metrics}")
        return Response(metrics)

@extend_schema_view(
    list=extend_schema(
        tags=['Admin: Users'],
        summary="List users",
        description="Get a paginated list of all users with filtering and search capabilities",
        parameters=[
            OpenApiParameter(name="is_active", description="Filter by active status", type=bool),
            OpenApiParameter(name="is_staff", description="Filter by staff status", type=bool),
            OpenApiParameter(name="email_verified", description="Filter by email verification status", type=bool),
            OpenApiParameter(name="search", description="Search in username, email, first and last name", type=str),
            OpenApiParameter(name="ordering", description="Order by field (prefix with - for descending)", type=str),
        ],
        responses={
            200: UserSerializer(many=True),
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource")
        }
    ),
    retrieve=extend_schema(
        tags=['Admin: Users'],
        summary="Get user details",
        description="Retrieve detailed information about a specific user by ID",
        responses={
            200: UserSerializer,
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource"),
            404: OpenApiResponse(description="User not found")
        }
    ),
    create=extend_schema(
        tags=['Admin: Users'],
        summary="Create user",
        description="Create a new user account with admin privileges",
        responses={
            201: UserSerializer,
            400: OpenApiResponse(description="Invalid input data"),
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource")
        }
    ),
    update=extend_schema(
        tags=['Admin: Users'],
        summary="Update user",
        description="Update all fields of an existing user",
        responses={
            200: UserSerializer,
            400: OpenApiResponse(description="Invalid input data"),
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource"),
            404: OpenApiResponse(description="User not found")
        }
    ),
    partial_update=extend_schema(
        tags=['Admin: Users'],
        summary="Partial update user",
        description="Update selected fields of an existing user",
        responses={
            200: UserSerializer,
            400: OpenApiResponse(description="Invalid input data"),
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource"),
            404: OpenApiResponse(description="User not found")
        }
    ),
    destroy=extend_schema(
        tags=['Admin: Users'],
        summary="Delete user",
        description="Delete a user account permanently",
        responses={
            204: OpenApiResponse(description="User deleted successfully"),
            401: OpenApiResponse(description="Authentication credentials were not provided"),
            403: OpenApiResponse(description="Not authorized to access this resource"),
            404: OpenApiResponse(description="User not found")
        }
    ),
)
class UserAdminViewSet(viewsets.ModelViewSet):
    """
    Admin ViewSet for managing users with filtering, search, and sorting
    """
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = User.objects.all()
    serializer_class = UserSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    
    # Define filterable fields
    filterset_fields = {
        'is_active': ['exact'],
        'is_staff': ['exact'], 
        'email_verified': ['exact'],
        'is_superuser': ['exact'],
        'date_joined': ['gte', 'lte', 'date'],
        'last_active': ['gte', 'lte', 'date'],
    }
    
    # Define searchable fields
    search_fields = ['username', 'email', 'first_name', 'last_name']
    
    # Define orderable fields
    ordering_fields = ['date_joined', 'last_active', 'first_name', 'last_name', 'email', 'username']
    ordering = ['-date_joined']  # Default ordering
    
    def get_queryset(self):
        """
        Override to add custom filtering logic
        """
        queryset = super().get_queryset()
        
        # Handle boolean parameter strings correctly
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            if is_active.lower() in ['true', '1']:
                queryset = queryset.filter(is_active=True)
            elif is_active.lower() in ['false', '0']:
                queryset = queryset.filter(is_active=False)
        
        is_staff = self.request.query_params.get('is_staff')
        if is_staff is not None:
            if is_staff.lower() in ['true', '1']:
                queryset = queryset.filter(is_staff=True)
            elif is_staff.lower() in ['false', '0']:
                queryset = queryset.filter(is_staff=False)
        
        email_verified = self.request.query_params.get('email_verified')
        if email_verified is not None:
            if email_verified.lower() in ['true', '1']:
                queryset = queryset.filter(email_verified=True)
            elif email_verified.lower() in ['false', '0']:
                queryset = queryset.filter(email_verified=False)
        
        return queryset
    
    @extend_schema(
        tags=['Admin: Users'],
        summary="User metrics",
        description="Get metrics about user registrations and activity",
        responses={
            200: OpenApiResponse(
                description="User metrics retrieved successfully",
                examples=[
                    OpenApiExample(
                        'Success Response',
                        value={
                            'total_users': 1250,
                            'active_users': 843,
                            'new_users_this_month': 125,
                            'verified_users': 980,
                            'staff_users': 12
                        }
                    )
                ]
            )
        }
    )
    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """
        Return user metrics
        """
        return UserMetricsView().get(request)
    
    @extend_schema(
        tags=['Admin: Users'],
        summary="Suspend or unsuspend user",
        description="Toggle a user's active status to suspend or unsuspend their account",
        responses={
            200: OpenApiResponse(
                description="User suspension status toggled successfully",
                examples=[
                    OpenApiExample(
                        'Success Response',
                        value={
                            'message': 'User user@example.com has been suspended',
                            'is_active': False
                        }
                    )
                ]
            ),
            400: OpenApiResponse(description="Cannot suspend yourself"),
            403: OpenApiResponse(description="Cannot suspend a superuser"),
            404: OpenApiResponse(description="User not found")
        }
    )
    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        """
        Suspend or unsuspend a user
        """
        user = self.get_object()
        
        # Prevent admin from suspending themselves
        if user.id == request.user.id:
            return Response(
                {'error': 'You cannot suspend yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Prevent suspending superusers unless the requester is also a superuser
        if user.is_superuser and not request.user.is_superuser:
            return Response(
                {'error': 'You cannot suspend a superuser'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Toggle the user's active status
        user.is_active = not user.is_active
        user.save()
        
        action_taken = 'suspended' if not user.is_active else 'unsuspended'
        
        return Response({
            'message': f'User {user.email} has been {action_taken}',
            'is_active': user.is_active
        })
    
    @extend_schema(
        tags=['Admin: Users'],
        summary="Reset user password",
        description="Send a password reset email to the user with a reset link",
        responses={
            200: OpenApiResponse(
                description="Password reset email sent successfully",
                examples=[
                    OpenApiExample(
                        'Success Response',
                        value={
                            'message': 'Password reset email sent to user@example.com',
                            'reset_url': 'http://example.com/reset-password/confirm/abc123/xyz789/'
                        }
                    )
                ]
            ),
            404: OpenApiResponse(description="User not found"),
            500: OpenApiResponse(description="Failed to send password reset email")
        }
    )
    @action(detail=True, methods=['post'])
    def reset_password(self, request, pk=None):
        """
        Generate a password reset token and send reset email to user
        """
        user = self.get_object()
        
        try:
            # Generate password reset token
            token = default_token_generator.make_token(user)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            
            # Create reset URL (you may need to adjust this based on your frontend routing)
            reset_url = f"{settings.FRONTEND_URL}/reset-password/confirm/{uid}/{token}/"
            
            # Send email
            subject = 'Password Reset Request - Testimus'
            message = f"""
Hello {user.first_name or user.username},

An administrator has initiated a password reset for your account.

Please click the following link to reset your password:
{reset_url}

If you did not request this password reset, please ignore this email.

Best regards,
The Testimus Team
            """
            
            send_mail(
                subject,
                message,
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
            
            return Response({
                'message': f'Password reset email sent to {user.email}',
                'reset_url': reset_url  # Include for testing purposes
            })
            
        except Exception as e:
            return Response(
                {'error': f'Failed to send password reset email: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

@extend_schema(
    tags=['Admin: Users'],
    summary="List users (legacy)",
    description="Legacy endpoint for listing users. Use /api/v1/admin/users/ instead.",
    parameters=[
        OpenApiParameter(name="is_active", description="Filter by active status", type=bool),
        OpenApiParameter(name="is_staff", description="Filter by staff status", type=bool),
        OpenApiParameter(name="email_verified", description="Filter by email verification status", type=bool),
        OpenApiParameter(name="search", description="Search in username, email, first and last name", type=str),
        OpenApiParameter(name="ordering", description="Order by field (prefix with - for descending)", type=str),
    ],
    responses={
        200: UserSerializer(many=True),
        401: OpenApiResponse(description="Authentication credentials were not provided"),
        403: OpenApiResponse(description="Not authorized to access this resource")
    }
)
# Keep backward compatibility with existing URL patterns
class UserListView(generics.ListCreateAPIView):
    """
    Legacy view for backward compatibility - redirects to ViewSet
    """
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = User.objects.all()
    serializer_class = UserSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'is_staff', 'email_verified']
    search_fields = ['username', 'email', 'first_name', 'last_name']
    ordering_fields = ['date_joined', 'last_active', 'first_name', 'last_name', 'email']
    ordering = ['-date_joined']
    
    def get_queryset(self):
        """
        Override to add custom filtering logic
        """
        queryset = super().get_queryset()
        
        # Handle boolean parameter strings correctly
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            if is_active.lower() in ['true', '1']:
                queryset = queryset.filter(is_active=True)
            elif is_active.lower() in ['false', '0']:
                queryset = queryset.filter(is_active=False)
        
        is_staff = self.request.query_params.get('is_staff')
        if is_staff is not None:
            if is_staff.lower() in ['true', '1']:
                queryset = queryset.filter(is_staff=True)
            elif is_staff.lower() in ['false', '0']:
                queryset = queryset.filter(is_staff=False)
        
        email_verified = self.request.query_params.get('email_verified')
        if email_verified is not None:
            if email_verified.lower() in ['true', '1']:
                queryset = queryset.filter(email_verified=True)
            elif email_verified.lower() in ['false', '0']:
                queryset = queryset.filter(email_verified=False)
        
        return queryset

class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = User.objects.all()
    serializer_class = UserSerializer 


@extend_schema(
    tags=['Admin: Settings'],
    summary="System settings",
    description="Get and update system settings",
)
class SystemSettingsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    
    def get(self, request):
        """Get current system settings"""
        # Default settings that can be customized
        default_settings = {
            'ai_search_frequency': 'daily',
            'ai_content_monitoring': True,
            'ai_alert_threshold': 75,
            'auto_backup': True,
            'backup_frequency': 'daily',
            'maintenance_mode': False,
            'user_registration_enabled': True,
            'email_notifications': True,
            'max_upload_size': 10,  # MB
            'session_timeout': 30,  # minutes
        }
        
        # In a real implementation, you would load these from database
        # For now, return defaults
        return Response(default_settings)
    
    def put(self, request):
        """Update system settings"""
        settings_data = request.data
        
        # Here you would validate and save to database
        # For now, just return success
        return Response({'message': 'Settings updated successfully'})


@extend_schema(
    tags=['Admin: Support'],
    summary="FAQ categories",
    description="Get FAQ categories for content management",
)
class FAQCategoriesView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    
    def get(self, request):
        """Get FAQ categories dynamically from database"""
        # Get unique categories from existing FAQs
        categories_from_db = FAQItem.objects.values_list('category', flat=True).distinct().order_by('category')
        
        # Convert to the expected format with sequential IDs
        categories = []
        for index, category_name in enumerate(categories_from_db, 1):
            # Clean up category name for display
            display_name = category_name.strip()
            if display_name:  # Only include non-empty categories
                # Format display name properly (title case)
                if display_name.lower() in ['api usage', 'affiliate program']:
                    display_name = display_name.title()
                elif display_name.isdigit():
                    # Skip numeric categories (seems to be data corruption)
                    continue
                else:
                    display_name = display_name.capitalize()
                
                categories.append({
                    'id': index,
                    'name': display_name,
                    'value': category_name,  # Original value for backend operations
                    'description': f'{display_name} related questions',
                    'count': FAQItem.objects.filter(category=category_name).count()
                })
        
        return Response(categories) 