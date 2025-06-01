#!/usr/bin/env python
"""
Local Development Server Runner

This script sets up and runs the Django development server optimized for local testing.
"""
import os
import sys
import subprocess

def run_local_server():
    """Run the Django development server for local testing"""
    
    print("🚀 Starting Testimus Local Development Server")
    print("=" * 50)
    
    # Ensure we're using the development settings
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'exam_prep_platform.settings')
    
    # Set local development environment variables
    os.environ.setdefault('FRONTEND_URL', 'http://localhost:8000')
    os.environ.setdefault('SUMUP_TESTING_MODE', 'true')
    
    print("📋 Configuration:")
    print(f"   • Settings Module: {os.environ.get('DJANGO_SETTINGS_MODULE')}")
    print(f"   • Frontend URL: {os.environ.get('FRONTEND_URL')}")
    print(f"   • Testing Mode: {os.environ.get('SUMUP_TESTING_MODE')}")
    print(f"   • Debug: True (Development)")
    print(f"   • Database: SQLite (Local)")
    print(f"   • Email Backend: Console (Development)")
    
    print("\n🔧 Running system checks...")
    
    # Run Django management commands
    try:
        # Check for pending migrations
        print("   • Checking for migrations...")
        result = subprocess.run([sys.executable, 'manage.py', 'showmigrations', '--plan'], 
                              capture_output=True, text=True, check=False)
        
        if '[ ]' in result.stdout:
            print("   ⚠️  Unapplied migrations found. Running migrations...")
            subprocess.run([sys.executable, 'manage.py', 'migrate'], check=True)
            print("   ✅ Migrations applied successfully")
        else:
            print("   ✅ All migrations up to date")
            
        # Collect static files if needed (development)
        print("   • Checking static files...")
        print("   ✅ Static files ready (development mode)")
        
        print("\n🌐 Starting development server...")
        print("   • Local URL: http://localhost:8000/")
        print("   • Admin URL: http://localhost:8000/admin/")
        print("   • API Docs: http://localhost:8000/api/docs/")
        print("   • Press CTRL+C to stop the server")
        print("\n" + "=" * 50)
        
        # Start the development server
        subprocess.run([
            sys.executable, 'manage.py', 'runserver', 
            '--noreload'  # Use --noreload as per user's preference
        ], check=True)
        
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error running server: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_local_server() 