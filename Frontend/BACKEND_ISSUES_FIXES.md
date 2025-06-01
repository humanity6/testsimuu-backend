# Backend Issues and Frontend Fixes

## Issues Identified from Backend Logs

### 1. Questions Metrics Endpoint Missing (404)
```
Not Found: /api/v1/admin/questions/questions/metrics/
[26/May/2025 02:20:20] "GET /api/v1/admin/questions/questions/metrics/ HTTP/1.1" 404 23
```

**Fix Applied:** Updated `AdminService.getDashboardMetrics()` to handle 404 gracefully
- Added try-catch around questions metrics call
- Provides default metrics when endpoint is missing
- Added TODO comment for backend implementation

### 2. AI Content Alerts Bad Request (400)
```
Bad Request: /api/v1/admin/ai/content-alerts/
[26/May/2025 02:20:20] "GET /api/v1/admin/ai/content-alerts/?page=1&page_size=20&status=PENDING HTTP/1.1" 400 82
```

**Fixes Applied:**
- Improved status parameter handling in `getAIAlerts()`
- Added proper status value mapping (PENDING, REVIEWED, RESOLVED)
- Added debug logging for request URLs
- Added specific 400 error handling
- Temporarily removed status filter to prevent crashes

### 3. Subscription Parsing Error (Frontend)
```
Error loading active subscriptions: NoSuchMethodError: '[]'
Dynamic call of null.
Receiver: 68
Arguments: ["name"]
```

**Fix Applied:** Updated `Subscription.fromJson()` to handle both API response formats
- Added fallback from `pricing_plan_name` to `pricing_plan.name`
- Added fallback from `pricing_plan_price` to `pricing_plan.price`
- Added fallback from `pricing_plan_currency` to `pricing_plan.currency`
- Improved error handling with detailed logging

### 4. Pagination Warning
```
UnorderedObjectListWarning: Pagination may yield inconsistent results with an unordered object_list: <class 'subscriptions.models.UserSubscription'> QuerySet.
```

**Backend Issue:** Need to add ordering to UserSubscription model
**Frontend Workaround:** Added error handling to prevent crashes

## Files Modified

### `Frontend/lib/services/admin_service.dart`
- Fixed questions metrics endpoint handling (404 graceful handling)
- Improved AI alerts parameter validation
- Added detailed debug logging for subscriptions
- Enhanced error handling across all methods

### `Frontend/lib/models/subscription.dart`
- Fixed JSON parsing to handle both nested and flat pricing plan data
- Added robust fallback mechanisms
- Improved number parsing with `double.tryParse()`

### `Frontend/lib/screens/admin_panel/dashboard_screen.dart`
- Added specific error handling for subscription parsing errors
- Added 400 error handling for AI alerts
- Improved user feedback for various error scenarios

## Current Status

✅ **Fixed and Working:**
- User metrics loading correctly
- Authentication working properly
- Dashboard loads without crashes
- Graceful error handling for missing endpoints

⚠️ **Partially Working:**
- Subscriptions: Basic loading works, may need backend ordering fix
- AI Alerts: Can load all alerts, status filtering may need backend fix

❌ **Still Needs Backend Implementation:**
- Questions metrics endpoint
- Proper AI alerts status parameter handling
- UserSubscription model ordering for pagination

## Backend Recommendations

### 1. Add Questions Metrics Endpoint
```python
# In questions/views.py
class QuestionMetricsView(APIView):
    permission_classes = [IsAdminUser]
    
    def get(self, request):
        return Response({
            'total_questions': Question.objects.count(),
            'active_questions': Question.objects.filter(is_active=True).count(),
            'questions_by_type': dict(Question.objects.values_list('question_type').annotate(count=Count('id'))),
            'questions_by_difficulty': dict(Question.objects.values_list('difficulty').annotate(count=Count('id'))),
        })
```

### 2. Fix UserSubscription Ordering
```python
# In subscriptions/models.py
class UserSubscription(models.Model):
    # ... existing fields ...
    
    class Meta:
        ordering = ['-created_at']  # Add default ordering
```

### 3. Fix AI Content Alerts Status Validation
Check the AI content alerts view to ensure it accepts 'PENDING' as a valid status value.

## Testing Results

After applying these fixes:
- ✅ Dashboard loads successfully
- ✅ No more 401 authentication errors
- ✅ Graceful handling of missing endpoints
- ✅ Better error messages for users
- ✅ Debug information for troubleshooting

The admin panel is now much more robust and can handle backend issues without crashing the frontend. 