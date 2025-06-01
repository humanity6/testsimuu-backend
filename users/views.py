from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
from django.contrib.auth import authenticate
from .models import User
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    UserProfileUpdateSerializer
)
from drf_spectacular.utils import extend_schema, OpenApiResponse, OpenApiExample


@extend_schema(
    tags=['Authentication'],
    summary="Register a new user",
    description="Create a new user account and return user data with JWT tokens",
    responses={
        201: OpenApiResponse(
            description="User registered successfully",
            examples=[
                OpenApiExample(
                    'Success Response',
                    value={
                        'user': {
                            'id': 1,
                            'username': 'testuser',
                            'email': 'test@example.com',
                            'first_name': 'Test',
                            'last_name': 'User',
                            'profile_picture_url': None,
                            'date_of_birth': None,
                            'time_zone': 'UTC',
                            'email_verified': False,
                            'referral_code': 'ABC123',
                            'date_joined': '2023-05-26T12:00:00Z',
                            'is_staff': False
                        },
                        'tokens': {
                            'refresh': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...',
                            'access': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...'
                        }
                    }
                )
            ]
        ),
        400: OpenApiResponse(description="Invalid input data")
    }
)
class UserRegistrationView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Generate JWT tokens for the newly registered user
        refresh = RefreshToken.for_user(user)
        
        # Return user data and tokens
        return Response({
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)


@extend_schema(
    tags=['Authentication'],
    summary="User login",
    description="Authenticate a user and return user data with JWT tokens",
    responses={
        200: OpenApiResponse(
            description="Login successful",
            examples=[
                OpenApiExample(
                    'Success Response',
                    value={
                        'user': {
                            'id': 1,
                            'username': 'testuser',
                            'email': 'test@example.com',
                            'first_name': 'Test',
                            'last_name': 'User',
                            'profile_picture_url': None,
                            'date_of_birth': None,
                            'time_zone': 'UTC',
                            'email_verified': False,
                            'referral_code': 'ABC123',
                            'date_joined': '2023-05-26T12:00:00Z',
                            'is_staff': False
                        },
                        'tokens': {
                            'refresh': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...',
                            'access': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...'
                        }
                    }
                )
            ]
        ),
        400: OpenApiResponse(description="Invalid credentials")
    }
)
class UserLoginView(generics.GenericAPIView):
    serializer_class = UserLoginSerializer
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        
        # Update last_login
        user.save(update_fields=['last_login'])
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)


@extend_schema(
    tags=['Authentication'],
    summary="User logout",
    description="Blacklist the user's refresh token to logout",
    request={'application/json': {'properties': {'refresh': {'type': 'string'}}}},
    responses={
        200: OpenApiResponse(description="Logout successful"),
        400: OpenApiResponse(description="Invalid refresh token")
    }
)
class UserLogoutView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        try:
            # Get refresh token from request data
            refresh_token = request.data.get('refresh')
            if not refresh_token:
                return Response({"error": "Refresh token is required"}, status=status.HTTP_400_BAD_REQUEST)
            
            # Blacklist the refresh token
            token = RefreshToken(refresh_token)
            token.blacklist()
            
            return Response({"success": "Successfully logged out"}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(
    tags=['Users'],
    summary="User profile",
    description="Retrieve or update the authenticated user's profile",
    responses={
        200: UserProfileSerializer,
        401: OpenApiResponse(description="Authentication credentials were not provided")
    }
)
class UserProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return UserProfileSerializer
        return UserProfileUpdateSerializer
    
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        
        # Return the updated profile using the full profile serializer
        return Response(UserProfileSerializer(instance).data)
    
    def partial_update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs) 