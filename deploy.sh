#!/bin/bash

# Testimus Deployment Script for Hetzner Cloud
# Run this script on your server after uploading the project files

set -e  # Exit on any error

echo "Starting Testimus deployment..."

# Configuration
PROJECT_DIR="/var/www/testimus"
VENV_DIR="$PROJECT_DIR/venv"
USER="testimus"
GROUP="testimus"

# Create application user if it doesn't exist
if ! id "$USER" &>/dev/null; then
    echo "Creating application user..."
    adduser --system --group --home "$PROJECT_DIR" "$USER"
fi

# Create project directory if it doesn't exist
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating project directory..."
    mkdir -p "$PROJECT_DIR"
fi

# Set ownership
echo "Setting ownership..."
chown -R "$USER:$GROUP" "$PROJECT_DIR"

# Switch to project directory
cd "$PROJECT_DIR"

# Create virtual environment
echo "Creating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    sudo -u "$USER" python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment and install dependencies
echo "Installing dependencies..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
"

# Run database migrations
echo "Running database migrations..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    python manage.py migrate
"

# Collect static files
echo "Collecting static files..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    export DJANGO_SETTINGS_MODULE=exam_prep_platform.production_settings
    python manage.py collectstatic --noinput
"

# Create log directory
echo "Creating log directories..."
mkdir -p /var/log/django
mkdir -p /var/log/supervisor
chown -R "$USER:$GROUP" /var/log/django

# Create gunicorn configuration
echo "Creating gunicorn configuration..."
cat > "$PROJECT_DIR/gunicorn.conf.py" << EOF
bind = "127.0.0.1:8000"
workers = 3
user = "$USER"
group = "$GROUP"
chdir = "$PROJECT_DIR"
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
preload_app = True
worker_class = "sync"
EOF

chown "$USER:$GROUP" "$PROJECT_DIR/gunicorn.conf.py"

# Create supervisor configuration
echo "Creating supervisor configuration..."
cat > /etc/supervisor/conf.d/testimus.conf << EOF
[program:testimus]
command=$VENV_DIR/bin/gunicorn exam_prep_platform.wsgi:application -c $PROJECT_DIR/gunicorn.conf.py
directory=$PROJECT_DIR
user=$USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/supervisor/testimus.log
environment=DJANGO_SETTINGS_MODULE="exam_prep_platform.production_settings"
EOF

# Create nginx configuration
echo "Creating nginx configuration..."
cat > /etc/nginx/sites-available/testimus << EOF
server {
    listen 80;
    server_name 188.245.35.46 _;
    client_max_body_size 100M;
    
    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

# Enable nginx site
echo "Configuring nginx..."
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

ln -sf /etc/nginx/sites-available/testimus /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Reload supervisor and nginx
echo "Reloading services..."
supervisorctl reread
supervisorctl update
supervisorctl restart testimus 2>/dev/null || supervisorctl start testimus

systemctl restart nginx

# Wait a moment for services to start
sleep 5

# Check service status
echo "Checking service status..."
echo "Supervisor status:"
supervisorctl status testimus

echo "Nginx status:"
systemctl is-active nginx

echo "Testing application..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|404"; then
    echo "✅ Application is responding!"
    echo "🚀 Deployment completed successfully!"
    echo ""
    echo "Your application is now available at:"
    echo "  - Main site: http://188.245.35.46"
    echo "  - Admin panel: http://188.245.35.46/admin/"
    echo "  - API docs: http://188.245.35.46/api/schema/swagger-ui/"
    echo ""
    echo "Useful commands:"
    echo "  - View logs: tail -f /var/log/supervisor/testimus.log"
    echo "  - Restart app: supervisorctl restart testimus"
    echo "  - Check status: supervisorctl status testimus"
else
    echo "❌ Application is not responding. Check the logs:"
    echo "  - tail -f /var/log/supervisor/testimus.log"
    echo "  - tail -f /var/log/nginx/error.log"
fi 