from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from django.shortcuts import get_object_or_404
from .models import FAQItem, SupportTicket, TicketReply
from .serializers import (
    FAQItemSerializer,
    AdminSupportTicketSerializer,
    TicketReplySerializer,
    TicketReplyCreateSerializer
)


class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow admin users to access the view.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_staff


class AdminFAQItemViewSet(viewsets.ModelViewSet):
    """ViewSet for managing FAQ items by admin users."""
    queryset = FAQItem.objects.all().order_by('display_order')
    serializer_class = FAQItemSerializer
    permission_classes = [IsAdminUser]
    lookup_field = 'id'
    pagination_class = None  # Disable pagination to return all FAQs
    
    @action(detail=False, methods=['get'])
    def categories(self, request):
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


class AdminSupportTicketViewSet(viewsets.ModelViewSet):
    """ViewSet for managing support tickets by admin users."""
    queryset = SupportTicket.objects.all().order_by('-created_at')
    serializer_class = AdminSupportTicketSerializer
    permission_classes = [IsAdminUser]
    lookup_field = 'id'
    
    def get_queryset(self):
        queryset = SupportTicket.objects.all().order_by('-created_at')
        
        # Filter by status if provided
        status = self.request.query_params.get('status')
        if status:
            queryset = queryset.filter(status=status)
            
        # Filter by ticket_type if provided
        ticket_type = self.request.query_params.get('ticket_type')
        if ticket_type:
            queryset = queryset.filter(ticket_type=ticket_type)
            
        return queryset
    
    @action(detail=True, methods=['post'])
    def reply(self, request, id=None):
        """Add an admin reply to a support ticket."""
        ticket = self.get_object()
        
        serializer = TicketReplyCreateSerializer(data=request.data)
        if serializer.is_valid():
            reply = serializer.save(
                ticket=ticket,
                user=request.user,
                is_staff_reply=True
            )
            return Response(
                TicketReplySerializer(reply).data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=True, methods=['post'])
    def change_status(self, request, id=None):
        """Change the status of a support ticket."""
        ticket = self.get_object()
        
        new_status = request.data.get('status')
        if new_status not in dict(SupportTicket.STATUS_CHOICES):
            return Response(
                {'status': 'Invalid status'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        ticket.status = new_status
        ticket.save()
        
        return Response(
            AdminSupportTicketSerializer(ticket).data,
            status=status.HTTP_200_OK
        )
    
    @action(detail=True, methods=['post'])
    def assign(self, request, id=None):
        """Assign a support ticket to a staff member."""
        ticket = self.get_object()
        
        user_id = request.data.get('user_id')
        if not user_id:
            return Response(
                {'user_id': 'This field is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        from users.models import User
        try:
            user = User.objects.get(id=user_id, is_staff=True)
            ticket.assigned_to = user
            ticket.save()
            return Response(
                AdminSupportTicketSerializer(ticket).data,
                status=status.HTTP_200_OK
            )
        except User.DoesNotExist:
            return Response(
                {'user_id': 'Staff user not found'},
                status=status.HTTP_404_NOT_FOUND
            ) 