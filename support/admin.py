from django.contrib import admin
from .models import FAQItem, SupportTicket, TicketReply

class TicketReplyInline(admin.StackedInline):
    model = TicketReply
    extra = 1

@admin.register(FAQItem)
class FAQItemAdmin(admin.ModelAdmin):
    list_display = ('question_text_preview', 'category', 'display_order', 'is_published', 'view_count')
    list_filter = ('category', 'is_published')
    search_fields = ('question_text', 'answer_text', 'category')
    
    def question_text_preview(self, obj):
        return obj.question_text[:50] + '...' if len(obj.question_text) > 50 else obj.question_text
    question_text_preview.short_description = 'Question'

@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ('subject', 'user', 'ticket_type', 'status', 'priority', 'created_at', 'assigned_to')
    list_filter = ('ticket_type', 'status', 'priority')
    search_fields = ('subject', 'description', 'user__username', 'user__email')
    date_hierarchy = 'created_at'
    inlines = [TicketReplyInline]

@admin.register(TicketReply)
class TicketReplyAdmin(admin.ModelAdmin):
    list_display = ('ticket', 'user', 'message_preview', 'is_staff_reply', 'created_at')
    list_filter = ('is_staff_reply', 'created_at')
    search_fields = ('message', 'user__username', 'ticket__subject')
    date_hierarchy = 'created_at'
    
    def message_preview(self, obj):
        return obj.message[:50] + '...' if len(obj.message) > 50 else obj.message
    message_preview.short_description = 'Message' 