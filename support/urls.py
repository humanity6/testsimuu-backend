from django.urls import path
from .views import (
    FAQItemListView,
    FAQItemDetailView,
    SupportTicketListView,
    SupportTicketCreateView,
    SupportTicketDetailView,
    create_ticket_reply
)

urlpatterns = [
    # FAQ Item endpoints
    path('faq-items/', FAQItemListView.as_view(), name='faq-item-list'),
    path('faq-items/<int:id>/', FAQItemDetailView.as_view(), name='faq-item-detail'),
    
    # Support Ticket endpoints
    path('support/tickets/', SupportTicketListView.as_view(), name='support-ticket-list'),
    path('support/tickets/create/', SupportTicketCreateView.as_view(), name='support-ticket-create'),
    path('support/tickets/<int:id>/', SupportTicketDetailView.as_view(), name='support-ticket-detail'),
    path('support/tickets/<int:id>/replies/', create_ticket_reply, name='support-ticket-reply-create'),
] 