from rest_framework import serializers
from .models import UserPreference

class NotificationPreferenceSerializer(serializers.Serializer):
    system = serializers.BooleanField(default=True)
    subscription = serializers.BooleanField(default=True)
    learning = serializers.BooleanField(default=True)
    support = serializers.BooleanField(default=True)
    email = serializers.BooleanField(default=True)
    push = serializers.BooleanField(default=True)

class UserPreferenceSerializer(serializers.ModelSerializer):
    notification_settings = NotificationPreferenceSerializer()
    
    class Meta:
        model = UserPreference
        fields = ['id', 'notification_settings', 'ui_preferences', 'updated_at']
        read_only_fields = ['id', 'updated_at']
    
    def create(self, validated_data):
        return UserPreference.objects.create(**validated_data)
    
    def update(self, instance, validated_data):
        # Handle nested notification_settings
        notification_settings_data = validated_data.pop('notification_settings', None)
        if notification_settings_data is not None:
            current_settings = instance.notification_settings
            # Update with new values
            current_settings.update(notification_settings_data)
            instance.notification_settings = current_settings
        
        # Handle other fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        instance.save()
        return instance 