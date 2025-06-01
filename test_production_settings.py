#!/usr/bin/env python3
"""
Test script specifically for production settings and .env file loading
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Add the project directory to Python path
project_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(project_dir))

print("🔍 TESTING PRODUCTION SETTINGS WITH .ENV")
print("=" * 50)

# Test loading .env file directly
print("📄 Loading .env file...")
env_file = project_dir / '.env'
if env_file.exists():
    load_dotenv(env_file)
    print("✅ .env file loaded")
else:
    print("❌ .env file not found")

# Check if environment variables are loaded
print("\n🔧 ENVIRONMENT VARIABLES LOADED:")
print("-" * 40)
print(f"SECRET_KEY: {os.environ.get('SECRET_KEY', 'NOT SET')[:20]}...")
print(f"DEBUG: {os.environ.get('DEBUG', 'NOT SET')}")
print(f"OPENAI_API_KEY: {os.environ.get('OPENAI_API_KEY', 'NOT SET')[:20]}...")
print(f"FRONTEND_URL: {os.environ.get('FRONTEND_URL', 'NOT SET')}")

# Now test Django production settings
print("\n🚀 TESTING DJANGO PRODUCTION SETTINGS:")
print("-" * 40)

os.environ['DJANGO_SETTINGS_MODULE'] = 'exam_prep_platform.production_settings'

try:
    import django
    django.setup()
    from django.conf import settings
    
    print("✅ Django production settings loaded successfully!")
    print(f"DEBUG: {settings.DEBUG}")
    print(f"SECRET_KEY starts with: {settings.SECRET_KEY[:20]}...")
    print(f"OPENAI_API_KEY set: {'Yes' if getattr(settings, 'OPENAI_API_KEY', '') else 'No'}")
    if getattr(settings, 'OPENAI_API_KEY', ''):
        openai_key = settings.OPENAI_API_KEY
        print(f"OPENAI_API_KEY starts with: {openai_key[:20]}...")
        print(f"OPENAI_API_KEY length: {len(openai_key)}")
    print(f"FRONTEND_URL: {getattr(settings, 'FRONTEND_URL', 'NOT SET')}")
    
    print("\n🧪 TESTING OPENAI API:")
    print("-" * 40)
    openai_key = getattr(settings, 'OPENAI_API_KEY', '')
    if openai_key:
        try:
            import requests
            headers = {
                'Authorization': f"Bearer {openai_key}",
                'Content-Type': 'application/json'
            }
            data = {
                'model': getattr(settings, 'OPENAI_MODEL', 'gpt-3.5-turbo'),
                'messages': [{'role': 'user', 'content': 'Test'}],
                'max_tokens': 5
            }
            response = requests.post(
                'https://api.openai.com/v1/chat/completions',
                headers=headers,
                json=data,
                timeout=10
            )
            print(f"OpenAI API status: {response.status_code}")
            if response.status_code == 200:
                print("✅ OpenAI API is working correctly!")
                print("✅ ChatBot issue should be FIXED on the server!")
            else:
                print(f"❌ OpenAI API error: {response.text[:200]}")
        except Exception as e:
            print(f"❌ OpenAI test failed: {str(e)}")
    else:
        print("❌ OpenAI API key not configured")
    
except Exception as e:
    print(f"❌ Error loading production settings: {str(e)}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 50)
print("✅ Production settings test completed!") 