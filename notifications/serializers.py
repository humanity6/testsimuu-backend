from rest_framework import serializers
from .models import Notification

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id', 'title', 'message', 'notification_type', 
            'is_read', 'created_at', 'related_object_type', 
            'related_object_id', 'metadata'
        ]
        read_only_fields = [
            'id', 'title', 'message', 'notification_type', 
            'created_at', 'related_object_type', 
            'related_object_id', 'metadata'
        ] 