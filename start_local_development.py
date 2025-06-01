#!/usr/bin/env python3
"""
Local Development Server Startup Script for Testimus
Configures and starts the app for local development instead of production server
"""

import os
import sys
import subprocess
import time
import urllib.request
import urllib.error
import json
from pathlib import Path

def print_header(text):
    """Print a formatted header."""
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def print_step(step, description):
    """Print a formatted step."""
    print(f"\n🔧 STEP {step}: {description}")

def print_success(message):
    """Print a success message."""
    print(f"✅ {message}")

def print_error(message):
    """Print an error message."""
    print(f"❌ {message}")

def print_info(message):
    """Print an info message."""
    print(f"ℹ️  {message}")

def check_python():
    """Check if Python is available."""
    try:
        version = sys.version_info
        if version.major >= 3 and version.minor >= 8:
            print_success(f"Python {version.major}.{version.minor} is available")
            return True
        else:
            print_error(f"Python {version.major}.{version.minor} found, but Python 3.8+ is required")
            return False
    except Exception as e:
        print_error(f"Python check failed: {e}")
        return False

def check_django():
    """Check if Django is installed."""
    try:
        import django
        print_success(f"Django {django.VERSION[0]}.{django.VERSION[1]} is available")
        return True
    except ImportError:
        print_error("Django is not installed. Please run: pip install -r requirements.txt")
        return False

def check_database():
    """Check and prepare the database."""
    try:
        # Check if migrations need to be applied
        result = subprocess.run([
            sys.executable, 'manage.py', 'showmigrations', '--plan'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print_success("Database migrations are ready")
            
            # Check if database has any unapplied migrations
            if '[ ]' in result.stdout:
                print_info("Applying pending migrations...")
                migrate_result = subprocess.run([
                    sys.executable, 'manage.py', 'migrate'
                ], capture_output=True, text=True)
                
                if migrate_result.returncode == 0:
                    print_success("Database migrations applied successfully")
                else:
                    print_error(f"Migration failed: {migrate_result.stderr}")
                    return False
            
            return True
        else:
            print_error(f"Database check failed: {result.stderr}")
            return False
    except Exception as e:
        print_error(f"Database check error: {e}")
        return False

def check_api_config():
    """Check if API configuration is set to local development."""
    api_config_path = Path('Frontend/lib/utils/api_config.dart')
    
    if not api_config_path.exists():
        print_error("Flutter API config file not found")
        return False
    
    try:
        with open(api_config_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if 'http://localhost:8000' in content:
            print_success("Flutter app is configured for local development (localhost:8000)")
            return True
        elif '188.245.35.46' in content:
            print_error("Flutter app is still configured for production server")
            print_info("Please run the configuration update script first")
            return False
        else:
            print_info("Flutter app API configuration is using environment variables or custom setup")
            return True
    except Exception as e:
        print_error(f"Error checking API config: {e}")
        return False

def check_django_settings():
    """Check Django settings for local development."""
    try:
        # Set Django settings module for local development
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'exam_prep_platform.settings')
        
        import django
        django.setup()
        
        from django.conf import settings
        
        # Check if DEBUG is True
        if settings.DEBUG:
            print_success("Django DEBUG mode is enabled (local development)")
        else:
            print_error("Django DEBUG mode is disabled (production mode)")
            print_info("Make sure you're using exam_prep_platform.settings, not production_settings")
            return False
        
        # Check allowed hosts
        if 'localhost' in settings.ALLOWED_HOSTS or '*' in settings.ALLOWED_HOSTS:
            print_success("Django ALLOWED_HOSTS includes localhost")
        else:
            print_error("Django ALLOWED_HOSTS doesn't include localhost")
            return False
        
        # Check frontend URL
        frontend_url = getattr(settings, 'FRONTEND_URL', '')
        if 'localhost' in frontend_url:
            print_success(f"Django FRONTEND_URL is set to local development: {frontend_url}")
        else:
            print_info(f"Django FRONTEND_URL: {frontend_url}")
        
        return True
    except Exception as e:
        print_error(f"Django settings check failed: {e}")
        return False

def start_server():
    """Start the Django development server."""
    print_info("Starting Django development server on http://localhost:8000")
    print_info("Press Ctrl+C to stop the server")
    print_info("The server will start in 3 seconds...")
    
    for i in range(3, 0, -1):
        print(f"  {i}...")
        time.sleep(1)
    
    try:
        # Start the server
        subprocess.run([
            sys.executable, 'manage.py', 'runserver', 'localhost:8000'
        ])
    except KeyboardInterrupt:
        print_info("\nServer stopped by user")
    except Exception as e:
        print_error(f"Failed to start server: {e}")

def test_server_connectivity():
    """Test if the server is responding."""
    try:
        print_info("Testing server connectivity...")
        
        # Test base URL
        response = urllib.request.urlopen('http://localhost:8000/', timeout=5)
        if response.getcode() == 200:
            print_success("Base URL is accessible")
        
        # Test admin URL
        try:
            response = urllib.request.urlopen('http://localhost:8000/admin/', timeout=5)
            print_success("Admin panel is accessible")
        except urllib.error.HTTPError as e:
            if e.code == 302:  # Redirect to login is expected
                print_success("Admin panel is accessible (redirects to login)")
            else:
                print_info(f"Admin panel returns HTTP {e.code}")
        
        # Test API URL
        try:
            response = urllib.request.urlopen('http://localhost:8000/api/v1/', timeout=5)
            print_success("API endpoints are accessible")
        except urllib.error.HTTPError as e:
            if e.code == 404:  # Expected for base API URL
                print_success("API is responding (404 expected for base API URL)")
            else:
                print_info(f"API returns HTTP {e.code}")
        
        return True
    except Exception as e:
        print_error(f"Server connectivity test failed: {e}")
        return False

def print_local_urls():
    """Print the available local URLs."""
    print_header("LOCAL DEVELOPMENT URLS")
    print("📱 Main Application:")
    print("   • Server: http://localhost:8000/")
    print("   • Admin Panel: http://localhost:8000/admin/")
    print()
    print("📋 API Documentation:")
    print("   • API Schema: http://localhost:8000/api/schema/")
    print("   • Swagger UI: http://localhost:8000/api/docs/")
    print("   • ReDoc: http://localhost:8000/api/redoc/")
    print()
    print("🔌 API Endpoints:")
    print("   • Authentication: http://localhost:8000/api/v1/auth/")
    print("   • User Profile: http://localhost:8000/api/v1/users/me/")
    print("   • Exams: http://localhost:8000/api/v1/exams/")
    print("   • Questions: http://localhost:8000/api/v1/questions/")
    print()
    print("📱 Flutter App Configuration:")
    print("   • Base URL: http://localhost:8000")
    print("   • API Base: http://localhost:8000/api/v1")

def main():
    """Main function to run all checks and start the server."""
    print_header("TESTIMUS LOCAL DEVELOPMENT STARTUP")
    print("Configuring and starting the app for LOCAL development")
    print("Production server (188.245.35.46) will NOT be used")
    
    # Step 1: Environment checks
    print_step(1, "Checking Development Environment")
    if not check_python():
        return 1
    if not check_django():
        return 1
    
    # Step 2: Configuration checks
    print_step(2, "Verifying Local Development Configuration")
    if not check_django_settings():
        return 1
    if not check_api_config():
        return 1
    
    # Step 3: Database preparation
    print_step(3, "Preparing Database")
    if not check_database():
        return 1
    
    # Step 4: Show URLs
    print_step(4, "Local Development URLs")
    print_local_urls()
    
    # Step 5: Start server
    print_step(5, "Starting Development Server")
    start_server()
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 