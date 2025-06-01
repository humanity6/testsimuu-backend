from rest_framework import generics, status, filters
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from .models import Notification
from .serializers import NotificationSerializer

class NotificationListView(generics.ListAPIView):
    """
    API view to list all notifications for the authenticated user.
    Supports filtering by is_read and notification_type.
    """
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['is_read', 'notification_type']
    ordering_fields = ['created_at']
    ordering = ['-created_at']  # Default ordering: newest first
    
    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class MarkNotificationAsReadView(APIView):
    """
    API view to mark a specific notification as read.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, notification_id):
        try:
            notification = Notification.objects.get(
                id=notification_id, 
                user=request.user
            )
            notification.is_read = True
            notification.save(update_fields=['is_read'])
            
            serializer = NotificationSerializer(notification)
            return Response(serializer.data)
        except Notification.DoesNotExist:
            return Response(
                {"error": "Notification not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )


class MarkAllNotificationsAsReadView(APIView):
    """
    API view to mark all notifications as read for the authenticated user.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        # Update all unread notifications for the user
        updated_count = Notification.objects.filter(
            user=request.user, 
            is_read=False
        ).update(is_read=True)
        
        return Response({
            "message": f"Marked {updated_count} notifications as read",
            "count": updated_count
        }) 