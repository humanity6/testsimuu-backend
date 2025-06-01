# Testimus Mobile App - Connection Issues Troubleshooting Guide

## 🚨 Current Issue Analysis

### Error Encountered:
```
ClientException with SocketException:
Connection failed (OS Error: Operation not permitted, errno = 1), 
address = 188.245.35.46, port = 80, uri=http://188.245.35.46/api/v1/auth/login/
```

### Root Causes Identified:
1. **Android Network Security Policy** - HTTP traffic restrictions
2. **Missing Network Permissions** - Android manifest issues
3. **CORS Configuration** - Server not allowing mobile app requests
4. **Firewall/Network Configuration** - Server accessibility issues

## ✅ Solutions Applied

### 1. Android App Fixes

#### A. Updated AndroidManifest.xml
```xml
<!-- Added missing permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Network security configuration -->
<application
    android:usesCleartextTraffic="true"
    android:networkSecurityConfig="@xml/network_security_config">
```

#### B. Enhanced Network Security Config
Updated `Frontend/android/app/src/main/res/xml/network_security_config.xml`:
```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <!-- Your production server -->
        <domain includeSubdomains="false">188.245.35.46</domain>
        <!-- Development servers -->
        <domain includeSubdomains="false">localhost</domain>
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
    
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
```

### 2. Backend Fixes

#### A. Enhanced CORS Configuration
Updated `exam_prep_platform/production_settings.py`:
```python
# CORS settings for production - UPDATED TO ALLOW MOBILE APPS
CORS_ALLOW_ALL_ORIGINS = True  # Temporarily allow all origins for mobile apps

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
```

#### B. Created Custom HTTP Client
New file `Frontend/lib/utils/http_client.dart` with:
- Better timeout handling (30 seconds)
- Improved error handling for network issues
- Custom headers for mobile app identification
- Connection retry logic

### 3. Server Configuration

#### A. Updated server_setup.sh
- Comprehensive firewall configuration
- Nginx optimization for mobile apps
- CORS headers in nginx configuration
- Rate limiting for API endpoints

#### B. Nginx Configuration
Added mobile-specific headers:
```nginx
# CORS headers for mobile apps
add_header Access-Control-Allow-Origin "*";
add_header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS";
add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";

# Handle preflight requests
location / {
    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Max-Age 1728000;
        add_header Content-Type 'text/plain; charset=utf-8';
        add_header Content-Length 0;
        return 204;
    }
    # ... proxy configuration
}
```

## 🔧 Deployment Steps

### Step 1: Update Your Server
Run the updated server setup script:
```bash
# On your Hetzner server
cd /var/www/testimus
chmod +x server_setup.sh
sudo ./server_setup.sh
```

### Step 2: Apply Django Settings
```bash
# Restart Django with updated settings
sudo supervisorctl restart testimus

# Check if the service is running
sudo supervisorctl status testimus
```

### Step 3: Test Server Connectivity
```bash
# Test from server
curl -I http://localhost/api/v1/auth/login/

# Test CORS
curl -H "Origin: http://mobile-app" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     -X OPTIONS \
     http://188.245.35.46/api/v1/auth/login/
```

### Step 4: Rebuild Flutter App
```bash
# In your Flutter project
cd Frontend

# Clean and rebuild
flutter clean
flutter pub get

# Build for Android
flutter build apk --debug
# or
flutter run -d android
```

## 🧪 Testing Procedures

### 1. Test Server Accessibility
```bash
# From your local machine
curl -v http://188.245.35.46/api/v1/

# Should return 401 Unauthorized (which means server is working)
```

### 2. Test CORS Configuration
```bash
# Test preflight request
curl -X OPTIONS \
     -H "Origin: http://localhost" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     http://188.245.35.46/api/v1/auth/login/
```

### 3. Test Mobile App Connection
Use the connection test utility in your Flutter app:
```dart
// Run this in your app to test connectivity
await CustomHttpClient.testConnectivity();
```

## 🔍 Debugging Steps

### 1. Check Android Logs
```bash
# View Android logs while running the app
adb logcat | grep -E "(testimus|TestimusApp|NetworkException|SocketException)"
```

### 2. Check Server Logs
```bash
# On your server
sudo tail -f /var/log/supervisor/testimus.log
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 3. Test with Flutter Web (Bypass Android Restrictions)
```bash
# Test with Flutter web to isolate Android-specific issues
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
```

## 🚦 Verification Checklist

- [ ] Android app has INTERNET permission
- [ ] Network security config allows your server IP
- [ ] Django CORS settings allow all origins temporarily
- [ ] Server firewall allows ports 80 and 443
- [ ] Nginx is running and configured correctly
- [ ] Django is running under supervisor
- [ ] Can access http://188.245.35.46/admin/ from browser
- [ ] Can access http://188.245.35.46/api/v1/ from browser
- [ ] CORS preflight requests work

## 🛡️ Security Considerations

### After fixing the connection:

1. **Restrict CORS Origins:**
```python
# In production_settings.py, change from:
CORS_ALLOW_ALL_ORIGINS = True

# To specific origins:
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [
    "http://188.245.35.46",
    # Add your app's specific origins
]
```

2. **Set up HTTPS:**
```bash
# Install SSL certificate
sudo certbot --nginx -d yourdomain.com
```

3. **Update Android network config for HTTPS:**
```xml
<!-- Remove cleartext traffic permission after HTTPS setup -->
<domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">yourdomain.com</domain>
</domain-config>
```

## 📱 Alternative Solutions

### If HTTP still doesn't work:

1. **Use HTTPS immediately:**
   - Get a domain name
   - Set up SSL certificate
   - Update Android config to use HTTPS

2. **Use Android development build:**
   ```bash
   # Build debug version that bypasses some restrictions
   flutter build apk --debug
   ```

3. **Test on Android emulator first:**
   ```bash
   # Emulator may have different network restrictions
   flutter run -d emulator
   ```

## 📞 Support

If issues persist after following this guide:

1. Check Django logs for specific error messages
2. Verify network connectivity from your location
3. Test with a different Android device/emulator
4. Consider using HTTPS instead of HTTP

## ✨ Success Indicators

You'll know it's working when:
- ✅ Android app connects without SocketException
- ✅ Login requests return 400 (bad credentials) instead of connection errors
- ✅ API endpoints return proper HTTP status codes
- ✅ No more "Operation not permitted" errors

---

*Last updated: $(date)* 