"""
Django settings for exam_prep_platform project.

Generated by 'django-admin startproject' using Django 5.2.1.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/5.2/ref/settings/
"""

from pathlib import Path
from datetime import timedelta
import os

# Load environment variables from .env file for development
from dotenv import load_dotenv
load_dotenv()

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-v=zb5a64nghrs5^&2-3%&ogmc!$mk$=3pmy8of5kax3y)1n&7i'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# Local development hosts - optimized for testing
ALLOWED_HOSTS = [
    'localhost', 
    '127.0.0.1', 
    '[::1]',           # IPv6 localhost
    'testserver',      # For Django tests
    '0.0.0.0',         # Allow all interfaces for local network testing
    '188.245.35.46',   # Hetzner Cloud IP
]


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Custom apps
    'users',
    'questions',
    'subscriptions',
    'assessment',
    'analytics',
    'ai_integration',
    'support',
    'notifications',
    'exams',
    'affiliates',
    # Third party apps
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
    'corsheaders',
    'drf_spectacular',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # CORS middleware - add before CommonMiddleware
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'exam_prep_platform.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'exam_prep_platform.wsgi.application'


# Database
# https://docs.djangoproject.com/en/5.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'exam_prep_db.sqlite3',
    }
}

# Uncomment this for PostgreSQL in production
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': 'exam_prep_db',
#         'USER': 'postgres',
#         'PASSWORD': 'password',
#         'HOST': 'localhost',
#         'PORT': '5432',
#     }
# }


# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = 'static/'

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Custom user model
AUTH_USER_MODEL = 'users.User'

# Authentication Backends
AUTHENTICATION_BACKENDS = [
    'users.authentication.CaseInsensitiveEmailBackend',
    'django.contrib.auth.backends.ModelBackend',  # Keep default as fallback
]

# REST Framework Settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

# Simple JWT Settings
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}

# Frontend URL for password reset links and API redirects - LOCAL DEVELOPMENT
FRONTEND_URL = os.environ.get('FRONTEND_URL', 'http://localhost:8000')


# SumUp Integration Settings - Load from environment variables
SUMUP_API_KEY = os.environ.get('SUMUP_API_KEY', '')
SUMUP_API_BASE_URL = 'https://api.sumup.com/v0.1'  # Production API endpoint
SUMUP_MERCHANT_CODE = os.environ.get('SUMUP_MERCHANT_CODE', '')
SUMUP_MERCHANT_EMAIL = os.environ.get('SUMUP_MERCHANT_EMAIL', '')
SUMUP_WEBHOOK_SECRET = os.environ.get('SUMUP_WEBHOOK_SECRET', 'sumup-webhook-secret')
SUMUP_WEBHOOK_URL = os.environ.get('SUMUP_WEBHOOK_URL', f'{FRONTEND_URL}/api/v1/webhooks/sumup/')
SUMUP_RETURN_URL = os.environ.get('SUMUP_RETURN_URL', f'{FRONTEND_URL}/subscription/success/')

# Testing mode - set to False for production
SUMUP_TESTING_MODE = os.environ.get('SUMUP_TESTING_MODE', 'false').lower() == 'true'

# SumUp Country Configuration
SUMUP_COUNTRY_CODE = 'DE'  # Germany
SUMUP_CURRENCY = 'EUR'  # Euro for Germany

# Dynamic URLs based on current host (for webhooks and redirects)
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0', '*']  # Update with your production domain

# CORS settings
CORS_ALLOW_ALL_ORIGINS = True  # For development only
CORS_ALLOW_CREDENTIALS = True

# Email settings
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'  # For development - prints to console
DEFAULT_FROM_EMAIL = 'admin@testimus.com'

# For production, use SMTP:
# EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
# EMAIL_HOST = 'smtp.gmail.com'
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = 'your-email@gmail.com'
# EMAIL_HOST_PASSWORD = 'your-app-password'

# Frontend URL is defined above with SumUp settings

# OpenAI API Settings for AI Integration - Load from environment variables
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')
OPENAI_MODEL = os.environ.get('OPENAI_MODEL', 'gpt-4o-mini')



# Note: For local testing, set environment variables for real API keys if needed:
# For Windows PowerShell: $env:OPENAI_API_KEY="your-api-key-here"
# For Windows Command Prompt: set OPENAI_API_KEY=your-api-key-here
# For Unix/Linux/Mac: export OPENAI_API_KEY="your-api-key-here"

# Spectacular API Documentation Settings
SPECTACULAR_SETTINGS = {
    'TITLE': 'Testimus API',
    'DESCRIPTION': 'API documentation for Testimus exam preparation platform',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'COMPONENT_SPLIT_REQUEST': True,
    'SCHEMA_PATH_PREFIX': r'/api/v[0-9]',
    'TAGS': [
        {'name': 'Authentication', 'description': 'Authentication endpoints'},
        {'name': 'Users', 'description': 'User management endpoints'},
        {'name': 'Questions', 'description': 'Question management endpoints'},
        {'name': 'Exams', 'description': 'Exam management endpoints'},
        {'name': 'Subscriptions', 'description': 'Subscription management endpoints'},
        {'name': 'Support', 'description': 'Support and ticket management endpoints'},
        {'name': 'AI Integration', 'description': 'AI chatbot and integration endpoints'},
        {'name': 'Analytics', 'description': 'Analytics and reporting endpoints'},
        {'name': 'Notifications', 'description': 'Notification management endpoints'},
        {'name': 'Affiliates', 'description': 'Affiliate program management endpoints'},
    ],
}
