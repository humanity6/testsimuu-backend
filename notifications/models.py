from django.db import models
from users.models import User

class Notification(models.Model):
    """Model for user notifications."""
    NOTIFICATION_TYPE_CHOICES = (
        ('SYSTEM', 'System'),
        ('SUBSCRIPTION', 'Subscription'),
        ('LEARNING', 'Learning'),
        ('SUPPORT', 'Support'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=20, choices=NOTIFICATION_TYPE_CHOICES, db_index=True)
    related_object_type = models.CharField(max_length=50, null=True, blank=True)
    related_object_id = models.IntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False, db_index=True)
    is_sent = models.BooleanField(default=False)
    send_email = models.BooleanField(default=False)
    send_push = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    scheduled_for = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(null=True, blank=True)

    class Meta:
        db_table = 'notifications_notification'
        indexes = [
            models.Index(fields=['user', 'is_read', 'created_at']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.title[:50]} - {self.notification_type}" 