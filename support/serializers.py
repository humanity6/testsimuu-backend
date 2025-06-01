from rest_framework import serializers
from .models import FAQItem, SupportTicket, TicketReply


class FAQItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FAQItem
        fields = ['id', 'question_text', 'answer_text', 'category', 'display_order',
                  'created_at', 'updated_at', 'view_count']
        read_only_fields = ['id', 'created_at', 'updated_at', 'view_count']


class TicketReplySerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    
    class Meta:
        model = TicketReply
        fields = ['id', 'message', 'is_staff_reply', 'created_at', 'user_name']
        read_only_fields = ['id', 'is_staff_reply', 'created_at', 'user_name']
    
    def get_user_name(self, obj):
        if obj.user:
            return obj.user.username
        return "System"


class TicketReplyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = TicketReply
        fields = ['message']


class SupportTicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = ['id', 'subject', 'description', 'ticket_type', 'status',
                  'priority', 'created_at', 'updated_at', 'resolved_at']
        read_only_fields = ['id', 'status', 'priority', 'created_at', 'updated_at', 'resolved_at']


class SupportTicketDetailSerializer(serializers.ModelSerializer):
    replies = TicketReplySerializer(many=True, read_only=True)
    
    class Meta:
        model = SupportTicket
        fields = ['id', 'subject', 'description', 'ticket_type', 'status',
                  'priority', 'created_at', 'updated_at', 'resolved_at', 'replies']
        read_only_fields = ['id', 'status', 'priority', 'created_at', 'updated_at', 'resolved_at']


class SupportTicketCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = ['subject', 'description', 'ticket_type']


# Admin serializers
class AdminSupportTicketSerializer(serializers.ModelSerializer):
    user_username = serializers.SerializerMethodField()
    assigned_to_username = serializers.SerializerMethodField()
    
    class Meta:
        model = SupportTicket
        fields = ['id', 'user', 'user_username', 'subject', 'description', 'ticket_type', 
                  'status', 'priority', 'created_at', 'updated_at', 'resolved_at',
                  'assigned_to', 'assigned_to_username']
        read_only_fields = ['id', 'created_at', 'updated_at', 'user_username', 
                          'assigned_to_username']
    
    def get_user_username(self, obj):
        if obj.user:
            return obj.user.username
        return None
    
    def get_assigned_to_username(self, obj):
        if obj.assigned_to:
            return obj.assigned_to.username
        return None 