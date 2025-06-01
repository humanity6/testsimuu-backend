"""
URL configuration for exam_prep_platform project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """Simple health check endpoint"""
    return Response({
        'status': 'healthy',
        'message': 'API is running'
    }, status=status.HTTP_200_OK)

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # Health check endpoint
    path('api/health/', health_check, name='health-check'),
    
    # API endpoints
    path('api/v1/', include('users.urls')),
    path('api/v1/', include('questions.urls')),
    path('api/v1/', include('subscriptions.urls')),
    path('api/v1/', include('assessment.urls')),
    path('api/v1/admin/', include('users.admin_urls')),
    path('api/v1/admin/questions/', include('questions.admin_urls')),
    path('api/v1/admin/subscriptions/', include('subscriptions.admin_urls')),
    path('api/v1/admin/exams/', include('exams.admin_urls')),
    path('api/v1/', include('notifications.urls')),
    path('api/v1/', include('support.urls')),
    path('api/v1/admin/support/', include('support.admin_urls')),
    path('api/v1/admin/ai/', include('ai_integration.admin_urls')),
    path('api/v1/ai/', include('ai_integration.urls')),
    path('api/v1/', include('analytics.urls')),
    path('api/v1/', include('exams.urls')),
    path('api/v1/affiliates/', include('affiliates.urls')),
    path('api/v1/admin/affiliates/', include('affiliates.admin_urls')),
    
    # API Documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    # Optional UI:
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]
