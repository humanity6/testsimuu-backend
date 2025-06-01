from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import UserPreference
from .preferences_serializers import UserPreferenceSerializer
from drf_spectacular.utils import extend_schema, OpenApiResponse

@extend_schema(
    tags=['Users'],
    summary="User preferences",
    description="Retrieve or update the authenticated user's preferences",
    responses={
        200: UserPreferenceSerializer,
        401: OpenApiResponse(description="Authentication credentials were not provided")
    }
)
class UserPreferenceView(generics.RetrieveUpdateAPIView):
    """
    API view for retrieving and updating user preferences.
    """
    serializer_class = UserPreferenceSerializer
    permission_classes = [IsAuthenticated]
    
    def get_object(self):
        user = self.request.user
        # Get or create user preferences
        preference, created = UserPreference.objects.get_or_create(
            user=user,
            defaults={
                'notification_settings': {
                    'system': True,
                    'subscription': True,
                    'learning': True,
                    'support': True,
                    'email': True,
                    'push': True
                },
                'ui_preferences': {}
            }
        )
        return preference 