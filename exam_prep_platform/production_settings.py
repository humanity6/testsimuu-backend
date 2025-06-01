from .settings import *
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

# Production secret key from environment variable
SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-fallback-key-change-this')

# Authentication Backends - ensure case-insensitive email authentication in production
AUTHENTICATION_BACKENDS = [
    'users.authentication.CaseInsensitiveEmailBackend',
    'django.contrib.auth.backends.ModelBackend',  # Keep default as fallback
]

# Update allowed hosts for production
ALLOWED_HOSTS = [
    '188.245.35.46',  # Your Hetzner server IP
    'localhost',
    '127.0.0.1',
    # Add your domain here when you have one
    # 'yourdomain.com',
    # 'www.yourdomain.com',
]

# Database configuration with environment variables
DATABASES = {
    'default': {
        'ENGINE': os.environ.get('DB_ENGINE', 'django.db.backends.sqlite3'),
        'NAME': os.environ.get('DB_NAME', BASE_DIR / 'exam_prep_db.sqlite3'),
        'USER': os.environ.get('DB_USER', ''),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

# Static files configuration for production
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Media files configuration
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Update frontend URL for production
FRONTEND_URL = os.environ.get('FRONTEND_URL', 'http://188.245.35.46')

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

# OpenAI API Settings for AI Integration - Load from environment variables
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')
OPENAI_MODEL = os.environ.get('OPENAI_MODEL', 'gpt-4o-mini')


# CORS settings for production - UPDATED TO ALLOW MOBILE APPS
CORS_ALLOW_ALL_ORIGINS = True  # Temporarily allow all origins for mobile apps
CORS_ALLOWED_ORIGINS = [
    "http://188.245.35.46",
    "http://localhost:3000",  # Flutter web dev server
    "http://127.0.0.1:3000",
    # Add your domain here when you have one
    # "https://yourdomain.com",
    # "https://www.yourdomain.com",
]

CORS_ALLOW_CREDENTIALS = True

# Additional CORS settings for mobile apps
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

# Security settings for production
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# # SSL/HTTPS settings (load from environment variables)
# SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'False').lower() == 'true'
# SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', '0'))
# SECURE_HSTS_INCLUDE_SUBDOMAINS = os.environ.get('SECURE_HSTS_INCLUDE_SUBDOMAINS', 'False').lower() == 'true'
# SECURE_HSTS_PRELOAD = os.environ.get('SECURE_HSTS_PRELOAD', 'False').lower() == 'true'
# SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'False').lower() == 'true'
# CSRF_COOKIE_SECURE = os.environ.get('CSRF_COOKIE_SECURE', 'False').lower() == 'true'

# Email settings for production - Load from environment variables
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'admin@testimus.com')

# Logging configuration for production
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/django/testimus.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'ERROR',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['file', 'console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
} 