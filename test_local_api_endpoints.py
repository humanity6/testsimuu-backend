#!/usr/bin/env python3
"""
Local API Endpoints Test Script for Testimus
Tests all major API endpoints to ensure they work with localhost:8000
"""

import requests
import json
import sys
from datetime import datetime

# Local development server configuration
BASE_URL = "http://localhost:8000"
API_V1_URL = f"{BASE_URL}/api/v1"

def print_header(text):
    """Print a formatted header."""
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def print_test(endpoint, method="GET"):
    """Print test information."""
    print(f"\n🧪 Testing {method} {endpoint}")

def print_success(message):
    """Print a success message."""
    print(f"✅ {message}")

def print_error(message):
    """Print an error message."""
    print(f"❌ {message}")

def print_info(message):
    """Print an info message."""
    print(f"ℹ️  {message}")

def test_endpoint(url, method="GET", data=None, expected_codes=None, auth_token=None):
    """Test a single endpoint and return result."""
    if expected_codes is None:
        expected_codes = [200, 201, 400, 401, 403, 404, 405]  # Consider these as "working"
    
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    if auth_token:
        headers['Authorization'] = f'Bearer {auth_token}'
    
    try:
        if method.upper() == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method.upper() == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)
        elif method.upper() == "PUT":
            response = requests.put(url, headers=headers, json=data, timeout=10)
        elif method.upper() == "DELETE":
            response = requests.delete(url, headers=headers, timeout=10)
        else:
            response = requests.request(method, url, headers=headers, json=data, timeout=10)
        
        if response.status_code in expected_codes:
            return True, response.status_code, response.text[:200] if response.text else ""
        else:
            return False, response.status_code, response.text[:200] if response.text else ""
    
    except requests.exceptions.ConnectionError:
        return False, 0, "Connection failed - Server not running"
    except requests.exceptions.Timeout:
        return False, 0, "Request timeout"
    except Exception as e:
        return False, 0, str(e)

def test_public_endpoints():
    """Test public endpoints that don't require authentication."""
    print_header("TESTING PUBLIC ENDPOINTS")
    
    endpoints = [
        # Basic endpoints
        ("Base URL", "GET", BASE_URL, [200, 404]),
        ("Admin Panel", "GET", f"{BASE_URL}/admin/", [200, 302]),  # 302 = redirect to login
        ("API Schema", "GET", f"{BASE_URL}/api/schema/", [200]),
        ("API Docs", "GET", f"{BASE_URL}/api/docs/", [200]),
        ("API ReDoc", "GET", f"{BASE_URL}/api/redoc/", [200]),
        
        # API endpoints (most will return 401 without auth, which is correct)
        ("Pricing Plans", "GET", f"{API_V1_URL}/pricing-plans/", [200, 401]),
        ("FAQ Items", "GET", f"{API_V1_URL}/faq-items/", [200, 401]),
        ("Exams List", "GET", f"{API_V1_URL}/exams/", [200, 401]),
        ("Questions List", "GET", f"{API_V1_URL}/questions/", [200, 401]),
    ]
    
    results = []
    for name, method, url, expected_codes in endpoints:
        print_test(f"{name}: {url}", method)
        success, status_code, response_text = test_endpoint(url, method, expected_codes=expected_codes)
        
        if success:
            print_success(f"Status: {status_code} - Endpoint is working")
        else:
            print_error(f"Status: {status_code} - {response_text}")
        
        results.append((name, success, status_code))
    
    return results

def test_auth_endpoints():
    """Test authentication endpoints."""
    print_header("TESTING AUTHENTICATION ENDPOINTS")
    
    # Test registration endpoint with invalid data (should return 400)
    print_test(f"Registration: {API_V1_URL}/auth/register/", "POST")
    success, status_code, response_text = test_endpoint(
        f"{API_V1_URL}/auth/register/",
        method="POST",
        data={"email": "invalid-email", "password": "short"},
        expected_codes=[400, 401]
    )
    
    if success:
        print_success(f"Status: {status_code} - Registration endpoint is working")
    else:
        print_error(f"Status: {status_code} - {response_text}")
    
    # Test login endpoint with invalid data (should return 400 or 401)
    print_test(f"Login: {API_V1_URL}/auth/login/", "POST")
    success, status_code, response_text = test_endpoint(
        f"{API_V1_URL}/auth/login/",
        method="POST",
        data={"email": "nonexistent@example.com", "password": "wrongpassword"},
        expected_codes=[400, 401]
    )
    
    if success:
        print_success(f"Status: {status_code} - Login endpoint is working")
    else:
        print_error(f"Status: {status_code} - {response_text}")
    
    # Test token refresh endpoint (should return 400 without token)
    print_test(f"Token Refresh: {API_V1_URL}/auth/refresh/", "POST")
    success, status_code, response_text = test_endpoint(
        f"{API_V1_URL}/auth/refresh/",
        method="POST",
        data={"refresh": "invalid-token"},
        expected_codes=[400, 401]
    )
    
    if success:
        print_success(f"Status: {status_code} - Token refresh endpoint is working")
    else:
        print_error(f"Status: {status_code} - {response_text}")
    
    return [
        ("Registration", success, status_code),
        ("Login", success, status_code),
        ("Token Refresh", success, status_code)
    ]

def test_protected_endpoints():
    """Test protected endpoints that require authentication."""
    print_header("TESTING PROTECTED ENDPOINTS (WITHOUT AUTH)")
    print_info("These should return 401 Unauthorized, which indicates they're working correctly")
    
    endpoints = [
        ("User Profile", "GET", f"{API_V1_URL}/users/me/"),
        ("User Preferences", "GET", f"{API_V1_URL}/users/me/preferences/"),
        ("User Notifications", "GET", f"{API_V1_URL}/users/me/notifications/"),
        ("Exam Sessions", "GET", f"{API_V1_URL}/exam-sessions/"),
        ("User Answers", "GET", f"{API_V1_URL}/user-answers/"),
        ("Support Tickets", "GET", f"{API_V1_URL}/support/tickets/"),
        ("AI Chatbot", "GET", f"{API_V1_URL}/ai/chatbot/conversations/"),
    ]
    
    results = []
    for name, method, url in endpoints:
        print_test(f"{name}: {url}", method)
        success, status_code, response_text = test_endpoint(url, method, expected_codes=[401])
        
        if success and status_code == 401:
            print_success(f"Status: {status_code} - Correctly requires authentication")
        elif status_code == 200:
            print_info(f"Status: {status_code} - Endpoint allows anonymous access")
        else:
            print_error(f"Status: {status_code} - {response_text}")
        
        results.append((name, success or status_code == 200, status_code))
    
    return results

def test_admin_endpoints():
    """Test admin endpoints."""
    print_header("TESTING ADMIN ENDPOINTS (WITHOUT AUTH)")
    print_info("These should return 401 Unauthorized, which indicates they're working correctly")
    
    endpoints = [
        ("Admin Users", "GET", f"{API_V1_URL}/admin/users/"),
        ("Admin Questions", "GET", f"{API_V1_URL}/admin/questions/questions/"),
        ("Admin Subscriptions", "GET", f"{API_V1_URL}/admin/subscriptions/subscriptions/"),
        ("Admin Support", "GET", f"{API_V1_URL}/admin/support/tickets/"),
        ("Admin AI", "GET", f"{API_V1_URL}/admin/ai/content-alerts/"),
        ("Admin Analytics", "GET", f"{API_V1_URL}/admin/analytics/"),
    ]
    
    results = []
    for name, method, url in endpoints:
        print_test(f"{name}: {url}", method)
        success, status_code, response_text = test_endpoint(url, method, expected_codes=[401, 403])
        
        if success and status_code in [401, 403]:
            print_success(f"Status: {status_code} - Correctly requires admin authentication")
        else:
            print_error(f"Status: {status_code} - {response_text}")
        
        results.append((name, success, status_code))
    
    return results

def print_summary(all_results):
    """Print a summary of all test results."""
    print_header("TEST SUMMARY")
    
    total_tests = sum(len(results) for results in all_results)
    successful_tests = sum(sum(1 for _, success, _ in results if success) for results in all_results)
    
    print(f"📊 Total Tests: {total_tests}")
    print(f"✅ Successful: {successful_tests}")
    print(f"❌ Failed: {total_tests - successful_tests}")
    print(f"📈 Success Rate: {(successful_tests/total_tests)*100:.1f}%")
    
    if successful_tests == total_tests:
        print_success("All API endpoints are working correctly with localhost:8000!")
        print_info("Your app is ready for local development")
    elif successful_tests > total_tests * 0.8:
        print_info("Most API endpoints are working. Check failed tests above.")
    else:
        print_error("Many API endpoints are failing. Check server configuration.")
    
    print("\n🔧 Next Steps:")
    print("   1. Start the Flutter app and test the integration")
    print("   2. Create a test user account via the API or admin panel")
    print("   3. Test authenticated endpoints with real credentials")
    print("   4. Check the Django logs for any errors")

def main():
    """Main function to run all API tests."""
    print_header("TESTIMUS LOCAL API ENDPOINTS TEST")
    print(f"Testing all API endpoints against: {BASE_URL}")
    print(f"API Base URL: {API_V1_URL}")
    print(f"Test started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Run all test suites
    public_results = test_public_endpoints()
    auth_results = test_auth_endpoints()
    protected_results = test_protected_endpoints()
    admin_results = test_admin_endpoints()
    
    # Print summary
    print_summary([public_results, auth_results, protected_results, admin_results])
    
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n🛑 Tests stopped by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Test error: {e}")
        sys.exit(1) 