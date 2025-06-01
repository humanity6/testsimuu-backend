from rest_framework import generics, status, filters
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.decorators import api_view, permission_classes
from django_filters.rest_framework import DjangoFilterBackend
from django.shortcuts import get_object_or_404
from django.db.models import F
from .models import FAQItem, SupportTicket, TicketReply
from .serializers import (
    FAQItemSerializer,
    SupportTicketSerializer,
    SupportTicketDetailSerializer,
    SupportTicketCreateSerializer,
    TicketReplyCreateSerializer
)


class FAQItemListView(generics.ListAPIView):
    """List published FAQ items with filtering and ordering."""
    serializer_class = FAQItemSerializer
    permission_classes = [AllowAny]  # Allow anonymous access to FAQ items
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['category']
    
    def get_queryset(self):
        return FAQItem.objects.filter(is_published=True).order_by('display_order')


class FAQItemDetailView(generics.RetrieveAPIView):
    """Retrieve a specific FAQ item and increment view count."""
    serializer_class = FAQItemSerializer
    permission_classes = [AllowAny]  # Allow anonymous access to FAQ item details
    queryset = FAQItem.objects.filter(is_published=True)
    lookup_field = 'id'
    
    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # Increment the view_count
        FAQItem.objects.filter(id=instance.id).update(view_count=F('view_count') + 1)
        # Refresh the instance to get updated view_count
        instance.refresh_from_db()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)


class SupportTicketListView(generics.ListAPIView):
    """List current user's support tickets with filtering and ordering."""
    serializer_class = SupportTicketSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']
    
    def get_queryset(self):
        return SupportTicket.objects.filter(
            user=self.request.user
        ).order_by('-created_at')


class SupportTicketCreateView(generics.CreateAPIView):
    """Create a new support ticket."""
    serializer_class = SupportTicketCreateSerializer
    permission_classes = [IsAuthenticated]
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class SupportTicketDetailView(generics.RetrieveAPIView):
    """Retrieve a specific support ticket and its replies."""
    serializer_class = SupportTicketDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'
    
    def get_queryset(self):
        return SupportTicket.objects.filter(user=self.request.user)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_ticket_reply(request, id):
    """Add a reply to a support ticket."""
    ticket = get_object_or_404(SupportTicket, id=id, user=request.user)
    
    serializer = TicketReplyCreateSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save(
            ticket=ticket,
            user=request.user,
            is_staff_reply=False
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST) 