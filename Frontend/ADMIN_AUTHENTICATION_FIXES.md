# Admin Authentication Issues and Fixes

## Issues Identified

Based on the logs, the admin dashboard was experiencing:

1. **401 Unauthorized** responses for multiple admin endpoints
2. **404 Not Found** for `/api/v1/admin/ai/metrics/` (endpoint doesn't exist)
3. Authentication problems preventing access to admin functionality

## Root Causes

### 1. Missing AI Metrics Endpoint
The code was trying to call `/api/v1/admin/ai/metrics/` which doesn't exist in the API documentation.

### 2. Authentication Issues
- JWT token might be missing or invalid
- User might not have admin privileges
- Backend authentication middleware issues

### 3. Poor Error Handling
- No specific handling for 401/403 errors
- No user feedback for authentication failures

## Fixes Applied

### 1. Fixed AI Metrics Endpoint (`lib/services/admin_service.dart`)

**Before:**
```dart
final response = await http.get(
  Uri.parse('${ApiConfig.apiV1Url}/admin/ai/metrics/'),
  headers: headers,
);
```

**After:**
```dart
final response = await http.get(
  Uri.parse('${ApiConfig.apiV1Url}/admin/ai/evaluation-logs/?page=1&page_size=100'),
  headers: headers,
);
// Calculate metrics from evaluation logs
```

### 2. Enhanced Authentication Error Handling

**Dashboard (`lib/screens/admin_panel/dashboard_screen.dart`):**
- Added specific detection of 401/403 errors
- Added authentication error dialog
- Provides user options to retry or login again

**AdminService (`lib/services/admin_service.dart`):**
- Added specific error messages for 401/403 responses
- Added debug logging for token information

### 3. User-Friendly Error Dialog

Added `_showAuthenticationErrorDialog()` that:
- Explains the authentication issue
- Lists possible causes
- Provides "Retry" and "Login Again" options

### 4. Debug Information

Added debug logging to:
- Show token information (first 20 chars for security)
- Identify when AdminService is initialized without a token
- Better error messages for different HTTP status codes

## Testing Authentication

To resolve the authentication issues, check:

### 1. Backend User Permissions
Ensure the user has admin privileges:
```python
# In Django admin or shell
user = User.objects.get(email='your-email@example.com')
user.is_staff = True
user.is_superuser = True  # If needed
user.save()
```

### 2. JWT Token Validity
Check if the JWT token is valid and contains admin claims:
```dart
// In Flutter app, check token expiration
final user = context.authService.currentUser;
print('User is admin: ${user?.isAdmin}');
print('Token exists: ${user?.accessToken != null}');
```

### 3. Backend Authentication Middleware
Ensure your Django settings have proper JWT authentication:
```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}
```

### 4. Admin Endpoint Permissions
Verify admin endpoints have proper permissions:
```python
# In your admin views
from rest_framework.permissions import IsAdminUser

class AdminUserViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAdminUser]
    # ... rest of the view
```

## Expected Behavior After Fixes

### 1. Successful Authentication
- Dashboard loads with metrics
- No 401/404 errors in logs
- All admin functions work properly

### 2. Authentication Failure
- User sees clear error dialog
- Option to retry or login again
- No confusing error messages

### 3. Partial Data Loading
- If some endpoints fail, others continue to work
- Dashboard shows available data
- Clear indication of what's not available

## Debugging Steps

If authentication issues persist:

1. **Check Flutter logs** for token information
2. **Check backend logs** for permission errors
3. **Verify user has admin role** in Django admin
4. **Test admin endpoints directly** with curl/Postman
5. **Check JWT token expiration** and refresh logic

## API Endpoints Status

✅ **Fixed:**
- `/api/v1/admin/ai/evaluation-logs/` (replaces non-existent metrics endpoint)

❌ **Still returning 401 (need backend fix):**
- `/api/v1/admin/users/metrics/`
- `/api/v1/admin/questions/questions/metrics/`
- `/api/v1/admin/subscriptions/subscriptions/`
- `/api/v1/admin/ai/content-alerts/`

## Next Steps

1. **Backend**: Ensure user has proper admin permissions
2. **Backend**: Verify admin endpoints are properly secured
3. **Frontend**: Test with valid admin credentials
4. **Frontend**: Monitor logs for any remaining issues

The frontend is now robust enough to handle authentication failures gracefully while providing clear feedback to users about what's happening. 

# Admin Panel Authentication Fixes

## Issue Description
The admin panel was experiencing 401 Unauthorized errors when trying to access admin endpoints. This was preventing the dashboard and other admin screens from loading properly.

## Root Cause
The issue was in how the admin screens were accessing the JWT access token for API authentication:

### Before (Incorrect)
```dart
final user = context.authService.currentUser;
_adminService = AdminService(accessToken: user.accessToken);
```

### After (Correct)
```dart
final authService = context.authService;
final user = authService.currentUser;
final accessToken = authService.accessToken;
_adminService = AdminService(accessToken: accessToken);
```

## Problem Explanation
1. The `User` model has an `accessToken` field, but this field is typically null because tokens are not stored in the user object
2. The `AuthService` stores the actual JWT access token in its private `_accessToken` field and exposes it through the `accessToken` getter
3. Admin screens were trying to access `user.accessToken` (which was null) instead of `authService.accessToken` (which contains the actual token)

## Files Fixed
The following admin screen files were updated to use the correct access token:

1. `Frontend/lib/screens/admin_panel/dashboard_screen.dart`
2. `Frontend/lib/screens/admin_panel/users/users_screen.dart`
3. `Frontend/lib/screens/admin_panel/users/user_detail_screen.dart`
4. `Frontend/lib/screens/admin_panel/content/questions_screen.dart`
5. `Frontend/lib/screens/admin_panel/content/topics_screen.dart` (2 instances)
6. `Frontend/lib/screens/admin_panel/ai_alerts/ai_alerts_screen.dart`

## Changes Made
For each admin screen, the `_initializeAdminService()` method was updated to:

1. Get both the user and access token from the auth service
2. Check that both user exists, access token exists, and user has staff privileges
3. Only initialize the AdminService if all conditions are met
4. Redirect to login if authentication fails
5. Add proper error handling and debugging information

## Additional Improvements
- Added debug logging to help troubleshoot authentication issues
- Improved error handling for cases where user is not admin
- Added proper null checks for both user and access token
- Enhanced user feedback with better error messages

## Testing
After these fixes, the admin panel should:
- Load dashboard metrics without 401 errors
- Display user management screens properly
- Allow content management (topics, questions)
- Show AI alerts and other admin features
- Provide clear error messages if authentication fails

## Future Considerations
- Consider implementing token refresh logic in admin screens
- Add more comprehensive error handling for network issues
- Implement proper loading states during authentication checks
- Consider caching admin data to reduce API calls 