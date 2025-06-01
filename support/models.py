from django.db import models
from users.models import User

class FAQItem(models.Model):
    """Model for FAQ items."""
    question_text = models.TextField()
    answer_text = models.TextField()
    category = models.CharField(max_length=50, db_index=True)
    display_order = models.IntegerField(default=0)
    is_published = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    view_count = models.IntegerField(default=0)

    class Meta:
        db_table = 'support_faqitem'

    def __str__(self):
        return f"{self.category} - {self.question_text[:50]}"

class SupportTicket(models.Model):
    """Model for support tickets."""
    TICKET_TYPE_CHOICES = (
        ('QUESTION', 'Question'),
        ('BUG', 'Bug'),
        ('FEATURE_REQUEST', 'Feature Request'),
        ('BILLING', 'Billing'),
        ('OTHER', 'Other'),
    )
    STATUS_CHOICES = (
        ('OPEN', 'Open'),
        ('IN_PROGRESS', 'In Progress'),
        ('RESOLVED', 'Resolved'),
        ('CLOSED', 'Closed'),
    )
    PRIORITY_CHOICES = (
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
    )

    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='support_tickets')
    subject = models.CharField(max_length=255)
    description = models.TextField()
    ticket_type = models.CharField(max_length=20, choices=TICKET_TYPE_CHOICES, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='OPEN', db_index=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='MEDIUM')
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    assigned_to = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='assigned_tickets')

    class Meta:
        db_table = 'support_supportticket'

    def __str__(self):
        user_info = self.user.username if self.user else "Anonymous"
        return f"{user_info} - {self.subject[:50]} - {self.status}"

class TicketReply(models.Model):
    """Model for replies to support tickets."""
    ticket = models.ForeignKey(SupportTicket, on_delete=models.CASCADE, related_name='replies')
    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='ticket_replies')
    message = models.TextField()
    is_staff_reply = models.BooleanField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'support_ticketreply'

    def __str__(self):
        user_info = self.user.username if self.user else "System"
        return f"Reply by {user_info} - {self.created_at}" 